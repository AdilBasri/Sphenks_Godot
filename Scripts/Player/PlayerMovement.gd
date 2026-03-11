extends Node

class_name PlayerMovement

@export var player: CharacterBody3D
@export var base_speed: float = 3.0
@export var sprint_speed: float = 5.25
@export var crouch_speed: float = 1.6
@export var gravity: float = 9.8

var current_speed: float = 3.0
var is_crouching: bool = false
var walking_player: AudioStreamPlayer

func _ready():
	walking_player = AudioStreamPlayer.new()
	var w_stream = load("res://Assets/Audio/walking.mp3")
	if w_stream and "loop" in w_stream: w_stream.loop = true
	walking_player.stream = w_stream
	walking_player.bus = "SFX"
	add_child(walking_player)

func handle_movement(delta: float, input_dir: Vector2, is_on_floor: bool, skip_input: bool = false):
	if skip_input:
		player.velocity = Vector3.ZERO
		_stop_footsteps()
		return

	if not is_on_floor:
		player.velocity.y -= gravity * delta

	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity.x = direction.x * current_speed
		player.velocity.z = direction.z * current_speed
		if is_on_floor:
			_play_footsteps()
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, current_speed)
		_stop_footsteps()

func _play_footsteps():
	if not walking_player.playing:
		walking_player.play()

func _stop_footsteps():
	if walking_player.playing:
		walking_player.stop()

func toggle_crouch(active: bool):
	is_crouching = active
	current_speed = crouch_speed if is_crouching else base_speed
