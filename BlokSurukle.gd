extends Node3D
class_name BlokSurukle

# --- BAĞLANTILAR ---
@export_group("Bağlantılar")
@export var grid: GridYonetici
@export var hayalet: Node3D
@export var hayalet_mat: StandardMaterial3D

# --- AYARLAR ---
@export_group("Ayarlar")
@export var footprint: Array[Vector2i] = [Vector2i(0,0)]
@export var hover_y_offset: float = 1.0 # Elindeyken ne kadar yukarıda dursun?
@export var kilitlenince_tuket: bool = true

@export_group("Duruş ve Hizalama")
# Blok masaya konduğunda yerden ne kadar yukarıda dursun?
# Blok masanın içine giriyorsa bunu 0.5, 1.0 gibi artır.
@export var yerlesme_yuksekligi: float = 0.5 

# Blok masaya konduğunda nasıl yatsın?
@export var yatma_acisi: Vector3 = Vector3(-90, 0, 0) 

# --- DURUM DEĞİŞKENLERİ ---
var tutuluyor: bool = false
var kilitlendi: bool = false
var son_hucre: Variant = null

# --- HAFIZA ---
var orjinal_parent: Node = null
var orjinal_scale: Vector3 = Vector3.ONE
var baslangic_global_pos: Vector3 = Vector3.ZERO
var dik_rotasyon: Quaternion

func _ready() -> void:
	orjinal_parent = get_parent()
	orjinal_scale = scale
	baslangic_global_pos = global_position
	
	# Oyun başlarkenki duruşu kaydet
	dik_rotasyon = global_transform.basis.get_rotation_quaternion()
	
	if hayalet: hayalet.visible = false

func _process(_delta: float) -> void:
	if tutuluyor and not kilitlendi:
		_gorsel_mouse_takip()
		_hayalet_guncelle()
		# Tutarken şekli koru
		global_transform.basis = Basis(dik_rotasyon).scaled(orjinal_scale)

# --- INPUT ---
func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx) -> void:
	if kilitlendi: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not tutuluyor:
			_yakala()

func _input(event: InputEvent) -> void:
	if tutuluyor and not kilitlendi and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and (not event.pressed):
			_birak()

# --- YAKALAMA ---
func _yakala() -> void:
	tutuluyor = true
	son_hucre = null
	
	if grid:
		grid.release_owner(self)
		grid.set_exclude_rids(_alt_collision_rids())

	if hayalet: hayalet.visible = true

	var main_scene = get_tree().current_scene
	if main_scene:
		reparent(main_scene, true)
	
	global_transform.basis = Basis(dik_rotasyon).scaled(orjinal_scale)
	_gorsel_mouse_takip()

# --- FARE TAKİBİ ---
func _gorsel_mouse_takip() -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	var fare_pos = get_viewport().get_mouse_position()
	
	# Masanın açısını boşver, her zaman YER ÇEKİMİNE ZIT (Vector3.UP) hareket et.
	var hareket_normali = Vector3.UP
	
	var zemin_yuksekligi = 0.0
	if grid:
		zemin_yuksekligi = grid.global_position.y
	
	var hareket_duzlemi = Plane(hareket_normali, zemin_yuksekligi + hover_y_offset)
	
	var from = cam.project_ray_origin(fare_pos)
	var dir = cam.project_ray_normal(fare_pos)
	
	var kesisim = hareket_duzlemi.intersects_ray(from, dir)
	
	if kesisim:
		global_position = global_position.lerp(kesisim, 0.5)

# --- HAYALET ---
func _hayalet_guncelle() -> void:
	if not grid or not hayalet: return

	var vwp = grid.get_masa_world_noktasi()
	if vwp == null:
		hayalet.visible = false; son_hucre = null; return

	hayalet.visible = true
	var world_p = vwp as Vector3
	var vcell = grid.world_to_cell(world_p)
	
	# Hayaleti yatır
	hayalet.global_rotation = grid.masa_node.global_rotation 
	hayalet.rotate_object_local(Vector3.RIGHT, deg_to_rad(yatma_acisi.x))
	hayalet.rotate_object_local(Vector3.UP, deg_to_rad(yatma_acisi.y))
	hayalet.rotate_object_local(Vector3.FORWARD, deg_to_rad(yatma_acisi.z))
	
	# --- DÜZELTME: Kaldırma yönünü Vector3.UP (Dünya Yukarısı) yaptık ---
	var kaldirma_vektoru = Vector3.UP * yerlesme_yuksekligi

	if vcell == null:
		son_hucre = null
		_set_hayalet_color(false)
		# Grid dışındayken mouse hizasında kalsın
		# Burada da Vector3.UP kullanıyoruz ki havada dursun
		hayalet.global_position = world_p + (Vector3.UP * 0.1)
		return

	var cell = vcell as Vector2i
	son_hucre = cell
	var uygun = grid.can_place(cell, footprint)
	_set_hayalet_color(uygun)

	var center = grid.cell_center_world(cell)
	hayalet.global_position = center + kaldirma_vektoru

func _set_hayalet_color(ok: bool) -> void:
	if not hayalet_mat: return
	if ok:
		hayalet_mat.albedo_color = Color(0, 1, 0, 0.5)
	else:
		hayalet_mat.albedo_color = Color(1, 0, 0, 0.5)

# --- BIRAKMA ---
func _birak() -> void:
	tutuluyor = false
	if grid: grid.clear_exclude_rids()

	var basarili = false
	
	if grid and son_hucre != null:
		var cell = son_hucre as Vector2i
		if grid.can_place(cell, footprint):
			basarili = true
			
			reparent(grid, true)
			scale = orjinal_scale
			
			# Yatış pozisyonu
			global_rotation = grid.masa_node.global_rotation
			rotate_object_local(Vector3.RIGHT, deg_to_rad(yatma_acisi.x))
			rotate_object_local(Vector3.UP, deg_to_rad(yatma_acisi.y))
			rotate_object_local(Vector3.FORWARD, deg_to_rad(yatma_acisi.z))
			
			# Yerleşme
			var center = grid.cell_center_world(cell)
			
			# --- DÜZELTME: Yerleştirirken de Vector3.UP kullanıyoruz ---
			global_position = center + (Vector3.UP * yerlesme_yuksekligi)
			
			grid.occupy(cell, footprint, self)
			
			if hayalet: hayalet.visible = false
			if kilitlenince_tuket: kilitlendi = true

	if not basarili:
		_eve_don()

# --- EVE DÖNÜŞ ---
func _eve_don() -> void:
	if hayalet: hayalet.visible = false
	if orjinal_parent:
		reparent(orjinal_parent, false)
	
	global_position = baslangic_global_pos
	global_transform.basis = Basis(dik_rotasyon).scaled(orjinal_scale)

func _alt_collision_rids() -> Array[RID]:
	var rids: Array[RID] = []
	var area = find_child("Area3D", true, false)
	if area: rids.append(area.get_rid())
	return rids
