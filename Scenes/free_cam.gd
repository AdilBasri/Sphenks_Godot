extends Node3D

@export var move_speed: float = 5.0
@export var fast_speed: float = 15.0
@export var sensitivity: float = 0.003
@export var brightness: float = 0.85
@export var dof_enabled: bool = true
@export var auto_rotate_speed: float = 0.3

var _mouse_captured := false
var _hidden_ui_nodes: Array = []
var _original_env: Environment = null
var _auto_rotating := false
var _cam_active := false

func _ready():
	_capture_mouse()
	_apply_cinematic_env()

func _exit_tree():
	_restore_all_ui()
	_restore_env()

func _hide_all_ui():
	var root = get_tree().current_scene
	_find_and_hide_ui(root)

func _find_and_hide_ui(node: Node):
	if node == self:
		return
	if node is CanvasLayer or node is Control:
		if node.visible:
			node.visible = false
			_hidden_ui_nodes.append(node)
	for child in node.get_children():
		_find_and_hide_ui(child)

func _restore_all_ui():
	for node in _hidden_ui_nodes:
		if is_instance_valid(node):
			node.visible = true
	_hidden_ui_nodes.clear()

func _apply_cinematic_env():
	var env_node = _find_world_environment()
	if not env_node:
		return
	_original_env = env_node.environment.duplicate()
	var env: Environment = env_node.environment
	env.adjustment_enabled = true
	env.adjustment_brightness = brightness
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 0.9
	if dof_enabled:
		var cam = $Camera3D
		cam.attributes = CameraAttributesPractical.new()
		cam.attributes.dof_blur_far_enabled = true
		cam.attributes.dof_blur_far_distance = 8.0
		cam.attributes.dof_blur_far_transition = 4.0
		cam.attributes.dof_blur_amount = 0.08

func _restore_env():
	var env_node = _find_world_environment()
	if env_node and _original_env:
		env_node.environment = _original_env

func _find_world_environment() -> WorldEnvironment:
	var root = get_tree().current_scene
	return _search_world_env(root)

func _search_world_env(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for child in node.get_children():
		var result = _search_world_env(child)
		if result:
			return result
	return null

func _activate_player_camera():
	var oyuncu = get_tree().current_scene.find_child("Oyuncu", true, false)
	if oyuncu:
		var cam = oyuncu.find_child("Camera3D", true, false)
		if cam and cam is Camera3D:
			cam.make_current()

func _capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_mouse_captured = true

func _release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_mouse_captured = false

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if _mouse_captured:
				_release_mouse()
			else:
				_capture_mouse()
		if event.pressed and event.keycode == KEY_R:
			_auto_rotating = !_auto_rotating
		if event.pressed and event.keycode == KEY_F:
			_cam_active = !_cam_active
			if _cam_active:
				$Camera3D.make_current()
				_hide_all_ui()
			else:
				_restore_all_ui()
				_activate_player_camera()
	if event is InputEventMouseMotion and _mouse_captured and not _auto_rotating and _cam_active:
		rotate_y(-event.relative.x * sensitivity)
		$Camera3D.rotate_x(-event.relative.y * sensitivity)
		$Camera3D.rotation.x = clamp(
			$Camera3D.rotation.x,
			deg_to_rad(-89),
			deg_to_rad(89)
		)

func _process(delta):
	if not _mouse_captured or not _cam_active:
		return
	if _auto_rotating:
		rotate_y(deg_to_rad(auto_rotate_speed) * delta)
		return
	var speed = fast_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direction -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += transform.basis.x
	if Input.is_key_pressed(KEY_E):
		direction += transform.basis.y
	if Input.is_key_pressed(KEY_Q):
		direction -= transform.basis.y
	if direction.length() > 0:
		direction = direction.normalized()
	position += direction * speed * delta
