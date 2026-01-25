extends Node3D
class_name BlokSurukle

signal blok_yerlesti 

# --- BAĞLANTILAR ---
@export_group("Bağlantılar")
@export var grid: GridYonetici
@export var hayalet: Node3D
@export var hayalet_mat: StandardMaterial3D
@export var tekli_blok_sahnesi: PackedScene 

# --- AYARLAR ---
@export_group("Ayarlar")
@export var footprint: Array[Vector2i] = [Vector2i(0,0)]
@export var hover_y_offset: float = 0.5 
@export var kilitlenince_tuket: bool = true
@export var debug_modu_aktif: bool = true # Kırmızı topları aç/kapat

@export_group("Duruş ve Hizalama")
@export var yerlesme_yuksekligi: float = 0.0 
# Yatma açısını sadece GÖRSEL düzeltme için kullanacağız
@export var yatma_acisi: Vector3 = Vector3(-90, 0, 0) 
@export var grid_uzerindeki_aci: Vector3 = Vector3.ZERO 

var tutuluyor: bool = false
var kilitlendi: bool = false
var son_hucre: Variant = null
var tutma_offseti: Vector3 = Vector3.ZERO 
var orjinal_parent: Node = null
var orjinal_scale: Vector3 = Vector3.ONE
var dik_rotasyon: Quaternion
var orjinal_rotasyon_degrees: Vector3

# Dinamik Hesaplamalar
var anlik_footprint: Array[Vector2i] = [] 
var anlik_y_rotasyon: float = 0.0         

func _ready() -> void:
	orjinal_parent = get_parent()
	orjinal_scale = scale
	orjinal_rotasyon_degrees = rotation_degrees
	dik_rotasyon = global_transform.basis.get_rotation_quaternion()
	if hayalet: hayalet.visible = false
	
	# Başlangıç footprint'ini al
	anlik_footprint = footprint.duplicate()
	
	# DEBUG: Kırmızı topları çiz
	if debug_modu_aktif:
		_debug_footprint_ciz()

func _process(delta: float) -> void:
	if tutuluyor and not kilitlendi:
		_gorsel_mouse_takip(delta)
		_hayalet_guncelle()

func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx) -> void:
	if kilitlendi: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not tutuluyor:
			_yakala(_position)

func _input(event: InputEvent) -> void:
	if tutuluyor and not kilitlendi and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and (not event.pressed):
			_birak()

func _yakala(tiklanan_dunya_pos: Vector3) -> void:
	tutuluyor = true
	son_hucre = null
	if grid: grid.release_owner(self)
	if hayalet: hayalet.visible = true
	var main_scene = get_tree().current_scene
	if main_scene: reparent(main_scene, true)
	global_transform.basis = Basis(dik_rotasyon).scaled(orjinal_scale)
	tutma_offseti = Vector3.ZERO

func _gorsel_mouse_takip(delta: float) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	var fare_pos = get_viewport().get_mouse_position()
	var zemin_yuksekligi = 0.0
	if grid: zemin_yuksekligi = grid.global_position.y
	
	var hareket_duzlemi = Plane(Vector3.UP, zemin_yuksekligi + hover_y_offset)
	var from = cam.project_ray_origin(fare_pos)
	var dir = cam.project_ray_normal(fare_pos)
	var kesisim = hareket_duzlemi.intersects_ray(from, dir)
	
	if kesisim:
		var hedef_pos = kesisim + tutma_offseti
		global_position = global_position.lerp(hedef_pos, 25.0 * delta)

# --- AÇIYA GÖRE HAYALET VE FOOTPRINT GÜNCELLEME ---
func _hayalet_guncelle() -> void:
	if not grid or not hayalet: return
	
	hayalet.scale = Vector3.ONE 
	var current_pos_for_grid = global_position 
	current_pos_for_grid.y = grid.global_position.y
	
	# 1. AÇI HESABI (Oyuncu Masanın Neresinde?)
	var cam = get_viewport().get_camera_3d()
	var grid_y_rot = grid.global_rotation.y
	var cam_y_rot = cam.global_rotation.y
	var rot_diff = wrapf(cam_y_rot - grid_y_rot, -PI, PI)
	
	var ceyrek_turlar = int(round(rot_diff / (PI / 2.0)))
	ceyrek_turlar = (ceyrek_turlar % 4 + 4) % 4
	
	# 2. FOOTPRINT ÇEVİRME
	anlik_footprint = _footprint_dondur(footprint, ceyrek_turlar)
	anlik_y_rotasyon = float(ceyrek_turlar) * (PI / 2.0)
	
	# 3. GÖRSEL DÖNDÜRME
	# Önce rotasyonu sıfırla
	hayalet.global_rotation = Vector3.ZERO
	# Ana yönü ver (Grid + Oyuncu açısı)
	hayalet.rotation.y = grid.global_rotation.y + anlik_y_rotasyon
	
	# Sonra "Yatır" (Local X ekseninde)
	hayalet.rotate_object_local(Vector3.RIGHT, deg_to_rad(yatma_acisi.x))
	
	# -----------------------------------------------------

	var vcell = grid.world_to_cell(current_pos_for_grid)
	if vcell == null:
		son_hucre = null
		_set_hayalet_color(false)
		hayalet.global_position = global_position
		hayalet.global_position.y = grid.global_position.y + 0.1
		return

	var cell = vcell as Vector2i
	son_hucre = cell
	var uygun = grid.can_place(cell, anlik_footprint)
	_set_hayalet_color(uygun)

	var center = grid.cell_center_world(cell)
	var kaldirma_vektoru = Vector3.UP * yerlesme_yuksekligi
	hayalet.global_position = center + kaldirma_vektoru

