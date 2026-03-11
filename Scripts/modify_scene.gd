@tool
extends EditorScript

# EditorScript to optimize yenisahne.tscn and add collisions
# Geliştirilmiş Sürüm: Alt sahneleri önbellekleyip AABB/Mesh'leri garantili çeker.

func _run():
	var scene = get_editor_interface().get_edited_scene_root()
	if not scene:
		print("HATA: Lütfen önce yenisahne.tscn dosyasını açıp Editor'de görüntüleyin!")
		return
		
	if scene.name != "Node3D" and not scene.scene_file_path.contains("yenisahne"):
		print("UYARI: Seçili sahne yenisahne.tscn gibi durmuyor. (" + scene.name + ")")
	
	print("--- Sahne Düzenleme Başladı (" + scene.name + ") ---")
	
	var nodes_to_add_collision = []
	var grass_nodes = []
	var lamp_nodes = []
	
	# Sahnede olan her şeyi tarıyoruz
	var all_nodes = _get_all_children(scene)
	
	# Dosya yollarına göre düğümleri filtrele
	for node in all_nodes:
		if node.scene_file_path.contains("grass/scene.gltf"):
			grass_nodes.append(node)
		elif node.scene_file_path.contains("gas_lamp/scene.gltf"):
			lamp_nodes.append(node)
		elif node.scene_file_path.contains("ruin/scene.gltf") or \
			node.scene_file_path.contains("body/scene.gltf") or \
			node.scene_file_path.contains("pusat/Meshy_AI") or \
			node.scene_file_path.contains("tarikat/Meshy_AI"):
			nodes_to_add_collision.append(node)
			
	print("Bulunan Grass: ", grass_nodes.size(), " | Gas Lamp: ", lamp_nodes.size(), " | Çarpışma eklenecekler: ", nodes_to_add_collision.size())
			
	# Mesh ve AABB okumak için Packing işlemi
	var grass_mesh = _get_mesh_from_path("res://Assets/Models/grass/scene.gltf")
	var lamp_mesh = _get_mesh_from_path("res://Assets/Models/gas_lamp/scene.gltf")
	
	# 1. Grass için MultiMesh oluştur
	if grass_nodes.size() > 0 and grass_mesh != null:
		var grass_mmi = MultiMeshInstance3D.new()
		grass_mmi.name = "GrassMultiMesh"
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.instance_count = grass_nodes.size()
		multimesh.mesh = grass_mesh
		
		for i in range(grass_nodes.size()):
			var node = grass_nodes[i]
			multimesh.set_instance_transform(i, node.transform)
			node.queue_free()
			
		grass_mmi.multimesh = multimesh
		scene.add_child(grass_mmi)
		grass_mmi.owner = scene
		print("- Grass MultiMesh başarıyla eklendi.")
	elif grass_nodes.size() > 0:
		print("HATA: Grass Mesh'i bulunamadı. Lütfen res://Assets/Models/grass/scene.gltf yolunu kontrol edin.")
		
	# 2. Gas Lamp için MultiMesh oluştur (ışıkları koru)
	if lamp_nodes.size() > 0 and lamp_mesh != null:
		var lamp_mmi = MultiMeshInstance3D.new()
		lamp_mmi.name = "GasLampMultiMesh"
		var multimesh2 = MultiMesh.new()
		multimesh2.transform_format = MultiMesh.TRANSFORM_3D
		multimesh2.instance_count = lamp_nodes.size()
		multimesh2.mesh = lamp_mesh
		
		var lights_parent = Node3D.new()
		lights_parent.name = "GasLampLights"
		scene.add_child(lights_parent)
		lights_parent.owner = scene
		# Sahnenin en üstünde değilse diye ayarla
		
		for i in range(lamp_nodes.size()):
			var node = lamp_nodes[i]
			multimesh2.set_instance_transform(i, node.transform)
			
			# Orijinal sahnede OmniLight3D instance içinde kayıtlıdır!
			# Ancak Godot düzenleyicisinde kullanıcı tarafından override edilerek eklenmiş ışıklar olabilir.
			# yenisahne.tscn dosyasında "OmniLight3D" isimli child'ları olduğunu görebiliyoruz.
			for child in node.get_children():
				if child is OmniLight3D:
					var saved_global = child.global_transform
					# Cihazdan node'u çıkarıyoruz
					var clone = child.duplicate()
					lights_parent.add_child(clone)
					clone.global_transform = saved_global
					clone.owner = scene
			
			node.queue_free()
			
		lamp_mmi.multimesh = multimesh2
		scene.add_child(lamp_mmi)
		lamp_mmi.owner = scene
		print("- Gas Lamp MultiMesh ve Işık Koruma başarıyla eklendi.")
	elif lamp_nodes.size() > 0:
		print("HATA: Gas Lamp Mesh'i bulunamadı. Lütfen res://Assets/Models/gas_lamp/scene.gltf yolunu kontrol edin.")

	# 3. Collision Ekleme (Layer 1, Mask 1)
	var added_col_count = 0
	for node in nodes_to_add_collision:
		_add_collision_safely(node, scene)
		added_col_count += 1
		
	print("- Toplam", added_col_count, "adet düğüme çarpışma (CollisionShape3D) eklendi.")
	print("--- TÜM İŞLEMLER TAMAMLANDI! (Lütfen sahneyi kaydedin: Ctrl+S) ---")

