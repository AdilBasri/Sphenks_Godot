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
		if follows_player:
			return "[E] Sürmeyi Bırak"
		else:
			return "[E] El Arabasını Sür"

func interact(oyuncu: Node):
	if kilitli_mi: return
	
	var manager = _get_manager()
	if not manager: return
	
	if oyuncu.tutulan_nesne and oyuncu.tutulan_nesne.is_in_group("KopanUzuv"):
		return
	
	if manager.wheelbarrow_pieces >= 4:
		follows_player = not follows_player
		pc = oyuncu
		manager.driving_wheelbarrow = follows_player
		
		# Sürerken üstteki yazıyı gizle, bırakınca geri getir
		if follows_player:
			if manager.loading_zone_active:
				manager.show_mixer_prompt()
			else:
				manager.label_main.text = ""
		else:
			if manager.loading_zone_active:
				manager.show_mixer_prompt()
			else:
				manager.label_main.text = "El arabasını et\nparçalayıcısına sürükle"
		
		var p_root = get_parent()
		if pc is CollisionObject3D:
			for child in p_root.get_children():
				if child is CollisionObject3D:
					if follows_player:
						pc.add_collision_exception_with(child)
					else:
						pc.remove_collision_exception_with(child)

func _get_manager() -> Node:
	return get_tree().current_scene.find_child("MezbahaManager", true, false)

func unlock_movement():
	kilitli_mi = false

func _physics_process(delta):
	if follows_player and pc:
		# Very naive follow logic: move the root wheelbarrow to match player pos
		# Since the root wheelbarrow is a Mesh/Node3D, we can just tween or lerp it.
		var p_root = get_parent()
		var target_pos = pc.global_position - (pc.global_transform.basis.z * 1.5) # Biraz daha yakına çekildi (1.8'den 1.5'e düştü)
		target_pos.y = p_root.global_position.y
		
		# Fizik testi ile layer 9 (256) dışındaki şeylere çarpmasını sağla
		var space_state = p_root.get_world_3d().direct_space_state
		var motion = target_pos - p_root.global_position
		
		var q = PhysicsShapeQueryParameters3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(1.0, 1.0, 1.0) # Arabanın çarpışma tarama boyutu (Daraltıldı ki kapılara rahat girsin)
		q.shape = box
		q.transform = p_root.global_transform
		q.transform.origin.y += 0.5 # Arabanın gövdesini ortalayıp yerden kurtarmak için
		q.motion = motion
		q.collision_mask = 4294967295 ^ 256 # Tüm katmanlar - 256 (Layer 9 hariç)
		q.exclude = [pc.get_rid()] # Oyuncuyu dışla
		for child in p_root.get_children():
			if child is CollisionObject3D:
				q.exclude.append(child.get_rid()) # Arabanın kendi parçalarını dışla ki kendine çarpıp durmasın
		
		var res = space_state.cast_motion(q)
		var safe_move = motion * res[0]
		
		var final_pos = p_root.global_position + safe_move
		p_root.global_position = p_root.global_position.lerp(final_pos, 8.0 * delta)
		
		var target_rot = pc.global_rotation
		target_rot.x = 0
		target_rot.z = 0
		
		# Offset by -90 degrees because the model is rotated 90 degrees to the left
		var target_y = target_rot.y - deg_to_rad(90.0)
		
		p_root.global_rotation.y = lerp_angle(p_root.global_rotation.y, target_y, 5.0 * delta)
