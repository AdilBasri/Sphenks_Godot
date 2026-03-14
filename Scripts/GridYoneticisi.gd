@tool
extends Node3D
class_name GridYonetici

# --- DIŞARIYA AÇIK AYARLAR ---
@export var patlama_efekti_sahnesi: PackedScene 
@export var kamera_sarsinti_scripti: Node3D 

@export_group("Game Feel Ses ve Efektler")
@export var koyma_sesi: AudioStream
@export var patlama_sesi: AudioStream
@export var toz_efekti_sahnesi: PackedScene

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
	
	if is_inside_tree():
		if kamera_sarsinti_scripti and kamera_sarsinti_scripti.has_method("shake"):
			kamera_sarsinti_scripti.shake(0.2)
		if toz_efekti_sahnesi and item:
			var toz = toz_efekti_sahnesi.instantiate()
			add_child(toz)
			toz.global_position = item.global_position

# --- 🔥 GÜNCELLENEN KISIM: ZEMİN YÜKSEKLİĞİ 🔥 ---
func hucreyi_kilitle(hedef: Vector2i, tip: String = "TAS"):
	# 1. Doluluk Kontrolü (Aynı kalıyor)
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

	# 2. Engel Nesnesini Oluştur
	var engel = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	mat.roughness = 1.0
	
	var yukseklik_ofseti = 0.0 
	
	if tip == "TAS":
		engel.mesh = BoxMesh.new()
		var s = hucre_boyutu * 0.8
		engel.mesh.size = Vector3(s, s, s)
		mat.albedo_color = Color(0.3, 0.3, 0.3)
		yukseklik_ofseti = s / 2.0
		
	elif tip == "ASIT":
		engel.mesh = SphereMesh.new()
		var r = hucre_boyutu * 0.4
		var h = hucre_boyutu * 0.5 
		engel.mesh.radius = r
		engel.mesh.height = h
		mat.albedo_color = Color(0.1, 0.8, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.8, 0.1)
		yukseklik_ofseti = h / 2.0
	
	engel.material_override = mat
	engel.add_to_group("Blok")
	
	# --- BURASI KRİTİK DEĞİŞİKLİK ---
	add_child(engel)
	
	# 1. Grid'in Scale/Rotation ayarlarından etkilenmemesi için bağımsız yapıyoruz:
	engel.set_as_top_level(true) 
	
	# 2. Boyutunun bozulmadığından emin oluyoruz:
	engel.scale = Vector3.ONE 
	
	# 3. Pozisyonlama
	var merkez = cell_center_world(hedef)
	
	# Inspector'dan "engel_yuksekligi" ayarını kontrol et! (0.0 olmalı)
	var final_y = global_position.y + yukseklik_ofseti + engel_yuksekligi
	
	engel.global_position = Vector3(merkez.x, final_y, merkez.z)
	
	# Debug Baskısı (Konsola bak: Taşın nerede oluştuğunu yazar)
	print("🪨 Engel oluştu! Konum: ", engel.global_position, " | Tip: ", tip)
	
	kilitli_hucreler[hedef] = engel
	
	if kamera_sarsinti_scripti: kamera_sarsinti_scripti.shake(0.2)

func kilit_kir(hucre: Vector2i):
	if kilitli_hucreler.has(hucre):
		var engel = kilitli_hucreler[hucre]
		if is_instance_valid(engel):
			engel.queue_free()
		kilitli_hucreler.erase(hucre)
		print("✅ Engel Kırıldı!")

