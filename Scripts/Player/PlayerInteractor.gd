extends Node

class_name PlayerInteractor

@export var raycast: RayCast3D
@export var hold_point: Node3D
@export var interaction_label: Label

var held_object: RigidBody3D = null
var mouse_free_mode: bool = false

var _outline_material: ShaderMaterial
var _last_highlighted_mesh: GeometryInstance3D = null

func _ready():
	_outline_material = ShaderMaterial.new()
	var outline_shader = load("res://Assets/Materials/DarkToonyOutline.gdshader")
	if outline_shader:
		_outline_material.shader = outline_shader
		_outline_material.set_shader_parameter("outline_color", Color(0.1, 0.05, 0.15))
		_outline_material.set_shader_parameter("outline_width", 0.04)

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
		_clear_highlight()
		return
		
	var collider = raycast.get_collider()
	if not collider:
		if interaction_label: interaction_label.text = ""
		_clear_highlight()
		return

	if collider.is_in_group("Etkilesim"):
		# Find the actual mesh attached to the collider or the collider itself
		var mesh_instance = null
		if collider is GeometryInstance3D:
			mesh_instance = collider
		else:
			for child in collider.get_children():
				if child is GeometryInstance3D:
					mesh_instance = child
					break
					
		if mesh_instance and mesh_instance != _last_highlighted_mesh:
			_apply_highlight(mesh_instance)
		
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
		
		if not devre_disi and get_tree().current_scene:
			if "mezar" in get_tree().current_scene.name.to_lower():
				devre_disi = true
			
		if devre_disi:
			if interaction_label: interaction_label.text = ""
			return
		
		var custom_text = collider.get("interaction_text")
		if not custom_text and collider.get_parent():
			custom_text = collider.get_parent().get("interaction_text")
			
		if custom_text:
			if interaction_label: interaction_label.text = (DilYoneticisi.metin_al(custom_text) if DilYoneticisi else custom_text)
		else:
			if interaction_label: interaction_label.text = "[E] Etkileşim"
	else:
		if interaction_label: interaction_label.text = ""
		_clear_highlight()

func _apply_highlight(mesh: GeometryInstance3D):
	_clear_highlight()
	if mesh and _outline_material:
		_last_highlighted_mesh = mesh
		mesh.material_overlay = _outline_material

func _clear_highlight():
	if _last_highlighted_mesh and is_instance_valid(_last_highlighted_mesh):
		_last_highlighted_mesh.material_overlay = null
	_last_highlighted_mesh = null
