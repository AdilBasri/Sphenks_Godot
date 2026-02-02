extends Node3D

# Kapıları sahnede bulup değişkenlere atıyoruz
# İsimleri "Adım 1"de düzelttiğin gibi olmalı!
@onready var kapi_market = $KapiMarket
@onready var kapi_campfire = $KapiCampfire

func _ready():
	# Sinyalleri dinlemeye başla
	# Market kapısı "kapi_acildi" sinyali verirse, "_market_secildi" fonksiyonunu çalıştır
	kapi_market.kapi_acildi.connect(_market_secildi)
	
	# Campfire kapısı "kapi_acildi" sinyali verirse, "_campfire_secildi" fonksiyonunu çalıştır
	kapi_campfire.kapi_acildi.connect(_campfire_secildi)

func _market_secildi():
	print("Oyuncu Marketi Seçti! Campfire kilitleniyor...")
	# Diğer kapıyı kilitle
	kapi_campfire.kilitle()

func _campfire_secildi():
	print("Oyuncu Ateşi Seçti! Market kilitleniyor...")
	# Diğer kapıyı kilitle
	kapi_market.kilitle()
