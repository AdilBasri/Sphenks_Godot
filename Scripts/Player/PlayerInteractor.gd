extends Node

class_name PlayerInteractor

@export var raycast: RayCast3D
@export var hold_point: Node3D
@export var interaction_label: Label

var held_object: RigidBody3D = null
var mouse_free_mode: bool = false

func _physics_process(delta: float):
	if held_object and hold_point:
		var target_pos = hold_point.global_position
		var object_pos = held_object.global_position
		var dir = (target_pos - object_pos) * 15.0
		held_object.linear_velocity = dir
		held_object.angular_velocity = Vector3.ZERO

func check_interaction():
	if not raycast or not raycast.is_colliding():
		if interaction_label: interaction_label.text = ""
		return
		
	var collider = raycast.get_collider()
	if not collider:
		if interaction_label: interaction_label.text = ""
		return

	# TODO: Expand interaction logic based on groups or classes
	if collider.is_in_group("Etkilesim"):
		if interaction_label: interaction_label.text = "[E] Etkileşim"
	else:
		if interaction_label: interaction_label.text = ""
