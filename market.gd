extends Node3D

# --- REFERANSLAR ---
# El görselini (TextureRect) buraya bağlayacağız
@onready var el_arayuzu = $CanvasLayer/TextureRect

# Arkadaki kapıyı kapatmak için ona ihtiyacımız var.
# "KapiMarket"in yolunu sahne ağacından bakarak buraya sürükleyebilirsin veya export ile seçebilirsin.
# Şimdilik export ile yapalım, editörden atarsın.
@export var market_kapisi: Node3D 

var iceride_mi: bool = false

func _ready():
	# Başlangıçta el gizli (Sen zaten gizlemişsin ama garanti olsun)
	if el_arayuzu:
		el_arayuzu.visible = false
	
	# Giriş sensörünü dinle
	var sensor = $GirisSensoru
	if sensor:
		# Oyuncu (body) girdiğinde tetiklensin
		sensor.body_entered.connect(_oyuncu_girdi)

func _oyuncu_girdi(body):
	# Giren şey "Oyuncu" mu? (Adı "Oyuncu" veya CharacterBody3D ise)
	if body.name == "Oyuncu" or body is CharacterBody3D:
		if iceride_mi: return # Zaten içerideysek tekrar çalıştırma
		
		print("Market Odasına Girildi!")
		iceride_mi = true
		
		# 1. ELİ GÖSTER
		if el_arayuzu:
			el_arayuzu.visible = true
			
			# İstersen el aşağıdan yukarı kayarak çıksın (Tween)
			# (Önce konumunu aşağı al, sonra yukarı kaydır)
			# el_arayuzu.position.y += 200
			# var tween = create_tween()
			# tween.tween_property(el_arayuzu, "position:y", el_arayuzu.position.y - 200, 0.5)

		# 2. KAPIYI KAPAT
		if market_kapisi:
			# Kapı scriptine "kapiyi_kapat" fonksiyonu eklememiz gerekebilir
			# Şimdilik basitçe animasyonu ters oynatalım veya kilitleyelim
			if market_kapisi.has_method("kapiyi_kapat"):
				market_kapisi.kapiyi_kapat()
			else:
				# Eğer fonksiyon yoksa manuel kapatma (Geçici)
				print("Kapı kapanıyor...")
				var tween = create_tween()
				tween.tween_property(market_kapisi, "rotation_degrees:y", 0.0, 1.0) # 0 derece = Kapalı
