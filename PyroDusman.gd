extends CharacterBody3D

@export var hiz: float = 2.0 
@export var saglik: int = 20

@onready var anim_sprite = $AnimatedSprite3D
@onready var hitbox = $Hitbox 

var oyuncu: Node3D = null
var hasar_verdi_mi: bool = false 
var saldiri_aktif: bool = false 

func _ready():
	add_to_group("Dusman")
	
	if anim_sprite:
		anim_sprite.modulate.a = 1.0 
	
	oyuncuyu_bul()
	
	if hitbox:
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Spawn Kill koruması
	await get_tree().create_timer(2.0).timeout
	saldiri_aktif = true
	
	if anim_sprite:
		anim_sprite.modulate = Color(1, 0.5, 0.5)

func oyuncuyu_bul():
	var players = get_tree().get_nodes_in_group("Oyuncu")
	if players.size() > 0:
		oyuncu = players[0]
	else:
		oyuncu = get_tree().current_scene.find_child("CharacterBody3D", true, false)

func _physics_process(delta):
	if not oyuncu: return

	# --- FENER KONTROLÜ (Daha önce eklemiştik) ---
	if GameManager and GameManager.fener_aktif:
		look_at(Vector3(oyuncu.global_position.x, global_position.y, oyuncu.global_position.z))
		velocity = Vector3.ZERO
		move_and_slide()
		return 

	# Normal Davranış
	look_at(Vector3(oyuncu.global_position.x, global_position.y, oyuncu.global_position.z))

	var anlik_hiz = hiz
	
	# Saldırı modunda değilse (uzaktaysa) zaten yavaş
	if not saldiri_aktif:
		anlik_hiz = hiz * 0.2 
	
	# --- YENİ: ZAMAN YAVAŞLATMA (TIME) ETKİSİ ---
	if GameManager and GameManager.pyro_yavaslatma:
		anlik_hiz *= 0.5 # Hızı yarıya indir
	# ---------------------------------------------
	
	var hedef_pos = oyuncu.global_position
	hedef_pos.y += 0.8 
	var yon = (hedef_pos - global_position).normalized()
	velocity = yon * anlik_hiz
	
	move_and_slide()

func _on_hitbox_body_entered(body):
	if not saldiri_aktif: return 

	# --- FENER KORUMASI ---
	# Işık varsa ısıramazlar!
	if GameManager and GameManager.fener_aktif:
		return
	# ----------------------

	if body.is_in_group("Oyuncu"):
		print("🩸 YARASA ISIRDI!")
		if body.has_method("hasar_al"):
			body.hasar_al(20)
		queue_free()

func hasar_al_efekt():
	# Fener açık olsa bile vurabilirsin, o yüzden burayı engellemiyoruz.
	saglik -= 10
	if anim_sprite:
		anim_sprite.modulate = Color(10, 0, 0)
		var tween = create_tween()
		tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.1)
	
	if saglik <= 0:
		queue_free()