func _footprint_dondur(orj_fp: Array[Vector2i], tur_sayisi: int) -> Array[Vector2i]:
	if tur_sayisi == 0: return orj_fp.duplicate()
	var yeni_fp: Array[Vector2i] = []
	for p in orj_fp:
		var yeni_p = p
		for i in range(tur_sayisi):
			var temp = yeni_p.x
			yeni_p.x = yeni_p.y
			yeni_p.y = -temp
		yeni_fp.append(yeni_p)
	return yeni_fp

func _set_hayalet_color(ok: bool) -> void:
	if not hayalet_mat: return
	if ok: hayalet_mat.albedo_color = Color(0, 1, 0, 0.5)
	else: hayalet_mat.albedo_color = Color(1, 0, 0, 0.5)

func _birak() -> void:
	tutuluyor = false
	if grid:
		var anlik_blok_merkezi = global_position
		anlik_blok_merkezi.y = grid.global_position.y 
		var anlik_hucre = grid.world_to_cell(anlik_blok_merkezi)
		if anlik_hucre != null: son_hucre = anlik_hucre

	var basarili = false
	if grid and son_hucre != null:
		var origin_cell = son_hucre as Vector2i
		if grid.can_place(origin_cell, anlik_footprint):
			basarili = true
			if tekli_blok_sahnesi:
				for offset in anlik_footprint:
					var hedef_hucre = origin_cell + offset
					var yeni_blok = tekli_blok_sahnesi.instantiate()
					grid.add_child(yeni_blok)
					var pos = grid.cell_center_world(hedef_hucre)
					yeni_blok.global_position = pos
					
					# Yerleştirilen bloğun açısını ayarla
					var y_deg = rad_to_deg(anlik_y_rotasyon)
					var final_rot = grid_uzerindeki_aci + Vector3(0, y_deg, 0)
					yeni_blok.rotation_degrees = final_rot
					yeni_blok.scale = orjinal_scale 
					grid.tek_hucre_doldur(hedef_hucre, yeni_blok)
			
			if grid.has_method("satirlari_kontrol_et"):
				grid.satirlari_kontrol_et()
			if hayalet: hayalet.visible = false
			emit_signal("blok_yerlesti")
			queue_free() 

	if not basarili:
		_eve_don()

func _eve_don() -> void:
	if hayalet: hayalet.visible = false
	if orjinal_parent:
		reparent(orjinal_parent, false)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "position", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", orjinal_scale, 0.3)
		tween.tween_property(self, "rotation_degrees", orjinal_rotasyon_degrees, 0.3)

# --- DEBUG MODU (KESİN KOORDİNAT GÖSTERİCİ) ---
func _debug_footprint_ciz() -> void:
	# Varsa eskileri temizle
	for c in get_children():
		if c.name == "DebugKure": c.queue_free()
		
	var materyal = StandardMaterial3D.new()
	materyal.albedo_color = Color(0, 1, 0, 0.5) # YEŞİL olsun ki kırmızı blokla karışmasın
	materyal.emission_enabled = true
	materyal.emission = Color(0, 1, 0)
	materyal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materyal.no_depth_test = true # Bloğun içinden görünsün
	
	# Her bir footprint noktası için KUTU oluştur
	for nokta in footprint:
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = BoxMesh.new()
		
		# Boyutu biraz küçültelim (0.9) ki grid sınırlarını göstersin
		mesh_inst.mesh.size = Vector3(0.9, 0.9, 0.9) 
		
		mesh_inst.material_override = materyal
		mesh_inst.name = "DebugKure"
		add_child(mesh_inst)
		
		# --- KRİTİK EKSEN DÖNÜŞÜMÜ ---
		# Footprint X -> Dünya X
		# Footprint Y -> Dünya Z (Godot'da zemin Z eksenidir)
		# Yükseklik   -> 0 (veya bloğun merkezi olan 0.0)
		
		# Eğer bloklarının pivotu alttaysa Y=0.5 yapmalıyız.
		# Eğer bloklarının pivotu ortadaysa Y=0.0 yapmalıyız.
		# Şimdilik "yerlesme_yuksekligi"ni de hesaba katalım.
		
		mesh_inst.position = Vector3(nokta.x, 0.0, nokta.y)
