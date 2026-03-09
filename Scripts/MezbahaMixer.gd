extends Node

func _ready():
	pass

func _process(_delta):
	var m = get_tree().current_scene.find_child("MezbahaManager", true, false)
	if not m or m.is_mixing or m.wheelbarrow_pieces < 4:
		return
		
	var arabasi = get_tree().current_scene.find_child("El_arabasi", true, false)
	var mixer = self
	if not mixer is Node3D:
		mixer = get_parent()
		if not mixer is Node3D:
			mixer = get_tree().current_scene.find_child("*Mixer*", true, false)
			
	if arabasi and arabasi is Node3D:
		var is_inside = false
		var bosalt_alani = get_tree().current_scene.find_child("ElArabasiBosalt", true, false)
		
		# Eğer ElArabasiBosalt eklendiyse, onun fiziksel alanını (Shape) test et
		if bosalt_alani:
			var col = bosalt_alani.find_child("CollisionShape3D*", true, false)
			if col and col is CollisionShape3D and col.shape:
				var space_state = bosalt_alani.get_world_3d().direct_space_state
				var query = PhysicsShapeQueryParameters3D.new()
				query.shape = col.shape
				query.transform = col.global_transform
				# Tüm katmanları kontrol et, El_arabasi'nin body'lerini bulsun
				query.collision_mask = 0xFFFFFFFF
				var results = space_state.intersect_shape(query)
				for res in results:
					var p = res.collider
					while p:
						if p.name == "El_arabasi":
							is_inside = true
							break
						p = p.get_parent()
					if is_inside: break
		else:
			# Fallback olarak mesafe kontrolü (ElArabasiBosalt bulunamazsa)
			if mixer and mixer is Node3D:
				var dist = arabasi.global_position.distance_to(mixer.global_position)
				if dist <= 2.2:
					is_inside = true
		
		# Araba alanın içindeyse uyarıyı göster (sürülse de sürülmese de)
		if is_inside:
			if not m.loading_zone_active:
				m.loading_zone_active = true
				m.show_mixer_prompt()
		else:
			if m.loading_zone_active:
				m.loading_zone_active = false
				
				# Eğer araba sürülüyorsa farklı mesaj, sürülmüyorsa farklı mesaj
				if m.driving_wheelbarrow == true:
					m.label_main.text = "" 
				else:
					m.label_main.text = DilYoneticisi.metin_al("mezbaha_surukle")
