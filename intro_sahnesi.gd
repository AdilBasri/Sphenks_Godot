extends Node3D

# --- AYARLAR ---
@onready var kamera = $Oyuncu/Camera3D # Oyuncu kamerana giden yol (Doğru olduğundan emin ol)
@onready var altyazi_label = $UI/Label

var etkilesim_aktif = true # Oyuncu şu an tıklayabilir mi?
var varsayilan_fov = 90.0

# SENİN HİKAYE METİNLERİN (Sırayla veya Rastgele gösterilecek)
var diyaloglar = [
	"Bu biçimsiz insan kalabalığından sıkıldım artık...",
	"Hepsi aynı tornadan çıkmış et yığınları.",
	"Gördüklerini anlamayıp, inandıklarını görüyorlar.",
	"İmkanım olsa şu lanet yerde bir dakika durmam.",
	"Biçimsiz yüzler ve anlamsız sözler...",
	"Bu düzenin düzensizliğinden yoruldum.",
	"Bir süre ortadan kaybolsam kimsenin ruhu bile duymaz.",
	"Eğer bir gün burayı terk etseydim acaba nereye giderdim?"
]

func _ready():
	if kamera: varsayilan_fov = kamera.fov
	altyazi_label.text = ""

# --- GLITCH VE ALTYAZI TETİKLEYİCİSİ ---
func yolcuya_tiklandi(yolcu_node, yok_olacak_mi):
	# Eğer bekleme süresindeysek veya başka efekt varsa İPTAL ET
	if not etkilesim_aktif: return 
	
	etkilesim_aktif = false # Kilitle
	
	# 1. METİN GÖSTER
	var secilen_soz = diyaloglar.pick_random() # İstersen sırayla da yapabiliriz
	altyazi_label.text = secilen_soz
	
	# 2. GLITCH EFEKTİ (KAMERA VE FOV PATLAMASI)
	var tween = create_tween()
	
	# Kamerayı anlık olarak boz (Zoom in/out ve yamulma)
	tween.tween_property(kamera, "fov", 110.0, 0.05).set_trans(Tween.TRANS_BOUNCE)
	tween.parallel().tween_property(kamera, "h_offset", 0.1, 0.05) # Sağa kay
	
	tween.tween_property(kamera, "fov", 60.0, 0.05) # Ani Zoom
	tween.parallel().tween_property(kamera, "h_offset", -0.1, 0.05) # Sola kay
	
	tween.tween_property(kamera, "fov", varsayilan_fov, 0.1) # Normale dön
	tween.parallel().tween_property(kamera, "h_offset", 0.0, 0.1)

	# 3. YOLCUYU TİTRET veya YOK ET
	if yok_olacak_mi:
		# İkinci tıklayış: Yok et
		yolcu_node.visible = false
		# Opsiyonel: Yok olma sesi çalabilirsin
	else:
		# İlk tıklayış: Yolcuyu olduğu yerde titret
		var y_tween = create_tween()
		var org_pos = yolcu_node.position
		y_tween.tween_property(yolcu_node, "position", org_pos + Vector3(0.1, 0.1, 0), 0.05)
		y_tween.tween_property(yolcu_node, "position", org_pos - Vector3(0.1, 0.0, 0), 0.05)
		y_tween.tween_property(yolcu_node, "position", org_pos, 0.05)

	# 4. BEKLEME SÜRESİ (2.5 Saniye)
	await get_tree().create_timer(2.5).timeout
	
	# Temizle ve Aç
	altyazi_label.text = ""
	etkilesim_aktif = true
