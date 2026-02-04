extends Node3D

# --- MEVCUT REFERANSLAR ---
@onready var yan_sehpa = $YanSehpa 

# --- BOSS ZAR SİSTEMİ REFERANSLARI ---
@export_group("Boss Zar Sistemi")
@export var zar_sahnesi: PackedScene  # Zar.tscn
@export var zar_atik_noktasi: Node3D  # Marker3D
@export var zar_kamerasi: Camera3D    # Tepe Kamerası
@export var oyuncu_kamerasi: Camera3D # Oyuncu Kamerası

# --- YENİ EKLENENLER (Hasar İçin) ---
@export_group("Hasar Bağlantıları")
@export var oyuncu: CharacterBody3D   # Oyuncu.gd'ye erişmek için (Hasar vermek için)
@export var hasar_label: Label        # UI'daki "HasarYazisi" (Sonucu göstermek için)

# --- OYUN DEĞİŞKENLERİ ---
var atilan_zarlar = []
var toplam_sonuc = 0
var duran_zar_sayisi = 0

func _ready():
	# Envanter Sistemi
	if yan_sehpa and GameManager:
		yan_sehpa.envanteri_yukle(GameManager.envanter)

	# Kamera Başlangıç Ayarı
	if oyuncu_kamerasi and zar_kamerasi:
		zar_kamerasi.current = false
		oyuncu_kamerasi.current = true

func _input(event):
	# TEST TUŞU: X
	if event is InputEventKey and event.pressed and event.keycode == KEY_X:
		boss_zar_at()

# --- BOSS FONKSİYONLARI ---

func boss_zar_at():
	print("🎲 BOSS ZAR ATIYOR! Sinematik mod...")
	
	# 1. Kamerayı Değiştir
	if zar_kamerasi and oyuncu_kamerasi:
		oyuncu_kamerasi.current = false 
		zar_kamerasi.current = true     
	
	# 2. Değişkenleri Sıfırla
	toplam_sonuc = 0
	duran_zar_sayisi = 0
	atilan_zarlar.clear()
	
	# 3. Zarları Oluştur
	zar_olustur()
	await get_tree().create_timer(0.2).timeout
	zar_olustur()

func zar_olustur():
	if not zar_sahnesi or not zar_atik_noktasi:
		print("HATA: Zar Sahnesi veya Atış Noktası eksik!")
		return

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
	
	print("Bir zar durdu: ", gelen_sayi)
	
	# Eğer 2 zar da durduysa?
	if duran_zar_sayisi >= 2:
		print("✅ TÜM ZARLAR DURDU! Toplam: ", toplam_sonuc)
		
		# 1. Biraz bekle (Oyuncu zarları görsün)
		await get_tree().create_timer(1.5).timeout
		
		# 2. Kamerayı Oyuncuya Geri Ver
		if oyuncu_kamerasi:
			print("🎥 Kamera Oyuncuya dönüyor...")
			zar_kamerasi.current = false
			oyuncu_kamerasi.current = true
		
		# 3. Zarları temizle
		for zar in atilan_zarlar:
			if is_instance_valid(zar): zar.queue_free()
		atilan_zarlar.clear()
		
		# --- KRİTİK NOKTA: HASAR VE YAZI ---
		
		# A) Yazıyı Göster
		if hasar_label:
			hasar_label.text = "GELEN ZAR: " + str(toplam_sonuc)
			hasar_label.visible = true
			
			# Basit bir animasyon efekti (Büyüyüp küçülme)
			var tween = create_tween()
			hasar_label.scale = Vector2(0, 0) # Sıfırdan başla
			tween.tween_property(hasar_label, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_ELASTIC)
		
		# B) Oyuncuya Hasarı Ver
		# Oyuncu kendini gördükten azıcık sonra hasar yesin (Daha dramatik olur)
		await get_tree().create_timer(0.5).timeout
		
		if oyuncu and oyuncu.has_method("hasar_al"):
			print("💥 Oyuncuya " + str(toplam_sonuc) + " hasar veriliyor!")
			oyuncu.hasar_al(toplam_sonuc)
		else:
			print("HATA: Oyuncu düğümü atanmamış veya 'hasar_al' fonksiyonu yok!")

		# C) Yazıyı Gizle (2 saniye sonra)
		await get_tree().create_timer(2.0).timeout
		if hasar_label:
			hasar_label.visible = false
