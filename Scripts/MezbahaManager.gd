extends Node

var font = preload("res://Assets/Fonts/PressStart2P-Regular.ttf")

var axe_node: Node3D
var player: CharacterBody3D
var gui_layer: CanvasLayer

var label_main: Label
var label_blood: ColorRect

var hit_count = 0
var axe_equipped = false
var blood_tween: Tween

var anim_player: AnimationPlayer

var wheelbarrow_pieces = 0
var can_swing: bool = true

func _ready():
	_create_ui()
	player = get_tree().get_first_node_in_group("Oyuncu")

func _create_ui():
	gui_layer = CanvasLayer.new()
	gui_layer.layer = 50
	add_child(gui_layer)
	
	label_blood = ColorRect.new()
	label_blood.color = Color(0.8, 0, 0, 0) # Transparent red default
	label_blood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_blood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_layer.add_child(label_blood)

	label_main = Label.new()
	var ls = LabelSettings.new()
	ls.font = font
	ls.font_size = 28
	ls.font_color = Color(1, 0, 0, 1)
	ls.shadow_color = Color.BLACK
	ls.shadow_size = 4
	label_main.label_settings = ls
	label_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_main.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label_main.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label_main.offset_top = 80
	label_main.hide()
	gui_layer.add_child(label_main)

func axe_picked_up():
	axe_equipped = true
	label_main.text = "Eti parçala"
	label_main.show()
	_shake_label(label_main, true)
	
	if not player:
		player = get_tree().get_first_node_in_group("Oyuncu")
	
	# Spawn visual axe in player camera
	if player and player.kamera:
		# Yeni Pivot nodunu oluşturuyoruz: bu nod sapın alt (tutuş) noktasını kapsayacak
		var pivot = Node3D.new()
		pivot.name = "AxePivot"
		# Sapın dip noktası ekran altında sabit kalsın ve el tutuyormuş gibi dursun
		pivot.position = Vector3(0.35, -1.0, -0.35)
		player.kamera.add_child(pivot)
		
		var visual_axe = preload("res://Mezbaha/Mezbaha_axe/scene.gltf").instantiate()
		pivot.add_child(visual_axe)
		# Modeli Pivot'a göre yukarı iterken, bilek noktasını baltanın en dibine çekmiş oluyoruz
		visual_axe.position = Vector3(0.0, 0.5, 0.0) 
		# Sola 45 derece eğik (çapraz) durması için rotasyon (Euler X ile sola yatırılır, Y=80 ileri bakar)
		visual_axe.rotation_degrees = Vector3(0, 100, 0) 
		visual_axe.scale = Vector3(3.0, 3.0, 3.0) 
		visual_axe.name = "MezbahaVisualAxe"

func _process(delta):
	if axe_equipped and can_swing and Input.is_action_just_pressed("sol_tik"):
		_swing_axe()

func _swing_axe():
	if not player or not player.kamera: return
	
	# Cooldown başlatıyoruz
	can_swing = false
	get_tree().create_timer(0.75).timeout.connect(func(): can_swing = true)
	
	var pivot = player.kamera.get_node_or_null("AxePivot")
	if pivot:
		var tw = create_tween()
		# Hamleyi Pivot üzerinden sadece açısal (ileri eğilmek) yapıyoruz.
		# Baltayı z ekseninde itmiyoruz (position sabittir), böylece sap kısmı ekranın altına çakılı kalıyor ve taşmıyor.
		tw.tween_property(pivot, "rotation_degrees:x", -70.0, 0.15).set_trans(Tween.TRANS_SINE)
		
		# Hamle bitince geri eski açısına (0.0) dönüyor
		tw.tween_property(pivot, "rotation_degrees:x", 0.0, 0.4).set_trans(Tween.TRANS_SPRING)
	
	# Raycast to hit meat
	var space_state = player.get_world_3d().direct_space_state
	var origin = player.kamera.global_position
	var dir = -player.kamera.global_transform.basis.z.normalized()
	var end = origin + dir * 2.5
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 15
	var result = space_state.intersect_ray(query)
	
	if result and result.collider:
		var hit_node = _find_mezbaha_man(result.collider)
		if hit_node:
			meat_hit(hit_node)

