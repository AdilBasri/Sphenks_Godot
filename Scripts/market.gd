extends Node3D

# --- REFERANSLAR ---
@onready var oyuncu_kolu = $OyuncuEli
@onready var giris_sensoru = $GirisSensoru
@onready var altin_sahnesi = preload("res://Scenes/Items/altin.tscn")
@export var market_kapisi: Node3D
@export var market_ui: Control

# --- GÖRSEL EFEKTLER ---
@export var hedef_marketci: Node3D
@export var kese_sprite: Sprite3D

# --- KONUM AYARLARI ---
var kol_hedef_pos = Vector3(0.35, -0.8, -2.5)
var kol_baslangic_pos = Vector3(0.35, -3.0, -2.5)
var iceride_mi: bool = false

func _ready():
	# Başlangıç Ayarları
	if oyuncu_kolu:
		oyuncu_kolu.visible = false
	if market_ui:
		market_ui.visible = false

	# Sensör Bağlantıları
	if giris_sensoru:
		if not giris_sensoru.body_entered.is_connected(_on_giris_sensoru_body_entered):
			giris_sensoru.body_entered.connect(_on_giris_sensoru_body_entered)
		if not giris_sensoru.body_exited.is_connected(_on_giris_sensoru_body_exited):
			giris_sensoru.body_exited.connect(_on_giris_sensoru_body_exited)

func satin_almaya_calis(fiyat: int, urun_verisi: ItemData) -> bool:
	# 0. ÖNCE ENVANTERI KONTROL ET — para kesmeden
	if GameManager.envanter.size() >= GameManager.max_totem_sayisi:
		print("❌ Envanter Dolu! (" + str(GameManager.envanter.size()) + "/" + str(GameManager.max_totem_sayisi) + ") Alınamıyor.")
		_hata_sesi_cal()
		red_efekti_oynat()
		return false

	# Kanlı İndirim: %50 indirim uygula
	var gercek_fiyat = fiyat
	if GameManager and GameManager.get("kanli_indirim_aktif") and GameManager.kanli_indirim_aktif:
		gercek_fiyat = int(fiyat * 0.5)
		print("💩 Kanlı İndirim: Fiyat %50 düştü %d → %d" % [fiyat, gercek_fiyat])
	# 1. GameManager'a sor: "Yeterli para var mı?"
	if GameManager.altin_harca(gercek_fiyat):
		# 2. Para düştü, şimdi eşyayı envantere ekle
		GameManager.envanter.append(urun_verisi)
		GameManager.envanter_guncellendi.emit()
		print("✅ Satın alma başarılı: " + urun_verisi.esya_adi)
		return true
	else:
		print("❌ Yetersiz Bakiye! Gereken: " + str(gercek_fiyat))
		_hata_sesi_cal()
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz and arayuz.has_method("bilgi_goster"):
			arayuz.bilgi_goster(DilYoneticisi.metin_al("yetersiz_bakiye"))
		return false

func red_efekti_oynat():
	print("Envanter Dolu!")
	if market_ui and market_ui.has_method("hata_ver"):
		market_ui.hata_ver()

func _hata_sesi_cal():
	var sfx = AudioStreamPlayer.new()
	var stream = load("res://Assets/Audio/ErrorSound.mp3")
	if not stream:
		# Dosya ismi farklıysa dene
		stream = load("res://Assets/Audio/Error.mp3")
	if not stream:
		stream = load("res://Assets/Audio/error.mp3")
	if stream:
		sfx.stream = stream
		sfx.bus = "Master"
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
		print("🔊 Hata sesi çalındı.")
	else:
		print("⚠️ ErrorSound.mp3 bulunamadı!")

# --- SENSÖR VE ANİMASYONLAR ---
func _on_giris_sensoru_body_entered(body):
	if iceride_mi:
		return
	if body.is_in_group("Oyuncu") or body.name == "Oyuncu":
		iceride_mi = true
		if market_ui:
			market_ui.visible = true

		# ─ KANLI İNDİRİM: Girince 3 HP kaybet (bir kere) ─
		if GameManager and GameManager.get("kanli_indirim_aktif") and GameManager.kanli_indirim_aktif:
			if body.has_method("hasar_al"):
				body.hasar_al(3)
			var arayuz = get_tree().get_first_node_in_group("Arayuz")
			if arayuz and arayuz.has_method("bilgi_goster"):
				arayuz.bilgi_goster(DilYoneticisi.metin_al("kan_bedeli_odendi"), 4.0)
			print("💩 Kanlı İndirim: Oyuncu 3 HP kaybetti.")

		# --- MARKET TUTORIALINI BAŞLAT ---
		if TutorialManager:
			TutorialManager.start_tutorial_segment("market")

		# Kolu kaldır (Kamerayı bul)
		var kamera = body.find_child("Camera3D", true, false)
		if not kamera and body.has_node("Camera3D"):
			kamera = body.get_node("Camera3D")

		if kamera:
			call_deferred("kolu_kaldir", kamera)
		
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_giris_sensoru_body_exited(body):
	if body.is_in_group("Oyuncu") or body.name == "Oyuncu":
		iceride_mi = false
		if market_ui:
			market_ui.visible = false

func kolu_kaldir(kamera):
	if oyuncu_kolu.get_parent():
		oyuncu_kolu.get_parent().remove_child(oyuncu_kolu)
	kamera.add_child(oyuncu_kolu)

	oyuncu_kolu.transform = Transform3D.IDENTITY
	oyuncu_kolu.visible = true
	oyuncu_kolu.position = kol_baslangic_pos

	var tween = create_tween()
	tween.tween_property(oyuncu_kolu, "position", kol_hedef_pos, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if market_kapisi and market_kapisi.has_method("kilitle"):
		market_kapisi.kilitle() # İçeri girince kapıyı kilitle

func odeme_yap(adet):
	print(str(adet) + " Altın ödeniyor...")
	# Altın animasyonu için hedef belirleme
	var hedef_nokta_global = Vector3.ZERO
	if hedef_marketci:
		hedef_nokta_global = hedef_marketci.global_position
	elif oyuncu_kolu.get_parent():
		hedef_nokta_global = oyuncu_kolu.get_parent().to_global(Vector3(0, 0, -3.0))

	for i in range(adet):
		var yeni_altin = altin_sahnesi.instantiate()
		get_tree().current_scene.add_child(yeni_altin)

		if kese_sprite:
			yeni_altin.global_position = kese_sprite.global_position
		else:
			yeni_altin.global_position = oyuncu_kolu.global_position

		yeni_altin.scale = Vector3(0.5, 0.5, 0.5)

		var final_hedef = hedef_nokta_global + Vector3(randf_range(-0.1, 0.1), randf_range(0, 0.3), randf_range(-0.1, 0.1))
		var tween = create_tween()
		tween.tween_property(yeni_altin, "global_position", final_hedef, 0.5)
		tween.tween_callback(yeni_altin.queue_free)
		await get_tree().create_timer(0.1).timeout
