extends Node3D

const IDLE_POS     := Vector3(0.10, -0.1, -0.2)
const HIDDEN_POS   := Vector3(0.10, -0.45, -0.2)
const IDLE_ROT_DEG := Vector3(-7.0, 178.0, -1.4)

const AG_AMOUNT := 0.06
const AG_SPEED  := 8.0

const T_FIRE_START        := 0.0
const T_FIRE_END          := 0.3
const T_RELOAD_START      := 1.66
const T_RELOAD_END        := 2.53
const T_POST_RELOAD_START := 7.0
const T_POST_RELOAD_END   := 10.60
const T_IDLE_START        := 9.43
const T_IDLE_END          := 10.60

@onready var anim_player : AnimationPlayer = $AnimationPlayer

var _camera       : Camera3D
var _ag_offset    := Vector3.ZERO
var _prev_cam_rot := Vector3.ZERO
var _tween        : Tween
var _idle_timer   : SceneTreeTimer
var _is_visible   := false
var _is_busy      := false
var _r_held       := false
var _idle_forward := true

var sfx_fire: AudioStreamPlayer
var mermi_sahnesi: PackedScene = preload("res://Scenes/Items/Mermi.tscn")

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	position = HIDDEN_POS
	rotation_degrees = IDLE_ROT_DEG
	visible = false
	_prev_cam_rot = _camera.rotation_degrees if _camera else Vector3.ZERO
	anim_player.animation_finished.connect(_on_anim_finished)
	
	sfx_fire = AudioStreamPlayer.new()
	sfx_fire.stream = load("res://Assets/Audio/gun_fire.mp3")
	add_child(sfx_fire)

func _process(delta: float) -> void:
	if not _is_visible or not _camera:
		return
	_apply_antigravity(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_visible:
			fire()

	if event is InputEventKey and event.keycode == KEY_R:
		if event.pressed and not event.echo:
			if _is_visible and not _is_busy:
				_r_held = true
				reload()
		elif not event.pressed:
			_r_held = false

func _apply_antigravity(delta: float) -> void:
	var cam_rot   := _camera.rotation_degrees
	var rot_delta := cam_rot - _prev_cam_rot
	_prev_cam_rot  = cam_rot

	var target_offset := Vector3(
		clamp(-rot_delta.y * AG_AMOUNT, -0.04,  0.04),
		clamp( rot_delta.x * AG_AMOUNT, -0.03,  0.03),
		0.0
	)
	_ag_offset = _ag_offset.lerp(target_offset, AG_SPEED * delta)

	if not _is_busy:
		position = IDLE_POS + _ag_offset

# ── PUBLIC ─────────────────────────────────────────────────────────────────────
func show_weapon() -> void:
	if _is_visible:
		return
	_is_visible = true
	visible = true
	_tween_to(IDLE_POS, 0.35)
	await get_tree().create_timer(0.35).timeout
	_play_idle()

func hide_weapon() -> void:
	if not _is_visible:
		# VISIBILITY FAILSAFE: Eğer visible ise ve animasyon takıldıysa gizle
		if visible: visible = false
		return
	_is_visible = false
	_is_busy = false
	_r_held = false
	_cancel_idle_timer()
	anim_player.speed_scale = 1.0
	anim_player.stop() # Yanlış animasyon oynamasını engellemek için durdur
	_tween_to(HIDDEN_POS, 0.25)
	await get_tree().create_timer(0.25).timeout
	visible = false

func fire() -> void:
	if _is_busy or not _is_visible:
		return
	
	if not GameManager.mermiyi_kullan():
		# Mermi yoksa ateşleme
		return

	_is_busy = true
	_cancel_idle_timer()
	
	sfx_fire.play()
	_ates_et_mermi()
	
	anim_player.speed_scale = 1.0
	anim_player.play("allanims")
	anim_player.seek(T_FIRE_START, true)
	await get_tree().create_timer(T_FIRE_END - T_FIRE_START).timeout
	anim_player.pause()
	_is_busy = false
	if _is_visible:
		_play_idle()

func _ates_et_mermi() -> void:
	if not mermi_sahnesi or not _camera: return
	
	var mermi = mermi_sahnesi.instantiate()
	get_tree().current_scene.add_child(mermi)
	mermi.scale = Vector3(0.5, 0.5, 0.5) # Boyutu yarıya düşür
	
	var ekran_ortasi = get_viewport().get_visible_rect().size / 2.0
	var hedef_yonu = _camera.project_ray_normal(ekran_ortasi)
	
	# Namlu ucu tahmini pozisyonu (silahın biraz önünde ve üstünde)
	var namlu_pos = global_position + _camera.global_transform.basis.z * -0.6 + _camera.global_transform.basis.y * 0.1
	mermi.global_position = namlu_pos + (hedef_yonu * 0.5)
	
	if mermi.has_method("baslat"):
		mermi.baslat(hedef_yonu)

func reload() -> void:
	if _is_busy or not _is_visible:
		return
	_is_busy = true
	_cancel_idle_timer()
	
	anim_player.speed_scale = 1.0
	# 1 — Mermi doldurma: 1.66 → 2.53
	anim_player.play("allanims")
	anim_player.seek(T_RELOAD_START, true)
	await get_tree().create_timer(T_RELOAD_END - T_RELOAD_START).timeout
	if not _is_visible:
		return
	# 2 — R bırakılsa da devam et: 7.0 → 10.60 tek sefer
	anim_player.seek(T_POST_RELOAD_START, true)
	await get_tree().create_timer(T_POST_RELOAD_END - T_POST_RELOAD_START).timeout
	anim_player.pause()
	_is_busy = false
	if _is_visible:
		_play_idle()

# ── İÇ YARDIMCILAR ────────────────────────────────────────────────────────────
func _play_idle() -> void:
	if not _is_visible:
		return
	_is_busy = false
	anim_player.play("allanims")
	
	if _idle_forward:
		anim_player.speed_scale = 0.01
		anim_player.seek(T_IDLE_START, true)
	else:
		anim_player.speed_scale = -1.0
		anim_player.seek(T_IDLE_END, true)
		
	_idle_forward = not _idle_forward
	
	var duration := T_IDLE_END - T_IDLE_START
	_idle_timer = get_tree().create_timer(duration)
	_idle_timer.timeout.connect(_play_idle)

func _on_anim_finished(_name: String) -> void:
	_is_busy = false
	if _is_visible:
		_play_idle()

func _tween_to(target: Vector3, duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(self, "position", target, duration)

func _cancel_idle_timer() -> void:
	if _idle_timer and _idle_timer.timeout.is_connected(_play_idle):
		_idle_timer.timeout.disconnect(_play_idle)
	_idle_timer = null
