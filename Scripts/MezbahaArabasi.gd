extends Node

@export var kilitli_mi: bool = false
@export var etkilesim_yazisi: String = ""

var follows_player = false
var pc: Node = null

func _ready():
	var parent_body = get_parent()
	if parent_body is CollisionObject3D:
		parent_body.collision_layer = 1 # Keep it hit by player raycast

func get_etkilesim_yazisi() -> String:
	var m = _get_manager()
	if not m: return etkilesim_yazisi
	if m.wheelbarrow_pieces < 4:
		return ""
	else:
		return "[E] Arabayi Sur/Birak"

func interact(oyuncu: Node):
	if kilitli_mi: return
	
	var manager = _get_manager()
	if not manager: return
	
	if manager.wheelbarrow_pieces < 4:
		# Check if player is holding a piece
		if oyuncu.tutulan_nesne and (oyuncu.tutulan_nesne.is_in_group("MezbahaUzuv") or oyuncu.tutulan_nesne.is_in_group("KopanUzuv")):
			var uzuv = oyuncu.tutulan_nesne
			oyuncu.esya_birak()
			
			if uzuv.get("arabaya_kondu_mu") != null:
				if uzuv.arabaya_kondu_mu == true:
					pass # Zaten konduysa sayma
				else:
					uzuv.arabaya_kondu_mu = true
					manager.piece_placed_in_wheelbarrow()
			else:
				manager.piece_placed_in_wheelbarrow()
			
			# Parent to wheelbarrow safely
			uzuv.freeze = true
			uzuv.get_parent().remove_child(uzuv)
			get_parent().add_child(uzuv)
			uzuv.position = Vector3(0, 5, 0) # Adjust relative to wheelbarrow model
			
			manager.piece_placed_in_wheelbarrow()
	else:
		follows_player = not follows_player
		pc = oyuncu
		
func _get_manager() -> Node:
	return get_tree().current_scene.find_child("MezbahaManager", true, false)

func unlock_movement():
	kilitli_mi = false

func _physics_process(delta):
	if follows_player and pc:
		# Very naive follow logic: move the root wheelbarrow to match player pos
		# Since the root wheelbarrow is a Mesh/Node3D, we can just tween or lerp it.
		var p_root = get_parent()
		var target_pos = pc.global_position - (pc.global_transform.basis.z * 1.0) # Pulled closer
		target_pos.y = p_root.global_position.y
		p_root.global_position = p_root.global_position.lerp(target_pos, 5.0 * delta)
		
		var target_rot = pc.global_rotation
		target_rot.x = 0
		target_rot.z = 0
		
		# Offset by -90 degrees because the model is rotated 90 degrees to the left
		var target_y = target_rot.y - deg_to_rad(90.0)
		
		p_root.global_rotation.y = lerp_angle(p_root.global_rotation.y, target_y, 5.0 * delta)
