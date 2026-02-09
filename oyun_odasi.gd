extends Node3D

# --- BÖLÜM 1: LEVEL VE IŞINLANMA REFERANSLARI ---
@export_group("Level Sistemi")
@export var market_spawn: Marker3D
@export var campfire_spawn: Marker3D
@export var start_spawn: Marker3D

# --- BÖLÜM 2: BOSS VE ZAR SİSTEMİ REFERANSLARI ---
@export_group("Boss Zar Sistemi")
@export var zar_sahnesi: PackedScene
@export var zar_atik_noktasi: Node3D
@export var zar_kamerasi: Camera3D
@export var oyuncu_kamerasi: Camera3D
@export var oyuncu: CharacterBody3D 
@export var hasar_label: Label
@export var olum_ekrani_sahnesi: PackedScene

# --- DİĞER REFERANSLAR ---
@onready var yan_sehpa = get_node_or_null("YanSehpa") 

# --- DEĞİŞKENLER ---
var zar_firlatiliyor_mu : bool = false
var atilan_zarlar = []
var toplam_sonuc = 0
var duran_zar_sayisi = 0
var boss_uyandi_mi : bool = false 
var boss_tamamen_oldu : bool = false 

func _ready():
	# 1. LEVEL MANAGER KAYDI
	if LevelManager and oyuncu:
		var p1 = market_spawn.global_position if market_spawn else Vector3.ZERO
		var p2 = campfire_spawn.global_position if campfire_spawn else Vector3.ZERO
		var p3 = start_spawn.global_position if start_spawn else Vector3.ZERO
		
		LevelManager.konumlari_kaydet(p1, p2, p3, oyuncu, self)
	
	if yan_sehpa and yan_sehpa.has_method("sehpayi_guncelle"):
		yan_sehpa.sehpayi_guncelle()

	if zar_kamerasi: zar_kamerasi.current = false
	if oyuncu_kamerasi: oyuncu_kamerasi.current = true

	# --- 4. SİNYAL BAĞLANTILARI ---
	if GameManager:
		if not GameManager.blok_yerlestirildi.is_connected(_on_blok_yerlestirildi):
			GameManager.blok_yerlestirildi.connect(_on_blok_yerlestirildi)
		
		if not GameManager.boss_oldu.is_connected(_on_boss_oldu):
			GameManager.boss_oldu.connect(_on_boss_oldu)
			
		if not GameManager.satir_patladi.is_connected(_on_satir_patladi):
			GameManager.satir_patladi.connect(_on_satir_patladi)
	
	if oyuncu:
		if not oyuncu.oyuncu_oldu.is_connected(_on_oyuncu_oldu):
			oyuncu.oyuncu_oldu.connect(_on_oyuncu_oldu)

# --- TETİKLEYİCİLER ---

func _on_satir_patladi():
	if boss_tamamen_oldu: return

	if not boss_uyandi_mi:
		boss_uyandi_mi = true
		print("⚠️ İLK SATIR PATLADI! BOSS UYANDI! (Gelecek tur saldıracak)")
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz: arayuz.bilgi_goster("BOSS UYANDI!", 3.0)

func _on_blok_yerlestirildi():
	if boss_tamamen_oldu: return
	if not boss_uyandi_mi:
		print("💤 Boss uyuyor, saldırı yok.")
		return

	print("🧱 Blok yerleşti. Boss saldırısı bekleniyor...")
	
	await get_tree().create_timer(1.0).timeout
	
	if LevelManager and not boss_tamamen_oldu:
		LevelManager.boss_saldirisi_baslat()

func _on_boss_oldu():
	print("☠️ OYUN ODASI: Boss öldü sinyali alındı. Tehdit bitti.")
	boss_uyandi_mi = false
	boss_tamamen_oldu = true 

func _on_oyuncu_oldu():
	print("💀 Oyun Odası: Oyuncu öldü.")
	await get_tree().create_timer(2.0).timeout
	if olum_ekrani_sahnesi:
		var ekran = olum_ekrani_sahnesi.instantiate()
		add_child(ekran)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# --- LEVEL MANAGER FONKSİYONLARI ---

func zar_at():
	if zar_firlatiliyor_mu: return
	zar_firlatiliyor_mu = true # KİLİT BURADA AKTİF OLUYOR
	print("🎲 OYUN ODASI: Zar Atma Animasyonu Başlatıldı...")
	
	if zar_kamerasi and oyuncu_kamerasi:
		oyuncu_kamerasi.current = false 
		zar_kamerasi.current = true       
	
	toplam_sonuc = 0
	duran_zar_sayisi = 0
	
	for z in atilan_zarlar:
		if is_instance_valid(z): z.queue_free()
	atilan_zarlar.clear()
	
	_tek_zar_olustur()
	await get_tree().create_timer(0.2).timeout
	_tek_zar_olustur()

func _tek_zar_olustur():
	if not zar_sahnesi or not zar_atik_noktasi: return

	var yeni_zar = zar_sahnesi.instantiate()
	add_child(yeni_zar)
	
	yeni_zar.global_position = zar_atik_noktasi.global_position
	yeni_zar.global_position.x += randf_range(-0.5, 0.5)
	
	var firlatma_gucu = Vector3(0, -5, 0)
	var donme = Vector3(randf()*10, randf()*10, randf()*10)
	
	if yeni_zar.has_method("firlat"):
		yeni_zar.firlat(firlatma_gucu, donme)
		if not yeni_zar.zar_durdu.is_connected(_on_zar_durdu):
			yeni_zar.zar_durdu.connect(_on_zar_durdu)
		atilan_zarlar.append(yeni_zar)

func _on_zar_durdu(gelen_sayi):
	toplam_sonuc += gelen_sayi
	duran_zar_sayisi += 1
	
	if duran_zar_sayisi >= 2:
		print("✅ Zarlar Durdu. Toplam: ", toplam_sonuc)
		
		# --- BURASI DÜZELTİLDİ: KİLİDİ AÇIYORUZ ---
		zar_firlatiliyor_mu = false 
		# ------------------------------------------
		
		await get_tree().create_timer(1.5).timeout
		oyunu_devam_ettir()
		
		for zar in atilan_zarlar:
			if is_instance_valid(zar): zar.queue_free()
		atilan_zarlar.clear()
		
		if hasar_label:
			hasar_label.text = "HASAR: " + str(toplam_sonuc)
			hasar_label.visible = true
			var tween = create_tween()
			hasar_label.scale = Vector2(0, 0)
			tween.tween_property(hasar_label, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_ELASTIC)
		
		await get_tree().create_timer(0.5).timeout
		
		if LevelManager:
			LevelManager.oyuncuya_saldir(toplam_sonuc)
		elif oyuncu:
			oyuncu.hasar_al(toplam_sonuc)

		await get_tree().create_timer(2.0).timeout
		if hasar_label:
			hasar_label.visible = false
			
		if LevelManager and LevelManager.has_method("_on_boss_isi_bitti"):
			LevelManager._on_boss_isi_bitti()

func oyunu_devam_ettir():
	if oyuncu_kamerasi:
		zar_kamerasi.current = false
		oyuncu_kamerasi.current = true
