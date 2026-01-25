extends Node3D

# --- GÖRSEL AYARLAR (Eski Kodundan Korunanlar) ---
@export_group("Görsel Efektler")
@export var suzulme_hizi : float = 2.0
@export var suzulme_mesafesi : float = 0.15
@export var nefes_hizi : float = 1.5
@export var nefes_miktari : float = 0.05 
@export var ana_scale : float = 1.0 # Boss'un normal boyutu (2.0 veya 3.0 yapabilirsin)

# --- YAPAY ZEKA AYARLARI (Yeni Eklenenler) ---
@export_group("Utangaç Yapay Zeka")
@export var oyuncu: Node3D        # Inspector'dan Oyuncu'yu ata
@export var masa_merkezi: Node3D  # Inspector'dan GridYoneticisi'ni ata
@export var kacma_mesafesi: float = 2.5 # Masadan ne kadar uzakta dursun?
@export var kacma_hizi: float = 2.0     # Ne kadar seri hareket etsin?

var baslangic_y : float
var zaman : float = 0.0

func _ready():
	# Boss'u sahneye koyduğun Y yüksekliğini referans alalım
	baslangic_y = global_position.y
	
	# Her boss farklı zamanda başlasın ki robot gibi durmasın
	zaman = randf() * 10.0 

func _process(delta):
	zaman += delta
	
	# --- 1. UTANGAÇ HAREKET MANTIĞI (X ve Z Ekseni) ---
	if oyuncu and masa_merkezi:
		# Masanın ve oyuncunun konumlarını al (Yükseklikleri sıfırla ki matematik şaşmasın)
		var merkez_pos = masa_merkezi.global_position
		var oyuncu_pos = oyuncu.global_position
		merkez_pos.y = 0
		oyuncu_pos.y = 0
		
		# Oyuncu masanın neresinde duruyor? (Yön vektörü)
		var oyuncu_yonu = (oyuncu_pos - merkez_pos).normalized()
		
		# Biz tam tersine gideceğiz!
		var kacis_yonu = -oyuncu_yonu
		
		# Hedefimiz: Masanın merkezinden 'kacma_mesafesi' kadar uzaktaki nokta
		var hedef_nokta = masa_merkezi.global_position + (kacis_yonu * kacma_mesafesi)
		
		# Sadece yatayda hareket et (Yüksekliği görsel efekte bırakacağız)
		var anlik_x = lerp(global_position.x, hedef_nokta.x, kacma_hizi * delta)
		var anlik_z = lerp(global_position.z, hedef_nokta.z, kacma_hizi * delta)
		
		global_position.x = anlik_x
		global_position.z = anlik_z
		
		# Her zaman masaya dönük olsun (İsteğe bağlı, silinebilir)
		look_at(masa_merkezi.global_position, Vector3.UP)
		# Eğer sprite ters dönerse rotation.y += 180 ekleyebilirsin veya scale.x'i -1 yapabilirsin.

	# --- 2. GÖRSEL EFEKTLER (Y Ekseni ve Scale) ---
	
	# YUKARI AŞAĞI SÜZÜLME
	# Yapay zeka X ve Z'yi değiştirdi, Y'yi ise burası dalgalandırıyor.
	var yeni_y = baslangic_y + (sin(zaman * suzulme_hizi) * suzulme_mesafesi)
	global_position.y = lerp(global_position.y, yeni_y, 5.0 * delta)
	
	# NEFES ALMA (Şişip İnme)
	var scale_degisimi = sin(zaman * nefes_hizi) * nefes_miktari
	
	# Vector3 kullanarak X, Y, Z boyutlarını orantılı değiştiriyoruz
	# Eski kodundaki mantığı korudum: Y biraz daha az esniyor (0.5 çarpanı)
	scale = Vector3(
		ana_scale + scale_degisimi, 
		ana_scale - (scale_degisimi * 0.2), 
		ana_scale
	)