func _find_mezbaha_man(node: Node) -> Node:
	var curr = node
	for i in range(4):
		if not curr: break
		if curr.is_in_group("MezbahaMan"): return curr
		curr = curr.get_parent()
	return null

func meat_hit(meat_node):
	hit_count += 1
	_splash_blood()
	
	if hit_count < 3:
		label_main.text = "TEKRAR!"
		var ls = label_main.label_settings
		ls.font_size = 48
		_shake_label(label_main, true)
	elif hit_count == 3:
		label_main.hide()
		meat_node.visible = false
		meat_node.get_parent().visible = false
		if meat_node is CollisionObject3D:
			meat_node.collision_layer = 0
			meat_node.collision_mask = 0
		spawn_pieces(meat_node.global_position)
		label_main.text = "Baltayı yerine as"
		var ls = label_main.label_settings
		ls.font_size = 20
		label_main.show()
		_shake_label(label_main, false)
		
		var sec_axe = get_tree().current_scene.find_child("Axe", true, false)
		if sec_axe:
			var static_b = sec_axe.get_node_or_null("StaticBody3D")
			if static_b:
				static_b.set("asilabilir_mi", true)
				static_b.collision_layer = 1 # Oyuncu hedef alabilsin diye çarpışmayı geri açıyoruz

func _splash_blood():
	label_blood.color = Color(0.6, 0.0, 0.0, 0.8) # Stronger red
	if blood_tween: blood_tween.kill()
	blood_tween = create_tween()
	blood_tween.tween_property(label_blood, "color:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _shake_label(lbl: Label, extreme: bool):
	if anim_player and anim_player.is_playing(): anim_player.stop()
	
	var tw = create_tween().set_loops()
	var amt = 4.0 if extreme else 1.0 # Less extreme shake
	var spd = 0.06 if extreme else 0.1
	var orig_y = 50.0 if not extreme else 80.0
	
	for i in range(4):
		tw.tween_property(lbl, "position:x", randf_range(-amt, amt), spd)
		tw.tween_property(lbl, "position:y", orig_y + randf_range(-amt, amt), spd)
	tw.tween_property(lbl, "position", Vector2(0, orig_y), spd)

func spawn_pieces(pos: Vector3):
	var piece_scene = preload("res://Mezbaha_uzuv.tscn")
	if not piece_scene: return
	for i in range(4):
		var p = piece_scene.instantiate()
		get_parent().call_deferred("add_child", p)
		# Sadece masanın yakın bölgelerine düşsün, alan çok daraldı
		p.global_position = pos + Vector3(randf_range(-0.1, 0.1), randf_range(0.2, 0.5), randf_range(-0.2, 0.2))
		
		# Saçma uzak konumlara fırlamaması için kuvvetleri de minimize ettik, neredeyse masaya pıt diye düşecek.
		var rb = p.get_node_or_null("KopanUzuv")
		if rb and rb is RigidBody3D:
			rb.linear_velocity = Vector3(randf_range(-0.3, 0.3), randf_range(0.5, 1.5), randf_range(-0.3, 0.3))

func piece_placed_in_wheelbarrow():
	wheelbarrow_pieces += 1
	if wheelbarrow_pieces < 4:
		label_main.text = "Parçaları el arabasına yerleştir (%d/4)" % wheelbarrow_pieces
	else:
		label_main.text = "El arabasını hareket ettir"
		
		# Unlock wheelbarrow
		var ab = get_parent().get_node_or_null("El_arabasi")
		if ab:
			if ab.has_method("unlock_movement"):
				ab.unlock_movement()

func show_mixer_prompt():
	if wheelbarrow_pieces >= 4:
		label_main.text = "Parçaları yüklemek için R basılı tut"

func axe_returned():
	axe_equipped = false
	label_main.text = "Parçaları el arabasına yerleştir (0/4)"
	if wheelbarrow_pieces > 0:
		label_main.text = "Parçaları el arabasına yerleştir (%d/4)" % wheelbarrow_pieces
		
	if player and player.kamera:
		var visual_axe = player.kamera.get_node_or_null("AxePivot")
		if visual_axe:
			visual_axe.queue_free()
