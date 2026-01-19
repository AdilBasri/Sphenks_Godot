extends Sprite3D

# --- AYARLAR ---
@export var süzülme_hizi : float = 2.0
@export var süzülme_mesafesi : float = 0.15 # Biraz daha belirgin olsun
@export var nefes_hizi : float = 1.5
@export var nefes_miktari : float = 0.05 

var baslangic_y : float
var zaman : float = 0.0

func _ready():
	baslangic_y = position.y
	# Rastgele başla ki doğal dursun
	zaman = randf() * 10.0 

func _process(delta):
	zaman += delta
	
	# 1. YUKARI AŞAĞI SÜZÜLME (Floating)
	var yeni_y = baslangic_y + (sin(zaman * süzülme_hizi) * süzülme_mesafesi)
	position.y = yeni_y
	
	# 2. NEFES ALMA (Şişip İnme)
	# Sadece Y ve X eksenini hafifçe oynatıyoruz
	var scale_degisimi = sin(zaman * nefes_hizi) * nefes_miktari
	# Eğer Boss'u elle büyütürsen (Scale 2 falan yaparsan) burası onu korur
	var ana_scale = 1.0 # Eğer Boss çok küçükse burayı 2.0 veya 3.0 yapabilirsin
	
	scale = Vector3(ana_scale + scale_degisimi, ana_scale - (scale_degisimi * 0.5), ana_scale)
