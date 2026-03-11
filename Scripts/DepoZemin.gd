extends Node3D

@export var floor_scene: PackedScene = preload("res://Assets/Models/depo_tas/scene.gltf")
@export var extents_x: float = 9.0     # Half of 18 width
@export var center_z: float = 8.566    # Offset center of the room in Z
@export var extents_z: float = 29.0    # Half of 58 depth
@export var spacing_x: float = 1.8     # Width of tile 
@export var spacing_z: float = 1.8     # Depth of tile
@export var height: float = -2.25      # Floor Y level
@export var piece_scale: float = 0.5   # Adjust to fit look

func _ready():
	_build_multimesh()

func _build_multimesh():
	if not floor_scene: return
	
	var temp_instance = floor_scene.instantiate()
	var mesh_inst = _find_first_mesh_instance(temp_instance)
	
	if not mesh_inst or not mesh_inst.mesh:
		print("ERROR: Could not find Mesh in depo_tas")
		temp_instance.queue_free()
		return
		
	var target_mesh = mesh_inst.mesh
	var target_material = mesh_inst.get_active_material(0) 
	var mesh_offset = _get_local_transform(temp_instance, mesh_inst)

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = target_mesh
	
	var count_x = int((extents_x * 2) / spacing_x) + 1
	var count_z = int((extents_z * 2) / spacing_z) + 1
	mm.instance_count = count_x * count_z
	
	var base_x = -extents_x
	var base_z = center_z - extents_z
	
	var idx = 0
	for ix in range(count_x):
		for iz in range(count_z):
			var pos_x = base_x + (ix * spacing_x)
			var pos_z = base_z + (iz * spacing_z)
			
			var t = Transform3D()
			t.basis = t.basis.scaled(Vector3(piece_scale, piece_scale, piece_scale))
			t.origin = Vector3(pos_x, height, pos_z)
			
			mm.set_instance_transform(idx, t * mesh_offset)
			idx += 1
			
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if target_material:
		mmi.material_override = target_material
		
	add_child(mmi)
	temp_instance.free()

func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found = _find_first_mesh_instance(child)
		if found: return found
	return null

func _get_local_transform(root: Node, mesh_node: MeshInstance3D) -> Transform3D:
	var t = mesh_node.transform
	var parent = mesh_node.get_parent()
	while parent and parent != root and parent is Node3D:
		t = parent.transform * t
		parent = parent.get_parent()
	if parent == root and root is Node3D:
		t = root.transform * t
	t.origin = Vector3.ZERO # Cancel internal GLTF offsets
	return t
