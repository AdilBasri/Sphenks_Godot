extends SceneTree

func _init():
	print("Starting Oda Collisions Generation...")
	var scene = load("res://final_oda/scene.gltf") as PackedScene
	if scene == null:
		print("Failed to load res://final_oda/scene.gltf as PackedScene")
		quit()
		return

	var scene_root = scene.instantiate()
	
	var static_body = StaticBody3D.new()
	static_body.name = "Oda_Collisions"
	static_body.collision_layer = 255
	
	_extract_collisions(scene_root, static_body)
	
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(static_body)
	if result == OK:
		var err = ResourceSaver.save(packed_scene, "res://final_oda/generated_collisions.tscn")
		if err == OK:
			print("Successfully saved generated_collisions.tscn")
		else:
			print("Error saving tscn: ", err)
	else:
		print("Error packing scene: ", result)
		
	scene_root.queue_free()
	quit()

func _get_global_transform(node: Node3D) -> Transform3D:
	var t = node.transform
	var p = node.get_parent()
	while p != null and p is Node3D:
		t = p.transform * t
		p = p.get_parent()
	return t

func _extract_collisions(node: Node, parent_body: StaticBody3D):
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		if mesh != null:
			var shape = mesh.create_trimesh_shape()
			if shape != null:
				var col_shape = CollisionShape3D.new()
				col_shape.shape = shape
				col_shape.name = "CollisionShape_" + node.name.validate_node_name()
				col_shape.transform = _get_global_transform(node)
				parent_body.add_child(col_shape)
				col_shape.owner = parent_body
				print("Generated collision for ", node.name)
	
	for child in node.get_children():
		_extract_collisions(child, parent_body)
