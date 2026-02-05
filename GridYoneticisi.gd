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
var grid_verisi: Dictionary = {} 
var arayuz: CanvasLayer = null 

# HEDEF GÖSTERGESİ (Kılıç/Fırça için)
var hedef_kare: MeshInstance3D = null

func set_exclude_rids(_rids: Array[RID]) -> void: pass
func clear_exclude_rids() -> void: pass

func _ready() -> void:
	_gridi_yenile()
	arayuz = get_tree().get_first_node_in_group("Arayuz")
	_hedef_kare_olustur()

func _hedef_kare_olustur():
	# Kırmızı yarı saydam bir kare oluşturuyoruz
	hedef_kare = MeshInstance3D.new()
	hedef_kare.mesh = BoxMesh.new()
	hedef_kare.mesh.size = Vector3(hucre_boyutu, 0.1, hucre_boyutu)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.5) # Kırmızı
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hedef_kare.material_override = mat
	add_child(hedef_kare)
	hedef_kare.visible = false

# --- GÖRSEL OLUŞTURMA ---
func _gridi_yenile() -> void:
	if not is_inside_tree(): return
	for child in get_children():
		if child is MeshInstance3D and not child.name.begins_with("Block") and child != hedef_kare:
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
	
	# Blok yerleşti, renk bonusunu kontrol et (Mantar veya doğal uyum)
	_renk_bonusu_kontrol(cell, item)

func release_owner(item: Node) -> void:
	pass

# --- 🔥 PUAN VE BONUS SİSTEMİ 🔥 ---

func _renk_bonusu_kontrol(hucre: Vector2i, yeni_blok: Node3D):
	# Blokta "boyali_renk" verisi var mı bak (Mantar etkisi)
	# Yoksa kendi materyalinden rengi bulmaya çalış (Basitçe şimdilik meta verisine güveniyoruz)
	var renk = null
	if yeni_blok.has_meta("boyali_renk"):
		renk = yeni_blok.get_meta("boyali_renk")
	elif yeni_blok.has_meta("renk"):
		renk = yeni_blok.get_meta("renk")
	
	if renk == null: return # Renk verisi yoksa geç

	var komsular = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var bonus_var = false
	
	for k in komsular:
		var bakilan = hucre + k
		if grid_verisi.has(bakilan):
			var komsu = grid_verisi[bakilan]
			# Komşunun rengiyle karşılaştır
			var komsu_renk = null
			if komsu.has_meta("boyali_renk"): komsu_renk = komsu.get_meta("boyali_renk")
			elif komsu.has_meta("renk"): komsu_renk = komsu.get_meta("renk")
			
			if komsu_renk != null and komsu_renk == renk:
				bonus_var = true
				break # Bir tane bile uysa yeter
	
	if bonus_var:
		print("🌈 RENK UYUMU! x1.5 Puan Bonusu!")
		# Normal puanı BlokSurukle hesaplıyor ama bonusu buradan ekleyebiliriz
		emit_signal("puan_kazanildi", 50) # Ekstra puan

# --- 🔥 ÖZEL EŞYA ETKİLERİ İÇİN FONKSİYONLAR 🔥 ---

func hedef_goster(hucre: Vector2i, aktif: bool):
	if hedef_kare:
		hedef_kare.visible = aktif
		if aktif:
			hedef_kare.global_position = cell_center_world(hucre)
			# Yüksekliği biraz artırıp z-fighting önle
			hedef_kare.global_position.y += 0.05

# 1. KILIÇ: Blok düşürme
func blok_dusur(hucre: Vector2i):
	if grid_verisi.has(hucre):
		var blok = grid_verisi[hucre]
		grid_verisi.erase(hucre)
		
		# Fiziksel düşüş
		var tween = create_tween()
		tween.tween_property(blok, "position:y", -5.0, 0.5).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_callback(blok.queue_free)

# 2. FIRÇA: Bloğu boya (Joker yap)
func bloku_boya(hucre: Vector2i, renk: Color):
	if grid_verisi.has(hucre):
		var blok = grid_verisi[hucre]
		blok.set_meta("boyali_renk", renk) # Joker rengi ata
		
		# Görseli güncelle
		var mesh = blok.find_child("MeshInstance3D", true, false)
		if mesh:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = renk
			mesh.material_override = mat

# 3. ASİT: Sütun silme
func sutunu_yok_et(hucre: Vector2i):
	var patlayacaklar = []
	for y in range(grid_boyutu.y):
		var h = Vector2i(hucre.x, y)
		if grid_verisi.has(h):
			patlayacaklar.append(h)
	
	if patlayacaklar.size() > 0:
		_bloklari_yok_et(patlayacaklar)

# --- STANDART PATLATMA SİSTEMİ ---
func satirlari_kontrol_et() -> void:
	var patlayacak_hucreler = []
	var patlayan_satir_sayisi = 0
	
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
	
	if patlayacak_hucreler.size() > 0:
		_bloklari_yok_et(patlayacak_hucreler)
		_puan_hesapla(patlayan_satir_sayisi, patlayacak_hucreler.size())
		GameManager.satir_patladi.emit()

func _bloklari_yok_et(hucreler: Array) -> void:
	for h in hucreler:
		if grid_verisi.has(h):
			var blok = grid_verisi[h]
			if patlama_efekti_sahnesi and blok:
				var efekt = patlama_efekti_sahnesi.instantiate()
				add_child(efekt)
				efekt.global_position = blok.global_position
				var mesh = blok.find_child("MeshInstance3D", true, false)
				if mesh and mesh.get_active_material(0):
					efekt.draw_pass_1.material.albedo_color = mesh.get_active_material(0).albedo_color

			grid_verisi.erase(h)
			if blok: blok.queue_free()

func _puan_hesapla(satir_sayisi: int, blok_sayisi: int) -> void:
	var bonus = 1
	if satir_sayisi > 1: bonus = pow(2, satir_sayisi - 1)
	var toplam_puan = (blok_sayisi * 10) * bonus
	
	get_tree().call_group("Arayuz", "puan_ekle", 100, "Sıra Temizlendi")
	emit_signal("puan_kazanildi", toplam_puan)
	
	if arayuz:
		var mesaj = "%d Satır Temizlendi!" % satir_sayisi
		if satir_sayisi > 1: mesaj += " (x%d KOMBO)" % bonus
		arayuz.puan_ekle(toplam_puan, mesaj)
