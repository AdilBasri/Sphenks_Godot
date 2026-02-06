extends Node3D

# --- BÖLÜM 1: LEVEL VE IŞINLANMA REFERANSLARI (YENİ) ---
@export_group("Level Sistemi")
@export var market_spawn: Marker3D
@export var campfire_spawn: Marker3D
@export var start_spawn: Marker3D

# --- BÖLÜM 2: BOSS VE ZAR SİSTEMİ REFERANSLARI (ESKİ - GERİ GELDİ) ---
@export_group("Boss Zar Sistemi")
@export var zar_sahnesi: PackedScene
@export var zar_atik_noktasi: Node3D
@export var zar_kamerasi: Camera3D
@export var oyuncu_kamerasi: Camera3D
@export var oyuncu: CharacterBody3D # Hem spawn hem hasar için lazım
@export var hasar_label: Label
@export var olum_ekrani_sahnesi: PackedScene

# --- DİĞER REFERANSLAR ---
@onready var yan_sehpa = $YanSehpa 

# --- DEĞİŞKENLER ---
var atilan_zarlar = []
var toplam_sonuc = 0
var duran_zar_sayisi = 0
var boss_uyandi_mi : bool = false
var boss_oldu_mu : bool = false 

func _ready():
	# --- 1. LEVEL MANAGER KAYDI (Işınlanma Sistemi) ---
	if LevelManager and oyuncu:
		var p1 = market_spawn.global_position if market_spawn else Vector3.ZERO
		var p2 = campfire_spawn.global_position if campfire_spawn else Vector3.ZERO
		var p3 = start_spawn.global_position if start_spawn else Vector3.ZERO
		
		LevelManager.konumlari_kaydet(p1, p2, p3, oyuncu)
	
	# --- 2. SEHPA GÜNCELLEME ---
	if yan_sehpa and yan_sehpa.has_method("sehpayi_guncelle"):
		yan_sehpa.sehpayi_guncelle()

	# --- 3. KAMERA BAŞLANGIÇ AYARI ---
	if zar_kamerasi: zar_kamerasi.current = false
	if oyuncu_kamerasi: oyuncu_kamerasi.current = true

	# --- 4. SİNYALLERİ DİNLEME (Boss Mekanikleri İçin) ---
	if GameManager:
		if not GameManager.satir_patladi.is_connected(_on_satir_patladi):
			GameManager.satir_patladi.connect(_on_satir_patladi)
		
		if not GameManager.blok_yerlestirildi.is_connected(_on_blok_yerlestirildi):
			GameManager.blok_yerlestirildi.connect(_on_blok_yerlestirildi)
			
		if not GameManager.boss_oldu.is_connected(_on_boss_oldu):
			GameManager.boss_oldu.connect(_on_boss_oldu)
	
	if oyuncu:
		if not oyuncu.oyuncu_oldu.is_connected(_on_oyuncu_oldu):
			oyuncu.oyuncu_oldu.connect(_on_oyuncu_oldu)

# --- TETİKLEYİCİLER (Boss Mantığı) ---

func _on_boss_oldu():
	boss_oldu_mu = true
	print("☠️ BOSS ÖLDÜ! Artık zar atılmayacak.")

func _on_satir_patladi():
	if not boss_uyandi_mi and not boss_oldu_mu:
		boss_uyandi_mi = true
		print("⚠️ İLK SATIR PATLADI! BOSS UYANDI!")

func _on_blok_yerlestirildi():
	# Blok konulduktan biraz sonra Boss hamle yapsın
	await get_tree().create_timer(0.5).timeout
	if boss_uyandi_mi and not boss_oldu_mu:
		boss_zar_at()

func _on_oyuncu_oldu():
	print("💀 Oyun Odası: Oyuncu öldü.")
	await get_tree().create_timer(2.0).timeout
	if olum_ekrani_sahnesi:
		var ekran = olum_ekrani_sahnesi.instantiate()
		add_child(ekran)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# --- BOSS ZAR FONKSİYONLARI (GERİ GELDİ) ---

func boss_zar_at():
	if boss_oldu_mu: return
	
	print("🎲 BOSS SALDIRIYOR! Kamera geçişi...")
	
	# Kamerayı Zar Kamerasına geçir
	if zar_kamerasi and oyuncu_kamerasi:
		oyuncu_kamerasi.current = false 
		zar_kamerasi.current = true      
	
	toplam_sonuc = 0
	duran_zar_sayisi = 0
	
	# Eski zarları temizle (Güvenlik)
	for z in atilan_zarlar:
		if is_instance_valid(z): z.queue_free()
	atilan_zarlar.clear()
	
	# Zarları fırlat
	zar_olustur()
	await get_tree().create_timer(0.2).timeout
	zar_olustur()

func zar_olustur():
	if not zar_sahnesi or not zar_atik_noktasi: 
		print("HATA: Zar sahnesi veya atık noktası eksik!")
		return

	var yeni_zar = zar_sahnesi.instantiate()
	add_child(yeni_zar)
	
	yeni_zar.global_position = zar_atik_noktasi.global_position
	# Hafif rastgelelik
	yeni_zar.global_position.x += randf_range(-0.5, 0.5)
	
	var firlatma_gucu = Vector3(0, -5, 0) # Aşağı doğru
	var donme = Vector3(randf()*10, randf()*10, randf()*10)
	
	if yeni_zar.has_method("firlat"):
		yeni_zar.firlat(firlatma_gucu, donme)
		yeni_zar.zar_durdu.connect(_on_zar_durdu)
		atilan_zarlar.append(yeni_zar)

func _on_zar_durdu(gelen_sayi):
	toplam_sonuc += gelen_sayi
	duran_zar_sayisi += 1
	
	# 2 Zar da durduysa
	if duran_zar_sayisi >= 2:
		print("Zarlar Durdu. Toplam Hasar: ", toplam_sonuc)
		
		# 1.5 saniye bekle ki sonucu görelim
		await get_tree().create_timer(1.5).timeout
		
		# Kamerayı Oyuncuya Geri Ver
		if oyuncu_kamerasi:
			zar_kamerasi.current = false
			oyuncu_kamerasi.current = true
		
		# Zarları temizle
		for zar in atilan_zarlar:
			if is_instance_valid(zar): zar.queue_free()
		atilan_zarlar.clear()
		
		if boss_oldu_mu: return

		# Hasar UI Gösterimi
		if hasar_label:
			hasar_label.text = "HASAR: " + str(toplam_sonuc)
			hasar_label.visible = true
			var tween = create_tween()
			hasar_label.scale = Vector2(0, 0)
			tween.tween_property(hasar_label, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_ELASTIC)
		
		await get_tree().create_timer(0.5).timeout
		
		# Oyuncuya hasar ver
		if oyuncu and oyuncu.has_method("hasar_al"):
			oyuncu.hasar_al(toplam_sonuc)

		# UI'ı gizle
		await get_tree().create_timer(2.0).timeout
		if hasar_label:
			hasar_label.visible = false
