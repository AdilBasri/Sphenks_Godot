extends Node3D

@export var wall_scene: PackedScene = preload("res://depo_duvar/scene.gltf")
@export var extents_x: float = 9.0     # Half of 18 width
@export var center_z: float = 8.566    # Offset center of the room in Z
@export var extents_z: float = 29.0    # Half of 58 depth
@export var spacing: float = 1.6       # Width of the wall piece
@export var piece_scale: float = 1.0   

func _ready():
	_build_multimesh()

func _build_multimesh():
	if not wall_scene: return
	
	var temp_instance = wall_scene.instantiate()
	var mesh_inst = _find_first_mesh_instance(temp_instance)
	
	if not mesh_inst or not mesh_inst.mesh:
		print("ERROR: Could not find Mesh in depo_duvar")
		temp_instance.queue_free()
		return
		
	var target_mesh = mesh_inst.mesh
	var target_material = mesh_inst.get_active_material(0) 
	var mesh_offset = _get_local_transform(temp_instance, mesh_inst)

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = target_mesh
	
	var count_z_side = int((extents_z * 2) / spacing) + 1
	var count_x_side = int((extents_x * 2) / spacing) + 1
	var count_y_side = 4 # Stack 4 pieces high to reach ceiling
	var height_spacing = 1.6 # Assuming square-ish wall pieces
	
	mm.instance_count = ((count_z_side * 2) + (count_x_side * 2)) * count_y_side
	
	var base_z = center_z - extents_z
	var base_x = -extents_x
	var base_y = -2.25 # Start at floor level
	
	var idx = 0
	
	for iy in range(count_y_side):
		var pos_y = base_y + (iy * height_spacing)
		
		#LEFT WALL (Facing +X)
		for iz in range(count_z_side):
			var pos_z = base_z + (iz * spacing)
			var t = Transform3D()
			t.basis = Basis.from_euler(Vector3(0, PI/2.0, 0))
			t.basis = t.basis.scaled(Vector3(piece_scale, piece_scale, piece_scale))
			t.origin = Vector3(-extents_x + 0.5, pos_y, pos_z)
			mm.set_instance_transform(idx, t * mesh_offset)
			idx += 1
			
		#RIGHT WALL (Facing -X)
		for iz in range(count_z_side):
			var pos_z = base_z + (iz * spacing)
			var t = Transform3D()
			t.basis = Basis.from_euler(Vector3(0, -PI/2.0, 0))
			t.basis = t.basis.scaled(Vector3(piece_scale, piece_scale, piece_scale))
			t.origin = Vector3(extents_x - 0.5, pos_y, pos_z)
			mm.set_instance_transform(idx, t * mesh_offset)
			idx += 1
			
		#FRONT WALL (Facing +Z)
		for ix in range(count_x_side):
			var pos_x = base_x + (ix * spacing)
			var t = Transform3D()
			t.basis = Basis.from_euler(Vector3(0, 0, 0))
			t.basis = t.basis.scaled(Vector3(piece_scale, piece_scale, piece_scale))
			t.origin = Vector3(pos_x, pos_y, center_z - extents_z + 0.5)
			mm.set_instance_transform(idx, t * mesh_offset)
			idx += 1
			
		#BACK WALL (Facing -Z)
		for ix in range(count_x_side):
			var pos_x = base_x + (ix * spacing)
			var t = Transform3D()
			t.basis = Basis.from_euler(Vector3(0, PI, 0))
			t.basis = t.basis.scaled(Vector3(piece_scale, piece_scale, piece_scale))
			t.origin = Vector3(pos_x, pos_y, center_z + extents_z - 0.5)
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
