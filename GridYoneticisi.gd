extends Node3D
class_name GridYonetici

# --- AYARLAR ---
@export_group("Grid")
@export var grid_boyutu: Vector2i = Vector2i(8, 8)
@export var hucre_boyutu: float = 0.5 # Bunu masadaki desene uyana kadar değiştir!

@export_group("Masa")
@export var masa_node: Node3D 
@export var masa_layer_mask: int = 1
@export var ray_uzunlugu: float = 4000.0

@export_group("Debug")
@export var debug_cizgileri_goster: bool = true

@onready var kamera: Camera3D = get_viewport().get_camera_3d()

# --- DEĞİŞKENLER ---
var grid_verisi: Dictionary = {}
var exclude_rids: Array[RID] = []
var debug_root: Node3D = null

func _ready() -> void:
	# 1. Kursorun boyutunu grid hücresine eşitle (Böylece görsel yanılgı olmaz)
	var kursor = get_node_or_null("Kursor")
	if kursor and kursor.mesh:
		kursor.mesh.size = Vector2(hucre_boyutu, hucre_boyutu)
	
	# 2. Debug çizgilerini çiz
	if debug_cizgileri_goster:
		cizgileri_olustur()

# --- KRİTİK: IZGARAYI GÖZLE GÖRMEK İÇİN ---
func cizgileri_olustur() -> void:
	if debug_root: debug_root.queue_free()
	debug_root = Node3D.new()
	add_child(debug_root)
	
	var toplam_x = float(grid_boyutu.x) * hucre_boyutu
	var toplam_z = float(grid_boyutu.y) * hucre_boyutu
	var bas_x = -(toplam_x / 2.0)
	var bas_z = -(toplam_z / 2.0)
	
	# Basit bir kare mesh oluştur (Kenar çizgileri için)
	var mesh = BoxMesh.new()
	mesh.size = Vector3(hucre_boyutu * 0.95, 0.02, hucre_boyutu * 0.95) # Biraz boşluklu olsun
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.3) # Yarı saydam beyaz
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	for x in range(grid_boyutu.x):
		for y in range(grid_boyutu.y):
			var hucre_merkezi_x = bas_x + (float(x) * hucre_boyutu) + (hucre_boyutu / 2.0)
			var hucre_merkezi_z = bas_z + (float(y) * hucre_boyutu) + (hucre_boyutu / 2.0)
			
			var kutu = MeshInstance3D.new()
			kutu.mesh = mesh
			kutu.material_override = mat
			debug_root.add_child(kutu)
			# Grid yöneticisinin kendi koordinat sistemine göre yerleştir
			kutu.position = Vector3(hucre_merkezi_x, 0, hucre_merkezi_z)

# --- STANDART FONKSİYONLAR ---
func set_exclude_rids(rids: Array[RID]) -> void:
	exclude_rids = rids

func clear_exclude_rids() -> void:
	exclude_rids.clear()

func get_masa_world_noktasi() -> Variant:
	if not is_instance_valid(kamera) or not is_instance_valid(masa_node): return null

	var fare_pos = get_viewport().get_mouse_position()
	var from = kamera.project_ray_origin(fare_pos)
	var dir = kamera.project_ray_normal(fare_pos)
	var to = from + dir * ray_uzunlugu

	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = masa_layer_mask
	query.exclude = exclude_rids

	var hit = space.intersect_ray(query)
	
	if not hit.is_empty():
		return hit.position 
	
	return null

func world_to_cell(world_p: Vector3) -> Variant:
	var local_p = to_local(world_p)

	var toplam_x = float(grid_boyutu.x) * hucre_boyutu
	var toplam_z = float(grid_boyutu.y) * hucre_boyutu
	var bas_x = -(toplam_x / 2.0)
	var bas_z = -(toplam_z / 2.0)

	var gx = int(floor((local_p.x - bas_x) / hucre_boyutu))
	var gz = int(floor((local_p.z - bas_z) / hucre_boyutu))

	if gx < 0 or gx >= grid_boyutu.x or gz < 0 or gz >= grid_boyutu.y:
		return null

	return Vector2i(gx, gz)

func cell_center_world(cell: Vector2i) -> Vector3:
	var toplam_x = float(grid_boyutu.x) * hucre_boyutu
	var toplam_z = float(grid_boyutu.y) * hucre_boyutu
	var bas_x = -(toplam_x / 2.0)
	var bas_z = -(toplam_z / 2.0)

	var lx = bas_x + (float(cell.x) * hucre_boyutu) + (hucre_boyutu / 2.0)
	var lz = bas_z + (float(cell.y) * hucre_boyutu) + (hucre_boyutu / 2.0)

	return to_global(Vector3(lx, 0.0, lz))

func can_place(origin: Vector2i, footprint: Array[Vector2i]) -> bool:
	for off in footprint:
		var c = origin + off
		# Sınır kontrolü
		if c.x < 0 or c.x >= grid_boyutu.x or c.y < 0 or c.y >= grid_boyutu.y:
			return false
		# Doluluk kontrolü
		if grid_verisi.has(c):
			return false
	return true

func occupy(origin: Vector2i, footprint: Array[Vector2i], item: Node) -> void:
	for off in footprint:
		grid_verisi[origin + off] = item

func release_owner(item: Node) -> void:
	for k in grid_verisi.keys():
		if grid_verisi[k] == item:
			grid_verisi.erase(k)
