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
@export var debug_modu_aktif: bool = false 

@export_group("Duruş ve Hizalama")
@export var yerlesme_yuksekligi: float = 0.0 
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

# --- RENK SİSTEMİ ---
var mevcut_renk = null 

# SADECE İSTENEN RENKLER (SABİT PALET)
var renk_paleti = [
	Color.ORANGE, 
	Color.YELLOW, 
	Color.BLUE, 
	Color.GREEN
]

func _ready() -> void:
	add_to_group("Blok") 
	
	orjinal_parent = get_parent()
	orjinal_scale = scale
	orjinal_rotasyon_degrees = rotation_degrees
	dik_rotasyon = global_transform.basis.get_rotation_quaternion()
	if hayalet: hayalet.visible = false
	
	anlik_footprint = footprint.duplicate()
	
	if debug_modu_aktif:
		_debug_footprint_ciz()

	# Mantar Modu açıksa doğar doğmaz renklenmeye çalış
	# "call_deferred" kullandığımız için bu işlem karenin en sonunda yapılır.
	# Bu sırada biz çoktan META verisini işlemiş olacağız.
	if GameManager.mantar_modu:
		call_deferred("rastgele_boya")

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

func _yakala(_tiklanan_dunya_pos: Vector3) -> void:
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

func _hayalet_guncelle() -> void:
	if not grid or not hayalet: return
	
	var current_pos_for_grid = global_position 
	current_pos_for_grid.y = grid.global_position.y
	
	var cam = get_viewport().get_camera_3d()
	var grid_y_rot = grid.global_rotation.y
	var cam_y_rot = cam.global_rotation.y
	var rot_diff = wrapf(cam_y_rot - grid_y_rot, -PI, PI)
	
	var ceyrek_turlar = int(round(rot_diff / (PI / 2.0)))
	ceyrek_turlar = (ceyrek_turlar % 4 + 4) % 4
	
	anlik_footprint = _footprint_dondur(footprint, ceyrek_turlar)
	anlik_y_rotasyon = float(ceyrek_turlar) * (PI / 2.0)
	
	var mevcut_scale = hayalet.scale 
	
	var hedef_y_rot = grid.global_rotation.y + anlik_y_rotasyon
	var y_basis = Basis(Vector3.UP, hedef_y_rot)
	var x_basis = Basis(Vector3.RIGHT, deg_to_rad(yatma_acisi.x))
	
	hayalet.global_transform.basis = y_basis * x_basis
	hayalet.scale = mevcut_scale
	
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
					
					var y_deg = rad_to_deg(anlik_y_rotasyon)
					var final_rot = grid_uzerindeki_aci + Vector3(0, y_deg, 0)
					yeni_blok.rotation_degrees = final_rot
					yeni_blok.scale = orjinal_scale 
					
					# --- RENK AKTARIMI (KRİTİK DÜZELTME) ---
					if GameManager.mantar_modu and mevcut_renk != null:
						# ÖNCE: Meta verisine rengi yazıyoruz.
						yeni_blok.set_meta("boyali_renk", mevcut_renk)
						
						# SONRA: Görsel olarak boyuyoruz.
						_recursive_boya(yeni_blok, mevcut_renk)
						
						# NOT: yeni_blok'un _ready fonksiyonu birazdan (deferred olarak)
						# rastgele_boya() çağıracak. Ama aşağıda düzelttiğimiz
						# rastgele_boya fonksiyonu, "boyali_renk" metasını görünce
						# yeni renk üretmekten vazgeçecek!
					# ----------------------------------------
					
					grid.tek_hucre_doldur(hedef_hucre, yeni_blok)
			
			if grid.has_method("satirlari_kontrol_et"):
				grid.satirlari_kontrol_et()
			if hayalet: hayalet.visible = false
			
			emit_signal("blok_yerlesti")
			GameManager.blok_yerlestirildi.emit()
			queue_free() 

	if not basarili:
		_eve_don()

func _eve_don() -> void:
	if hayalet: hayalet.visible = false
	if orjinal_parent and get_parent() != orjinal_parent:
		reparent(orjinal_parent, true)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", orjinal_scale, 0.3)
	tween.tween_property(self, "rotation_degrees", orjinal_rotasyon_degrees, 0.3)

func _debug_footprint_ciz() -> void:
	for c in get_children():
		if c.name == "DebugKure": c.queue_free()
		
	var materyal = StandardMaterial3D.new()
	materyal.albedo_color = Color(0, 1, 0, 0.5)
	materyal.emission_enabled = true
	materyal.emission = Color(0, 1, 0)
	materyal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materyal.no_depth_test = true
	
	for nokta in footprint:
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = BoxMesh.new()
		mesh_inst.mesh.size = Vector3(0.9, 0.9, 0.9) 
		mesh_inst.material_override = materyal
		mesh_inst.name = "DebugKure"
		add_child(mesh_inst)
		mesh_inst.position = Vector3(nokta.x, 0.0, nokta.y)

# --- RENK SİSTEMİ (AKILLI HALE GETİRİLDİ) ---
func rastgele_boya():
	# 1. KONTROL: Eğer bana zaten dışarıdan bir renk atandıysa (Meta varsa)
	# O zaman rastgele renk üretme, o rengi kullan!
	if has_meta("boyali_renk"):
		var atanan_renk = get_meta("boyali_renk")
		# Hafızaya da alalım ki karışıklık olmasın
		mevcut_renk = atanan_renk 
		_recursive_boya(self, atanan_renk)
		return # FONKSİYONDAN ÇIK, YENİ RENK ÜRETME

	# 2. Eğer atanan renk yoksa (İlk doğuş), paletten seç
	mevcut_renk = renk_paleti.pick_random()
	
	# Kendini boya
	_recursive_boya(self, mevcut_renk)

func _recursive_boya(node: Node, renk: Color):
	# Eğer bu düğüm bir MeshInstance3D ise boya
	if node is MeshInstance3D:
		_materyal_uygula(node, renk)
	
	# Sonra bu düğümün çocuklarını gez
	for child in node.get_children():
		_recursive_boya(child, renk)

func _materyal_uygula(mesh: MeshInstance3D, renk: Color):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = renk
	mat.emission_enabled = true
	mat.emission = renk
	mat.emission_energy_multiplier = 1.0 
	mesh.material_override = mat
