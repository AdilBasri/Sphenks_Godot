@tool
extends Node3D
class_name GridYonetici

# --- AYARLAR ---
@export_group("Grid Ayarları")
@export var grid_boyutu: Vector2i = Vector2i(8, 8):
	set(v):
		grid_boyutu = v
		if Engine.is_editor_hint(): _gridi_yenile()

@export var hucre_boyutu: float = 1.0:
	set(v):
		hucre_boyutu = v
		if Engine.is_editor_hint(): _gridi_yenile()

@export_group("Renkler")
@export var renk_1: Color = Color(0.2, 0.2, 0.2) 
@export var renk_2: Color = Color(0.4, 0.4, 0.4) 

# --- DEĞİŞKENLER ---
var grid_verisi: Dictionary = {}

# Fizik kullanmadığımız için bu fonksiyonları boş tutuyoruz (Hata vermemesi için)
func set_exclude_rids(_rids: Array[RID]) -> void: pass
func clear_exclude_rids() -> void: pass

func _ready() -> void:
	_gridi_yenile()

# --- SADECE GÖRSEL (Fizik Collider Yok) ---
func _gridi_yenile() -> void:
	for child in get_children():
		child.queue_free()
	
	grid_verisi.clear()
	
	var mesh_size = Vector2(hucre_boyutu, hucre_boyutu)
	var quad_mesh = PlaneMesh.new()
	quad_mesh.size = mesh_size
	
	var mat1 = StandardMaterial3D.new(); mat1.albedo_color = renk_1
	var mat2 = StandardMaterial3D.new(); mat2.albedo_color = renk_2
	
	var toplam_genislik = float(grid_boyutu.x) * hucre_boyutu
	var toplam_uzunluk = float(grid_boyutu.y) * hucre_boyutu
	var baslangic_x = -(toplam_genislik / 2.0) + (hucre_boyutu / 2.0)
	var baslangic_z = -(toplam_uzunluk / 2.0) + (hucre_boyutu / 2.0)
	
	for x in range(grid_boyutu.x):
		for y in range(grid_boyutu.y):
			var tile = MeshInstance3D.new()
			tile.mesh = quad_mesh
			tile.material_override = mat1 if (x + y) % 2 == 0 else mat2
			
			var pos_x = baslangic_x + (x * hucre_boyutu)
			var pos_z = baslangic_z + (y * hucre_boyutu)
			tile.position = Vector3(pos_x, 0, pos_z)
			add_child(tile)

# --- MATEMATİKSEL DÜZLEM HESABI (Fizik Yerine) ---
func get_masa_world_noktasi() -> Variant:
	var kamera = get_viewport().get_camera_3d()
	if not kamera: return null
	
	var fare_pos = get_viewport().get_mouse_position()
	
	# Sonsuz bir zemin düzlemi (Y = 0)
	# Grid'in kendi yüksekliğini baz alıyoruz.
	var matematik_duzlemi = Plane(Vector3.UP, global_position.y)
	
	var from = kamera.project_ray_origin(fare_pos)
	var dir = kamera.project_ray_normal(fare_pos)
	
	# Işın düzlemi nerede kesiyor?
	var kesisim = matematik_duzlemi.intersects_ray(from, dir)
	
	if kesisim:
		# Grid sınırları içinde mi?
		if _nokta_grid_icinde_mi(kesisim):
			return kesisim
			
	return null

func _nokta_grid_icinde_mi(nokta: Vector3) -> bool:
	var local_p = to_local(nokta)
	var toplam_genislik = float(grid_boyutu.x) * hucre_boyutu
	var toplam_uzunluk = float(grid_boyutu.y) * hucre_boyutu
	
	var yarim_x = toplam_genislik / 2.0
	var yarim_z = toplam_uzunluk / 2.0
	
	# Hafif tolerans (0.01) ekledik ki sınırdakileri kaçırmasın
	if local_p.x < -yarim_x - 0.01 or local_p.x > yarim_x + 0.01: return false
	if local_p.z < -yarim_z - 0.01 or local_p.z > yarim_z + 0.01: return false
	
	return true

func world_to_cell(world_p: Vector3) -> Variant:
	var local_p = to_local(world_p)
	var toplam_genislik = float(grid_boyutu.x) * hucre_boyutu
	var toplam_uzunluk = float(grid_boyutu.y) * hucre_boyutu
	var baslangic_x = -(toplam_genislik / 2.0)
	var baslangic_z = -(toplam_uzunluk / 2.0)
	
	var gx = int(floor((local_p.x - baslangic_x + 0.001) / hucre_boyutu))
	var gz = int(floor((local_p.z - baslangic_z + 0.001) / hucre_boyutu))
	
	if gx < 0 or gx >= grid_boyutu.x or gz < 0 or gz >= grid_boyutu.y:
		return null
	return Vector2i(gx, gz)

func cell_center_world(cell: Vector2i) -> Vector3:
	var toplam_genislik = float(grid_boyutu.x) * hucre_boyutu
	var toplam_uzunluk = float(grid_boyutu.y) * hucre_boyutu
	var baslangic_x = -(toplam_genislik / 2.0) + (hucre_boyutu / 2.0)
	var baslangic_z = -(toplam_uzunluk / 2.0) + (hucre_boyutu / 2.0)
	var lx = baslangic_x + (cell.x * hucre_boyutu)
	var lz = baslangic_z + (cell.y * hucre_boyutu)
	return to_global(Vector3(lx, 0.0, lz))

func can_place(origin: Vector2i, footprint: Array[Vector2i]) -> bool:
	for off in footprint:
		var c = origin + off
		if c.x < 0 or c.x >= grid_boyutu.x or c.y < 0 or c.y >= grid_boyutu.y:
			return false
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
