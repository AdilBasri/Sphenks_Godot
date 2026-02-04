extends Node3D

# --- MEVCUT REFERANSLAR ---
@onready var yan_sehpa = $YanSehpa 

# --- BOSS ZAR SİSTEMİ REFERANSLARI ---
@export_group("Boss Zar Sistemi")
@export var zar_sahnesi: PackedScene
@export var zar_atik_noktasi: Node3D
@export var zar_kamerasi: Camera3D
@export var oyuncu_kamerasi: Camera3D

# --- HASAR BAĞLANTILARI ---
@export_group("Hasar Bağlantıları")
@export var oyuncu: CharacterBody3D
@export var hasar_label: Label

# --- OYUN DEĞİŞKENLERİ ---
var atilan_zarlar = []
var toplam_sonuc = 0
var duran_zar_sayisi = 0

# --- MANTIK DEĞİŞKENLERİ ---
var boss_uyandi_mi : bool = false
var boss_oldu_mu : bool = false # YENİ: Boss'un ölme durumu

func _ready():
	# Envanter
	if yan_sehpa and GameManager:
		yan_sehpa.envanteri_yukle(GameManager.envanter)

	# Kamera
	if oyuncu_kamerasi and zar_kamerasi:
		zar_kamerasi.current = false
		oyuncu_kamerasi.current = true

	# --- SİNYALLERİ DİNLEME ---
	if GameManager:
		if not GameManager.satir_patladi.is_connected(_on_satir_patladi):
			GameManager.satir_patladi.connect(_on_satir_patladi)
		
		if not GameManager.blok_yerlestirildi.is_connected(_on_blok_yerlestirildi):
			GameManager.blok_yerlestirildi.connect(_on_blok_yerlestirildi)
			
		# YENİ: Boss öldü sinyali
		if not GameManager.boss_oldu.is_connected(_on_boss_oldu):
			GameManager.boss_oldu.connect(_on_boss_oldu)

# --- TETİKLEYİCİLER ---

func _on_boss_oldu():
	boss_oldu_mu = true
	print("☠️ BOSS ÖLDÜ! Artık zar atılmayacak.")

func _on_satir_patladi():
	if not boss_uyandi_mi and not boss_oldu_mu:
		boss_uyandi_mi = true
		print("⚠️ İLK SATIR PATLADI! BOSS UYANDI!")

func _on_blok_yerlestirildi():
	# KRİTİK ZAMANLAMA AYARI:
	# Blok konulduğunda önce skor hesaplanıp Boss ölebilir.
	# O yüzden 0.1 saniye bekleyip, Boss hala yaşıyor mu diye bakacağız.
	await get_tree().create_timer(0.1).timeout
	
	# Boss uyanıksa VE henüz ölmediyse saldır
	if boss_uyandi_mi and not boss_oldu_mu:
		boss_zar_at()

# --- BOSS ZAR FONKSİYONLARI ---

func boss_zar_at():
	# Çifte kontrol (Garanti olsun)
	if boss_oldu_mu: return
	
	print("🎲 SALDIRI BAŞLIYOR!")
	
	if zar_kamerasi and oyuncu_kamerasi:
		oyuncu_kamerasi.current = false 
		zar_kamerasi.current = true     
	
	toplam_sonuc = 0
	duran_zar_sayisi = 0
	atilan_zarlar.clear()
	
	zar_olustur()
	await get_tree().create_timer(0.2).timeout
	zar_olustur()

func zar_olustur():
	if not zar_sahnesi or not zar_atik_noktasi: return

	var yeni_zar = zar_sahnesi.instantiate()
	add_child(yeni_zar)
	
	yeni_zar.global_position = zar_atik_noktasi.global_position
	yeni_zar.global_position.x += randf_range(-0.5, 0.5)
	
	var firlatma_gucu = Vector3(0, -5, 0)
	var donme = Vector3(randf()*10, randf()*10, randf()*10)
	
	yeni_zar.firlat(firlatma_gucu, donme)
	yeni_zar.zar_durdu.connect(_on_zar_durdu)
	atilan_zarlar.append(yeni_zar)

func _on_zar_durdu(gelen_sayi):
	toplam_sonuc += gelen_sayi
	duran_zar_sayisi += 1
	
	if duran_zar_sayisi >= 2:
		await get_tree().create_timer(1.5).timeout
		
		# Boss ölse bile zarlar atıldıysa sonucunu gösterip öyle bitirelim
		# Ama kamera dönsün
		if oyuncu_kamerasi:
			zar_kamerasi.current = false
			oyuncu_kamerasi.current = true
		
		for zar in atilan_zarlar:
			if is_instance_valid(zar): zar.queue_free()
		atilan_zarlar.clear()
		
		# Boss bu arada öldüyse hasar vermeyelim (Opsiyonel, ama adil olan bu)
		if boss_oldu_mu:
			print("😌 Boss öldüğü için son hasar iptal edildi.")
			return

		if hasar_label:
			hasar_label.text = "GELEN ZAR: " + str(toplam_sonuc)
			hasar_label.visible = true
			var tween = create_tween()
			hasar_label.scale = Vector2(0, 0)
			tween.tween_property(hasar_label, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_ELASTIC)
		
		await get_tree().create_timer(0.5).timeout
		
		if oyuncu and oyuncu.has_method("hasar_al"):
			oyuncu.hasar_al(toplam_sonuc)

		await get_tree().create_timer(2.0).timeout
		if hasar_label:
			hasar_label.visible = false