func engelleri_temizle():
	for engel in kilitli_hucreler.values():
		if is_instance_valid(engel):
			engel.queue_free()
	kilitli_hucreler.clear()

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
			
	if GameManager and GameManager.get("kanli_civi_aktif"):
		var min_b = min(grid_boyutu.x, grid_boyutu.y)
		var d1_dolu = true
		for i in range(min_b):
			if not grid_verisi.has(Vector2i(i, i)): d1_dolu = false; break
		if d1_dolu:
			patlayan_satir_sayisi += 1
			for i in range(min_b):
				var h = Vector2i(i, i); if not h in patlayacak_hucreler: patlayacak_hucreler.append(h)
			for i in range(min_b): _komsulari_kontrol_et_ve_kir(Vector2i(i, i))
			
		var d2_dolu = true
		for i in range(min_b):
			if not grid_verisi.has(Vector2i(i, grid_boyutu.y - 1 - i)): d2_dolu = false; break
		if d2_dolu:
			patlayan_satir_sayisi += 1
			for i in range(min_b):
				var h = Vector2i(i, grid_boyutu.y - 1 - i); if not h in patlayacak_hucreler: patlayacak_hucreler.append(h)
			for i in range(min_b): _komsulari_kontrol_et_ve_kir(Vector2i(i, grid_boyutu.y - 1 - i))

	if patlayacak_hucreler.size() > 0:
		# Eski yavaşlatma ve kağıt patlama sesini kapatıyoruz (Kanlı vahşet eklendi)
		# Engine.time_scale = 0.05
		# get_tree().create_timer(0.1, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
		
		if kamera_sarsinti_scripti and kamera_sarsinti_scripti.has_method("shake"): kamera_sarsinti_scripti.shake(0.3)
			
		var mantar_ekstra = 0.0
		if GameManager and GameManager.mantar_modu:
			var renk_frekans = {}
			for h in patlayacak_hucreler:
				if grid_verisi.has(h):
					var b = grid_verisi[h]
					if b and b.has_meta("boyali_renk"):
						var c_str = str(b.get_meta("boyali_renk"))
						renk_frekans[c_str] = renk_frekans.get(c_str, 0) + 1
			var max_renk = 0
			for f in renk_frekans.values():
				if f > max_renk: max_renk = f
			if max_renk > 0:
				mantar_ekstra = 160.0 * pow(1.2, float(max_renk - 1))
				
		_bloklari_yok_et_kanli(patlayacak_hucreler)
		kombo_carpani += 1; kombo_suresi = max_kombo_suresi
		_gelismis_puan_hesapla(patlayan_satir_sayisi, patlayacak_hucreler, mantar_ekstra)
		
		# --- MERMİ PARÇASI DÜŞÜRME SİSTEMİ ---
		if not Engine.is_editor_hint():
			var gm = get_node_or_null("/root/GameManager")
			if gm:
				var toplam_patlayan_blok = patlayacak_hucreler.size()
				var parca_sansi_sayisi = int(toplam_patlayan_blok / 8)
				if parca_sansi_sayisi < 1: parca_sansi_sayisi = 1
				
				print("🔩 SATIR PATLADI! [%d blok] -> %d drop şansı deneniyor..." % [toplam_patlayan_blok, parca_sansi_sayisi])
				
				for i in range(parca_sansi_sayisi):
					var sans = randi() % 100
					if sans < 20: # %20 ihtimal
						print("🔩 Şans TUTTU! (%d < 20) -> Mermi parçası eklendi." % sans)
						if gm.has_method("mermi_parcasi_ekle"):
							gm.mermi_parcasi_ekle(1)
					else:
						print("🔩 Şans tutmadı (%d >= 20)." % sans)
			else:
				print("⚠️ UYARI: GameManager bulunamadı (Drop yapılamadı)")
		
		if GameManager:
			GameManager.satir_patladi.emit()

func _komsulari_kontrol_et_ve_kir(merkez: Vector2i):
	var yonler = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for yon in yonler:
		var hedef = merkez + yon
		if kilitli_hucreler.has(hedef): kilit_kir(hedef)

