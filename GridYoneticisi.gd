@tool
extends Node3D
class_name GridYonetici

# --- DIŞARIYA AÇIK AYARLAR ---
@export var patlama_efekti_sahnesi: PackedScene 
@export var kamera_sarsinti_scripti: Node3D 

# --- 🔥 YENİ AYAR: TAŞ/ASİT YÜKSEKLİĞİ 🔥 ---
# Burayı Inspector'dan -1, -2, -5 yaparak taşların zemine oturmasını sağla!
@export var engel_yuksekligi: float = 0.0 

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
var kilitli_hucreler: Dictionary = {} 
var arayuz: CanvasLayer = null 
var hedef_kare: MeshInstance3D = null
var kombo_carpani: int = 1
var kombo_suresi: float = 0.0
var max_kombo_suresi: float = 4.0

func _ready() -> void:
	_gridi_yenile()
	arayuz = get_tree().get_first_node_in_group("Arayuz")
	if not kamera_sarsinti_scripti:
		var cam = get_viewport().get_camera_3d()
		if cam and cam.has_method("shake"): kamera_sarsinti_scripti = cam
	_hedef_kare_olustur()

func _process(delta):
	if kombo_carpani > 1:
		kombo_suresi -= delta
		if kombo_suresi <= 0: kombo_carpani = 1

func _hedef_kare_olustur():
	hedef_kare = MeshInstance3D.new()
	hedef_kare.mesh = BoxMesh.new()
	hedef_kare.mesh.size = Vector3(hucre_boyutu, 0.1, hucre_boyutu)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.5) 
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hedef_kare.material_override = mat
	add_child(hedef_kare)
	hedef_kare.visible = false

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

func get_masa_world_noktasi() -> Variant:
	var kamera = get_viewport().get_camera_3d()
	if not kamera: return null
	var fare_pos = get_viewport().get_mouse_position()
	var matematik_duzlemi = Plane(Vector3.UP, global_position.y)
	var from = kamera.project_ray_origin(fare_pos)
	var dir = kamera.project_ray_normal(fare_pos)
	var kesisim = matematik_duzlemi.intersects_ray(from, dir)
	if kesisim:
		if _nokta_grid_icinde_mi(kesisim): return kesisim
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
	if gx < 0 or gx >= grid_boyutu.x or gz < 0 or gz >= grid_boyutu.y: return null
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
		if c.x < 0 or c.x >= grid_boyutu.x or c.y < 0 or c.y >= grid_boyutu.y: return false
		if grid_verisi.has(c): return false
		if kilitli_hucreler.has(c): return false 
	return true

func tek_hucre_doldur(cell: Vector2i, item: Node3D) -> void:
	grid_verisi[cell] = item

# --- 🔥 GÜNCELLENEN KISIM: ZEMİN YÜKSEKLİĞİ 🔥 ---
func hucreyi_kilitle(hedef: Vector2i, tip: String = "TAS"):
	if grid_verisi.has(hedef) or kilitli_hucreler.has(hedef):
		if tip == "ASIT" and grid_verisi.has(hedef):
			var blok = grid_verisi[hedef]
			if patlama_efekti_sahnesi:
				var efekt = patlama_efekti_sahnesi.instantiate()
				add_child(efekt)
				efekt.global_position = blok.global_position
			grid_verisi.erase(hedef)
			blok.queue_free()
			print("🧪 Asit bloğu eritti!")
			if kamera_sarsinti_scripti: kamera_sarsinti_scripti.shake(0.3)
			return 
		return 

	# Engel Oluştur
	var engel = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	mat.roughness = 1.0
	
	if tip == "TAS":
		engel.mesh = BoxMesh.new()
		engel.mesh.size = Vector3(hucre_boyutu * 0.8, hucre_boyutu * 0.8, hucre_boyutu * 0.8)
		mat.albedo_color = Color(0.3, 0.3, 0.3) 
	elif tip == "ASIT":
		engel.mesh = SphereMesh.new()
		engel.mesh.radius = hucre_boyutu * 0.4
		engel.mesh.height = hucre_boyutu * 0.5
		mat.albedo_color = Color(0.1, 0.8, 0.1) 
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.8, 0.1)
	
	engel.material_override = mat
	add_child(engel)
	
	# POZİSYONLAMA
	engel.global_position = cell_center_world(hedef)
	
	# --- YÜKSEKLİK AYARI (MANUEL MÜDAHALE) ---
	# Grid'in hesapladığı yükseklik yerine, senin elle girdiğin ayarı kullanıyoruz.
	# Eğer Inspector'dan -1 yazarsan, taş -1'de doğar.
	engel.global_position.y = grid_verisi.get(hedef, global_position).y + engel_yuksekligi
	
	# Eğer global_position kullandıysak, GridYonetici'nin kendi yüksekliğini baz alalım:
	engel.global_position.y = global_position.y + engel_yuksekligi
	# ----------------------------------------
	
	kilitli_hucreler[hedef] = engel
	
	if kamera_sarsinti_scripti: kamera_sarsinti_scripti.shake(0.2)

