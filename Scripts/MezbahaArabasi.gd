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
			return DilYoneticisi.metin_al("surmeyi_birak")
		else:
			return DilYoneticisi.metin_al("arabayi_sur")

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
				manager.label_main.text = DilYoneticisi.metin_al("mezbaha_surukle")
		
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
		var p_root = get_parent()
		var arab_pos = p_root.global_position
		
		# Hedef: oyuncunun ÖNÜNDEki sabit nokta (baktığı yön × 1.5 birim)
		# Mouse döndüğünde bu hedef oyuncunun etrafında döner → araba da onu kovalayarak rekonumlanır
		var ileri = -pc.global_transform.basis.z
		ileri.y = 0.0
		if ileri.length_squared() > 0.001:
			ileri = ileri.normalized()
		else:
			ileri = Vector3(0, 0, -1)
		
		var hedef = pc.global_position + ileri * 1.5
		hedef.y = arab_pos.y  # Y sabit — araba uçmasın
		
		var motion = hedef - arab_pos
		var dist = motion.length()
		
		# Hız hesabı: oyuncudan ne kadar uzaktaysak o kadar hızlı koş
		# Minimum 2.0 birim/sn sabit çekim (böylece mouse döngüsünde de takip eder)
		var oyuncu_hizi = 0.0
		if pc.get("velocity") != null:
			oyuncu_hizi = Vector3(pc.velocity.x, 0.0, pc.velocity.z).length()
		var hiz = max(oyuncu_hizi * 1.2 + 1.5, 2.5)  # Daima en az 2.5 birim/sn
		
		var hareket = motion.normalized() * min(dist, hiz * delta)
		
		if hareket.length() < 0.002:
			# Sadece rotasyon güncelle
			var target_rot_y = pc.global_rotation.y - deg_to_rad(90.0)
			p_root.global_rotation.y = lerp_angle(p_root.global_rotation.y, target_rot_y, 7.0 * delta)
			return
		
		# Duvar testi: Layer 9 hariç her duvar bloklasın, oyuncu dışlansın (itme yok)
		var space_state = p_root.get_world_3d().direct_space_state
		var q = PhysicsShapeQueryParameters3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.8, 0.7, 0.8)
		q.shape = box
		q.transform = Transform3D(Basis.IDENTITY, arab_pos + Vector3(0, 0.4, 0))
		q.motion = hareket
		q.collision_mask = 0xFFFFFFFF ^ 256  # Layer 9 (ElArabasiBosalt) hariç
		q.exclude = [pc.get_rid()]
		for child in p_root.get_children():
			if child is CollisionObject3D:
				q.exclude.append(child.get_rid())
		
		var res = space_state.cast_motion(q)
		p_root.global_position += hareket * res[0]
		
		# Rotasyon: oyuncunun baktığı yöne hizala (hızlı)
		var target_rot_y = pc.global_rotation.y - deg_to_rad(90.0)
		p_root.global_rotation.y = lerp_angle(p_root.global_rotation.y, target_rot_y, 7.0 * delta)



