extends Control

# --- REFERANSLAR ---
@onready var sayac_label = $SayacLabel
@onready var ses_player = $SesPlayer

# --- AYARLAR ---
var normal_renk = Color.WHITE
var hata_rengi = Color(1, 0.2, 0.2) # Parlak Kırmızı
var orijinal_scale = Vector2(1, 1)

func _ready():
	# Yazının tam ortasından büyümesi için pivot noktasını merkeze alıyoruz
	sayac_label.pivot_offset = sayac_label.size / 2
	
	# Başlangıçta güncelle
	guncelle(GameManager.envanter.size(), GameManager.max_totem_sayisi)

# SAYACI GÜNCELLEME VE "POP" ANİMASYONU
func guncelle(mevcut: int, maksimum: int):
	# 1. Metni değiştir
	sayac_label.text = "Totem: " + str(mevcut) + "/" + str(maksimum)
	
	# 2. Pivotu tekrar ayarla (Metin boyutu değişince kaymasın diye)
	await get_tree().process_frame # Bir kare bekle ki text güncellensin
	sayac_label.pivot_offset = sayac_label.size / 2
	
	# 3. POP Efekti (Tween) - Büyüyüp Küçülme
	var tween = create_tween()
	tween.tween_property(sayac_label, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sayac_label, "scale", orijinal_scale, 0.1)

# HATA EFEKTİ (TİTREME + KIRMIZI + SES)
func hata_ver():
	# Sesi Çal
	if ses_player.stream:
		ses_player.play()
	
	var tween = create_tween()
	
	# 1. Rengi Kırmızı Yap
	tween.tween_property(sayac_label, "modulate", hata_rengi, 0.1)
	
	# 2. Titreme (Shake) Efekti - Sağa Sola Hızlıca Git Gel
	var orijinal_pos = sayac_label.position
	for i in range(4): # 4 kere titret
		var sapma = 5.0 # 5 piksel sağa sola
		tween.tween_property(sayac_label, "position:x", orijinal_pos.x + sapma, 0.05)
		tween.tween_property(sayac_label, "position:x", orijinal_pos.x - sapma, 0.05)
	
	# 3. Sonunda Rengi ve Konumu Düzelt
	tween.tween_property(sayac_label, "position", orijinal_pos, 0.05)
	tween.tween_property(sayac_label, "modulate", normal_renk, 0.2)