func _bloklari_yok_et_kanli(hucreler: Array) -> void:
	var blok_nodelari = []
	for h in hucreler:
		if grid_verisi.has(h):
			var blok = grid_verisi[h]
			blok_nodelari.append(blok)
			# Grid'den hemen sil ki yenileri üstüne düşebilsin veya etkileşim kopsun
			grid_verisi.erase(h)
			
	if blok_nodelari.size() == 0: return
	
	# 1. Kan Yüklenme Sesi (load)
	var sfx_load = AudioStreamPlayer3D.new()
	sfx_load.stream = load("res://Assets/Audio/blood_load.mp3")
	sfx_load.max_distance = 25.0
	sfx_load.pitch_scale = randf_range(0.9, 1.1)
	add_child(sfx_load)
	sfx_load.global_position = blok_nodelari[0].global_position
	sfx_load.play()
	sfx_load.finished.connect(sfx_load.queue_free)
	
	# 2. Şişme ve Deformasyon Animasyonu (1.5 Saniye)
	var tween = create_tween()
	tween.set_parallel(true)
	for blok in blok_nodelari:
		if is_instance_valid(blok):
			var current_scale = blok.scale
			var target_scale = current_scale * 1.6 # %60 şişir
			target_scale.y *= 1.2 # Yukarı daha çok şişsin (karelikten çıksın)
			
			tween.tween_property(blok, "scale", target_scale, 0.8).set_trans(Tween.TRANS_SINE)
			
			var rand_rot = Vector3(
				randf_range(-0.5, 0.5),
				randf_range(-0.5, 0.5),
				randf_range(-0.5, 0.5)
			)
			tween.tween_property(blok, "rotation", blok.rotation + rand_rot, 0.8).set_trans(Tween.TRANS_BOUNCE)
			
	# Kanın dolmasını bekle
	await get_tree().create_timer(0.85).timeout
	
	# 3. PATLAMA VE KAN SAÇILMA
	var sfx_splash = AudioStreamPlayer3D.new()
	sfx_splash.stream = load("res://Assets/Audio/blood_splash.mp3")
	sfx_splash.max_distance = 30.0
	sfx_splash.pitch_scale = randf_range(0.85, 1.1)
	add_child(sfx_splash)
	if blok_nodelari.size() > 0 and is_instance_valid(blok_nodelari[0]):
		sfx_splash.global_position = blok_nodelari[0].global_position
	sfx_splash.play()
	sfx_splash.finished.connect(sfx_splash.queue_free)
	
	if kamera_sarsinti_scripti and kamera_sarsinti_scripti.has_method("shake"):
		kamera_sarsinti_scripti.shake(0.8)
		
	for blok in blok_nodelari:
		if is_instance_valid(blok):
			_kan_partikulleri_yarat(blok.global_position)
			blok.queue_free()

func _kan_partikulleri_yarat(pos: Vector3):
	var cpu_particles = CPUParticles3D.new()
	cpu_particles.amount = 40
	cpu_particles.one_shot = true
	cpu_particles.lifetime = 1.0
	cpu_particles.explosiveness = 0.95
	cpu_particles.randomness = 0.5
	
	# Havaya ve etrafa sıçrama
	cpu_particles.direction = Vector3(0, 1, 0)
	cpu_particles.spread = 60.0
	cpu_particles.initial_velocity_min = 4.0
	cpu_particles.initial_velocity_max = 8.0
	
	cpu_particles.gravity = Vector3(0, -15.0, 0)
	cpu_particles.damping_min = 2.0
	cpu_particles.damping_max = 4.0
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.4, 0.4)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.0, 0.0)
	mat.roughness = 0.1
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	var tex = load("res://Assets/Images/KAN.png") # Kandamlası texture'u varsa kullan
	if tex:
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, mat)
	
	cpu_particles.mesh = mesh
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(0.8, 0.8))
	curve.add_point(Vector2(1, 0.0))
	cpu_particles.scale_amount_curve = curve
	
	add_child(cpu_particles)
	cpu_particles.global_position = pos
	cpu_particles.emitting = true
	
	get_tree().create_timer(1.2).timeout.connect(cpu_particles.queue_free)


func _gelismis_puan_hesapla(satir, bloklar, mantar_ekstra = 0.0):
	# 1. Kombo Çarpanı
	var final_carpan = float(kombo_carpani)
	
	# 2. GÜÇ İKSİRİ ETKİSİ (YENİ)
	# Eğer GameManager'da çarpan 1'den büyükse (iksir içildiyse) çarpıyoruz.
	if GameManager and GameManager.puan_carpani > 1.0:
		final_carpan *= GameManager.puan_carpani
		print("💪 Güç İksiri Devrede! Çarpan: ", final_carpan)
	
	# 3. Puan Hesabı
	var p = bloklar.size() * 10 * final_carpan
	p += mantar_ekstra
	
	# Sinyal Gönder
	emit_signal("puan_kazanildi", int(p))
	
	# --- YENİ GOLD KAZANMA SİSTEMİ ---
	var kazanilan_altin = 0
	if satir == 1: kazanilan_altin = 3
	elif satir == 2: kazanilan_altin = 7
	elif satir >= 3: kazanilan_altin = 12
	
	if kazanilan_altin > 0 and GameManager:
		GameManager.toplam_altin += kazanilan_altin
		GameManager.emit_signal("altin_guncellendi", GameManager.toplam_altin)
	
	# Arayüzde Gösterim
	var mesaj = DilYoneticisi.metin_al("kombo") % kombo_carpani
	if kazanilan_altin > 0:
		mesaj += DilYoneticisi.metin_al("altin_kazandin_mesaj") % kazanilan_altin
		
	if GameManager.puan_carpani > 1.0:
		mesaj += DilYoneticisi.metin_al("guc_iksiri_duv") # Oyuncu iksirin çalıştığını görsün
	if mantar_ekstra > 0.0:
		mesaj += DilYoneticisi.metin_al("renk_bonusu")
		
	if arayuz: arayuz.puan_ekle(int(p), mesaj)

