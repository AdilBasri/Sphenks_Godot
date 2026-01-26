@tool
extends Node3D
class_name GridYonetici

# --- DIŞARIYA AÇIK AYARLAR ---
@export var patlama_efekti_sahnesi: PackedScene 

# --- SİNYALLER ---
signal puan_kazanildi(miktar: int)

# --- GRID AYARLARI ---
@export_group("Grid Ayarları")
@export var grid_boyutu: Vector2i = Vector2i(8, 8):
	set(v):
		grid_boyutu = v
		if is_inside_tree(): _gridi_yenile()

@export var hucre_boyutu: float = 1.0:
	set(v):
		hucre_boyutu = v
		if is_inside_tree(): _gridi_yenile()

@export_group("Renkler")
@export var renk_1: Color = Color(0.2, 0.2, 0.2) 
@export var renk_2: Color = Color(0.4, 0.4, 0.4) 

# --- DEĞİŞKENLER ---
var grid_verisi: Dictionary = {} # { Vector2i(x,y): Node3D }
var arayuz: CanvasLayer = null # UI Erişimi için

# Fiziksel harici durumlar için boş fonksiyonlar
func set_exclude_rids(_rids: Array[RID]) -> void: pass
func clear_exclude_rids() -> void: pass

func _ready() -> void:
	_gridi_yenile()
	# UI Grubunu bul ve bağlan
	arayuz = get_tree().get_first_node_in_group("Arayuz")

# --- GÖRSEL OLUŞTURMA ---
func _gridi_yenile() -> void:
	if not is_inside_tree(): return
	for child in get_children():
		# Sadece zemin karelerini sil, blokları veya efektleri silme
		if child is MeshInstance3D and not child.name.begins_with("Block"):
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

# --- MATEMATİKSEL HESAPLAMALAR ---
func get_masa_world_noktasi() -> Variant:
	var kamera = get_viewport().get_camera_3d()
	if not kamera: return null
	
	var fare_pos = get_viewport().get_mouse_position()
	var matematik_duzlemi = Plane(Vector3.UP, global_position.y)
	
	var from = kamera.project_ray_origin(fare_pos)
	var dir = kamera.project_ray_normal(fare_pos)
	var kesisim = matematik_duzlemi.intersects_ray(from, dir)
	
	if kesisim:
		if _nokta_grid_icinde_mi(kesisim):
			return kesisim
	return null

func _nokta_grid_icinde_mi(nokta: Vector3) -> bool:
	var local_p = to_local(nokta)
	var toplam_genislik = float(grid_boyutu.x) * hucre_boyutu
	var toplam_uzunluk = float(grid_boyutu.y) * hucre_boyutu
	var yarim_x = toplam_genislik / 2.0
	var yarim_z = toplam_uzunluk / 2.0
	
	if local_p.x < -yarim_x - 0.2 or local_p.x > yarim_x + 0.2: return false
	if local_p.z < -yarim_z - 0.2 or local_p.z > yarim_z + 0.2: return false
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

# --- YERLEŞTİRME MANTIĞI ---
func can_place(origin: Vector2i, footprint: Array[Vector2i]) -> bool:
	for off in footprint:
		var c = origin + off
		if c.x < 0 or c.x >= grid_boyutu.x or c.y < 0 or c.y >= grid_boyutu.y:
			return false
		if grid_verisi.has(c):
			return false
	return true

func tek_hucre_doldur(cell: Vector2i, item: Node3D) -> void:
	grid_verisi[cell] = item

func release_owner(item: Node) -> void:
	pass

# --- 🔥 PATLATMA, EFEKT ve PUAN MANTIĞI 🔥 ---
func satirlari_kontrol_et() -> void:
	var patlayacak_hucreler = []
	var patlayan_satir_sayisi = 0
	
	# 1. SÜTUNLARI TARA
	for x in range(grid_boyutu.x):
		var dolu_mu = true
		for y in range(grid_boyutu.y):
			if not grid_verisi.has(Vector2i(x, y)):
				dolu_mu = false; break
		if dolu_mu:
			patlayan_satir_sayisi += 1
			for y in range(grid_boyutu.y):
				var h = Vector2i(x, y)
				if not h in patlayacak_hucreler: patlayacak_hucreler.append(h)

	# 2. SATIRLARI TARA
	for y in range(grid_boyutu.y):
		var dolu_mu = true
		for x in range(grid_boyutu.x):
			if not grid_verisi.has(Vector2i(x, y)):
				dolu_mu = false; break
		if dolu_mu:
			patlayan_satir_sayisi += 1
			for x in range(grid_boyutu.x):
				var h = Vector2i(x, y)
				if not h in patlayacak_hucreler: patlayacak_hucreler.append(h)
	
	# 3. İŞLEM YAP
	if patlayacak_hucreler.size() > 0:
		_bloklari_yok_et(patlayacak_hucreler)
		_puan_hesapla(patlayan_satir_sayisi, patlayacak_hucreler.size())

func _bloklari_yok_et(hucreler: Array) -> void:
	for h in hucreler:
		if grid_verisi.has(h):
			var blok = grid_verisi[h]
			
			# --- PARÇACIK EFEKTİ ---
			if patlama_efekti_sahnesi and blok:
				var efekt = patlama_efekti_sahnesi.instantiate()
				add_child(efekt)
				efekt.global_position = blok.global_position
				
				# Renk Transferi
				var mesh = blok.find_child("MeshInstance3D", true, false)
				if mesh and mesh.get_active_material(0):
					var blok_rengi = mesh.get_active_material(0).albedo_color
					efekt.draw_pass_1.material.albedo_color = blok_rengi

			grid_verisi.erase(h)
			if blok:
				blok.queue_free()

func _puan_hesapla(satir_sayisi: int, blok_sayisi: int) -> void:
	# Bonus Sistemi: Çoklu satırda puan katlanır
	var bonus = 1
	if satir_sayisi > 1:
		bonus = pow(2, satir_sayisi - 1)
	
	var toplam_puan = (blok_sayisi * 10) * bonus
	
	print("--- PATLATMA ---")
	print("Satır: ", satir_sayisi, " | Blok: ", blok_sayisi, " | PUAN: ", toplam_puan)
	get_tree().call_group("Arayuz", "puan_ekle", 100, "Sıra Temizlendi")
	emit_signal("puan_kazanildi", toplam_puan)
	
	# --- UI GÜNCELLEME ---
	if arayuz:
		var mesaj = "%d Satır Temizlendi!" % satir_sayisi
		if satir_sayisi > 1: mesaj += " (x%d KOMBO)" % bonus
		arayuz.puan_ekle(toplam_puan, mesaj)