# --- YARDIMCI FONSİYONLAR ---

func _get_all_children(node: Node) -> Array:
	var nodes = []
	for n in node.get_children():
		nodes.append(n)
		nodes.append_array(_get_all_children(n))
	return nodes

func _get_mesh_from_path(scene_path: String) -> Mesh:
	if not ResourceLoader.exists(scene_path):
		return null
	var packed = load(scene_path)
	if packed == null: return null
	
	var temp_instance = packed.instantiate()
	var mesh_inst = _find_first_meshinstance3d(temp_instance)
	var result_mesh = null
	if mesh_inst and mesh_inst.mesh:
		result_mesh = mesh_inst.mesh
		
	temp_instance.free() # Hafızayı temizle
	return result_mesh

func _get_aabb_from_path(scene_path: String) -> AABB:
	if not ResourceLoader.exists(scene_path):
		return AABB(Vector3.ZERO, Vector3(2, 2, 2))
	var packed = load(scene_path)
	if packed == null: return AABB(Vector3.ZERO, Vector3(2, 2, 2))
	
	var temp_instance = packed.instantiate()
	var mesh_inst = _find_first_meshinstance3d(temp_instance)
	var result_aabb = AABB(Vector3.ZERO, Vector3(2, 2, 2))
	if mesh_inst:
		result_aabb = mesh_inst.get_aabb()
		
	temp_instance.free()
	return result_aabb

func _find_first_meshinstance3d(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var res = _find_first_meshinstance3d(child)
		if res != null: return res
	return null

func _add_collision_safely(node: Node, scene_root: Node):
	# Zaten varsa ekleme
	for child in node.get_children():
		if child is StaticBody3D:
			return
			
	var sb = StaticBody3D.new()
	sb.name = "GenCollisionBody"
	sb.collision_layer = 1
	sb.collision_mask = 1
	
	var col = CollisionShape3D.new()
	col.name = "GenCollisionShape"
	
	# Kutuyu alt sahneye göre hesapla
	var aabb = _get_aabb_from_path(node.scene_file_path)
	var box = BoxShape3D.new()
	
	box.size = aabb.size
	# Box biraz daha büyük olabilir tarikat ve karakterler için.
	if box.size.y < 1.0:
		box.size.y = 2.5
		box.size.x = 1.0
		box.size.z = 1.0
		
	if "ruin/scene.gltf" in node.scene_file_path:
		# Kolonları vs. saracak şekilde Scale ile düzeltmemiz lazım
		# ruin scale uygulanmış mı diye bakalım, node scale'ına göre
		# Genelde AABB kendi raw size'ındadır
		box.size = aabb.size
		col.position = aabb.position + (aabb.size / 2.0)
	elif "body/scene.gltf" in node.scene_file_path:
		col.position = aabb.position + (aabb.size / 2.0)
	else:
		# Karakterler (Anubis, tarikat) için
		col.position = aabb.position + (aabb.size / 2.0)
		
	col.shape = box
	sb.add_child(col)
	node.add_child(sb)
	
	# Godot Scene Tree'ye kayıt
	sb.owner = scene_root
	col.owner = scene_root
