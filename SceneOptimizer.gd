@tool
extends EditorScript

# yenisahne.tscn Otimizasyon Aracı
# Kullanımı: yenisahne.tscn açıkken bu scripti Script Editor'de açıp File -> Run (File -> Çalıştır) veya Ctrl+Shift+X ile çalıştırın.

func _run():
	var scene_root = get_scene()
	if not scene_root:
		print("HATA: Hiçbir sahne açık değil!")
		return
	
	print("=== Optimizasyon Başlıyor: ", scene_root.name, " ===")
	
	# 1. IŞIK OPTİMİZASYONU
	var light_count = 0
	var omni_lights = _find_all_nodes_of_class(scene_root, "OmniLight3D")
	for light in omni_lights:
		if "Key" in light.name or "Main" in light.name or "AnaLight" in light.name:
			continue # Ana ışıkların gölgelerini tut
		light.shadow_enabled = false
		light_count += 1
	print("-> ", light_count, " adet minör OmniLight3D gölgesi kapatıldı.")
	
	# 2. UZAK CİSİMLER İÇİN LOD (VISIBILITY RANGE)
	var mesh_count = 0
	var meshes = _find_all_nodes_of_class(scene_root, "MeshInstance3D")
	for mesh in meshes:
		if "Zemin" not in mesh.name and "Ground" not in mesh.name:
			# Küçük objeler uzaktan renderlanmasın
			mesh.visibility_range_end = 40.0 
			mesh.visibility_range_end_margin = 5.0
			mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mesh_count += 1
	print("-> ", mesh_count, " adet obje için LOD (Görünürlük Mesafesi) ayarlandı.")

	# 3. ÇİMENLERİ MULTIMESH'E ÇEVİR
	_convert_grass_to_multimesh(scene_root)
	
	print("=== Optimizasyon Tamamlandı! Sahneyi Kaydedin (Ctrl+S). ===")

func _find_all_nodes_of_class(node: Node, class_name_str: String) -> Array:
	var result = []
	if node.is_class(class_name_str):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_nodes_of_class(child, class_name_str))
	return result

func _convert_grass_to_multimesh(root: Node):
	# İsmi Grass, Cimen veya Ot olan MeshInstance3D'leri bulur
	var grass_nodes = []
	var meshes = _find_all_nodes_of_class(root, "MeshInstance3D")
	for mesh in meshes:
		if "Grass" in mesh.name or "Cimen" in mesh.name or "Ot" in mesh.name:
			grass_nodes.append(mesh)
			
	if grass_nodes.is_empty():
		print("-> HİÇBİR ÇİMEN (Grass/Cimen/Ot) BULUNAMADI, MultiMesh işlemi atlanıyor.")
		return
		
	var multi_mesh_instance = MultiMeshInstance3D.new()
	var multi_mesh = MultiMesh.new()
	
	multi_mesh.mesh = grass_nodes[0].mesh
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = grass_nodes.size()
	
	for i in range(grass_nodes.size()):
		var grass = grass_nodes[i]
		multi_mesh.set_instance_transform(i, grass.global_transform)
		
	multi_mesh_instance.multimesh = multi_mesh
	multi_mesh_instance.name = "OptimizedGrassMultiMesh"
	
	var parent = grass_nodes[0].get_parent()
	parent.add_child(multi_mesh_instance)
	multi_mesh_instance.owner = root
	
	for grass in grass_nodes:
		grass.free() # node'ları temizle
		
	print("-> ", grass_nodes.size(), " adet Çimen/Grass objesi 1 adet MultiMeshInstance3D yapısına dönüştürüldü.")