func kilit_kir(hucre: Vector2i):
	if kilitli_hucreler.has(hucre):
		var engel = kilitli_hucreler[hucre]
		if patlama_efekti_sahnesi:
			var efekt = patlama_efekti_sahnesi.instantiate()
			add_child(efekt)
			efekt.global_position = engel.global_position
		engel.queue_free()
		kilitli_hucreler.erase(hucre)
		print("✅ Engel Kırıldı!")

# ... (Geri kalan patlatma ve puan hesaplama fonksiyonları aynı) ...
# ... (satirlari_kontrol_et, _bloklari_yok_et, _gelismis_puan_hesapla vb. dokunmana gerek yok) ...
# Aşağıdakiler çalışması için gereken temel fonksiyonlar (kod eksik kalmasın diye):
func satirlari_kontrol_et() -> void:
	var patlayacak_hucreler = []
	var patlayan_satir_sayisi = 0
	for y in range(grid_boyutu.y):
		var dolu_mu = true
		for x in range(grid_boyutu.x):
			if not grid_verisi.has(Vector2i(x, y)): dolu_mu = false; break
		if dolu_mu:
			patlayan_satir_sayisi += 1
			for x in range(grid_boyutu.x):
				var h = Vector2i(x, y); if not h in patlayacak_hucreler: patlayacak_hucreler.append(h)
			for x in range(grid_boyutu.x): _komsulari_kontrol_et_ve_kir(Vector2i(x, y))
	for x in range(grid_boyutu.x):
		var dolu_mu = true
		for y in range(grid_boyutu.y):
			if not grid_verisi.has(Vector2i(x, y)): dolu_mu = false; break
		if dolu_mu:
			patlayan_satir_sayisi += 1
			for y in range(grid_boyutu.y):
				var h = Vector2i(x, y); if not h in patlayacak_hucreler: patlayacak_hucreler.append(h)
			for y in range(grid_boyutu.y): _komsulari_kontrol_et_ve_kir(Vector2i(x, y))
	if patlayacak_hucreler.size() > 0:
		if kamera_sarsinti_scripti: kamera_sarsinti_scripti.shake(0.5)
		_bloklari_yok_et(patlayacak_hucreler)
		kombo_carpani += 1; kombo_suresi = max_kombo_suresi
		_gelismis_puan_hesapla(patlayan_satir_sayisi, patlayacak_hucreler)
		GameManager.satir_patladi.emit()

func _komsulari_kontrol_et_ve_kir(merkez: Vector2i):
	var yonler = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for yon in yonler:
		var hedef = merkez + yon
		if kilitli_hucreler.has(hedef): kilit_kir(hedef)

func _bloklari_yok_et(hucreler: Array) -> void:
	for h in hucreler:
		if grid_verisi.has(h):
			var blok = grid_verisi[h]
			if patlama_efekti_sahnesi and blok:
				var efekt = patlama_efekti_sahnesi.instantiate()
				add_child(efekt)
				efekt.global_position = blok.global_position
			grid_verisi.erase(h); if blok: blok.queue_free()

func _gelismis_puan_hesapla(satir, bloklar):
	var p = bloklar.size() * 10 * kombo_carpani
	emit_signal("puan_kazanildi", int(p))
	if arayuz: arayuz.puan_ekle(int(p), "KOMBO x" + str(kombo_carpani))

func mantar_modu_aktif(): GameManager.mantar_modu = true; get_tree().call_group("Blok", "rastgele_boya")
func hedef_goster(hucre: Vector2i, aktif: bool):
	if hedef_kare: hedef_kare.visible = aktif; if aktif: hedef_kare.global_position = cell_center_world(hucre)
func blok_kir(hucre: Vector2i, odul: bool = false): if grid_verisi.has(hucre): grid_verisi[hucre].queue_free(); grid_verisi.erase(hucre)
func sutunu_yok_et(hucre: Vector2i): pass 
func bloku_boya(hucre: Vector2i): pass
func miknatis_etkisi(): pass