func mantar_modu_aktif(): GameManager.mantar_modu = true; get_tree().call_group("Blok", "rastgele_boya")
func hedef_goster(hucre: Vector2i, aktif: bool):
	if hedef_kare: hedef_kare.visible = aktif; if aktif: hedef_kare.global_position = cell_center_world(hucre)
func blok_kir(hucre: Vector2i, odul: bool = false): if grid_verisi.has(hucre): grid_verisi[hucre].queue_free(); grid_verisi.erase(hucre)
func sutunu_yok_et(hucre: Vector2i): pass 
func bloku_boya(hucre: Vector2i): pass
func miknatis_etkisi():
	print("🧲 Mıknatıs Çalıştı: Bloklar aşağı çekiliyor...")
	
	# YÖN: (0, 1) yani Z ekseninde pozitif (Bize doğru/Aşağı)
	var yon = Vector2i(0, 1)
	var hareket_var_mi = false
	
	# SIRALAMA ÖNEMLİ:
	# Aşağı çekeceğimiz için, en aşağıdan (y=7) en yukarıya (y=0) doğru taramalıyız.
	# Böylece alttakiler önce kaçar, üsttekilere yer açılır.
	
	# Griddeki dolu hücreleri al
	var dolu_hucreler = grid_verisi.keys()
	
	# Bunları Y koordinatına göre BÜYÜKTEN KÜÇÜĞE (7 -> 0) sırala
	dolu_hucreler.sort_custom(func(a, b): return a.y > b.y)
	
	for hucre in dolu_hucreler:
		var suanki_konum = hucre
		var blok_node = grid_verisi[hucre]
		
		# Bloğu gidebildiği kadar aşağı itelim
		var hedef_konum = suanki_konum
		
		while true:
			var sonraki_adim = hedef_konum + yon
			
			# 1. Grid dışına çıktı mı?
			if sonraki_adim.x < 0 or sonraki_adim.x >= grid_boyutu.x or sonraki_adim.y < 0 or sonraki_adim.y >= grid_boyutu.y:
				break
			
			# 2. Orada başka bir blok var mı? (Kendi eski yeri hariç)
			# Not: grid_verisi'ni anlık güncellemediğimiz için "hedef_konum" kontrolü yapıyoruz
			if grid_verisi.has(sonraki_adim) and sonraki_adim != suanki_konum:
				break
				
			# 3. Orada TAŞ (Engel) var mı?
			if kilitli_hucreler.has(sonraki_adim):
				break
			
			# Yol temiz, bir adım daha ilerle
			hedef_konum = sonraki_adim
		
		# Eğer blok yer değiştirdiyse
		if hedef_konum != suanki_konum:
			# 1. Sözlüğü Güncelle (Eskiyi sil, yeniyi ekle)
			grid_verisi.erase(suanki_konum)
			grid_verisi[hedef_konum] = blok_node
			
			# 2. Görsel Animasyon
			_blok_kaydir_animasyonu(blok_node, hedef_konum)
			
			hareket_var_mi = true
	
	# Hepsi bittikten sonra patlama kontrolü yap
	if hareket_var_mi:
		if kamera_sarsinti_scripti: kamera_sarsinti_scripti.shake(0.1) # Hafif sarsıntı
		
		# Animasyonların bitmesi için biraz bekle, sonra patlat
		await get_tree().create_timer(0.35).timeout
		satirlari_kontrol_et()
	else:
		print("🧲 Mıknatıs çekti ama hiçbir blok kıpırdayamadı.")

func _blok_kaydir_animasyonu(blok: Node3D, hedef_hucre: Vector2i):
	var hedef_pos = cell_center_world(hedef_hucre)
	# Yüksekliği koru (Blok havadaysa inmesin, olduğu yerde kaysın diye)
	# Ama grid sisteminde genelde y=0'dır. İstersen blok.position.y kullanabilirsin.
	
	var tween = create_tween()
	tween.tween_property(blok, "global_position:x", hedef_pos.x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(blok, "global_position:z", hedef_pos.z, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
