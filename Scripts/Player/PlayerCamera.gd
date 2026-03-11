extends Node

class_name PlayerCamera

@export var player: CharacterBody3D
@export var camera: Camera3D
@export var mouse_sensitivity: float = 0.003

# Bobbing
@export var bob_freq: float = 2.0
@export var bob_amp: float = 0.035

var x_rotation: float = 0.0
var t_bob: float = 0.0
var trauma: float = 0.0
var trauma_decay: float = 2.5

func handle_look(relative_motion: Vector2, is_locked: bool = false):
	if is_locked: return
	
	player.rotate_y(-relative_motion.x * mouse_sensitivity)
	x_rotation -= relative_motion.y * mouse_sensitivity
	x_rotation = clamp(x_rotation, deg_to_rad(-80), deg_to_rad(80))
	camera.rotation.x = x_rotation

func update_bob(delta: float, velocity: Vector3, is_on_floor: bool, is_crouching: bool, is_sprinting: bool):
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()

	if is_on_floor and horizontal_speed > 0.5:
		var freq = bob_freq
		var amp = bob_amp
		
		if is_crouching:
			freq = 1.5
			amp = 0.015
		elif is_sprinting:
			freq = 2.5
			amp = 0.055

		t_bob += delta * horizontal_speed * freq
		
		camera.v_offset = lerp(camera.v_offset, sin(t_bob) * amp, delta * 12.0)
		camera.h_offset = lerp(camera.h_offset, cos(t_bob * 0.5) * (amp * 0.5), delta * 12.0)
	else:
		t_bob = 0.0
		camera.v_offset = lerp(camera.v_offset, 0.0, delta * 8.0)
		camera.h_offset = lerp(camera.h_offset, 0.0, delta * 8.0)

func add_trauma(amount: float):
	trauma = clamp(trauma + amount, 0.0, 1.0)

func handle_shake(delta: float):
	if trauma > 0:
		trauma = max(trauma - trauma_decay * delta, 0)
		# TODO: Apply actual shake transform if needed
