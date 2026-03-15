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
		# Özel durum: Kapı veya nesne (veya babası) etkileşimi kapatmış olabilir
		var aday = collider
		var devre_disi = false
		var limit = 3
		while aday and limit > 0:
			if aday.get("e_etkilesimi_devre_disi") == true:
				devre_disi = true
				break
			if "mezar" in aday.name.to_lower():
				devre_disi = true
				break
			aday = aday.get_parent()
			limit -= 1
		
		# Sahne ismi kontrolü
		if not devre_disi and get_tree().current_scene:
			if "mezar" in get_tree().current_scene.name.to_lower():
				devre_disi = true
			
		if devre_disi:
			if interaction_label: interaction_label.text = ""
			return
		if interaction_label: interaction_label.text = "[E] Etkileşim"
	else:
		if interaction_label: interaction_label.text = ""
