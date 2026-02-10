extends Node3D

# --- AYARLAR ---
@onready var kamera = $Oyuncu/Camera3D
@onready var altyazi_label = $UI/Label
# Az önce eklediğin Siyah Perdeye ulaşıyoruz
@onready var gecis_materyali = $UI/GecisEkrani.material 

var etkilesim_aktif = true 
var varsayilan_fov = 90.0

# YOLCU TAKİBİ
var toplam_yolcu_sayisi = 0
var yok_edilen_yolcu_sayisi = 0

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
	
	# Sahnede kaç tane "StaticBody3D" (Yolcu) var otomatik sayalım
	# (Yolcuların hepsini bir "Yolcular" düğümü altına topladıysan daha kolay olur
	# ama dağınık olsa bile 'get_children' veya gruplarla bulabiliriz.
	# Şimdilik manuel sayıp buraya yazabilirsin veya otomatik buldurabiliriz)
	
	# BASİT YÖNTEM: Sahneye kaç yolcu koyduysan buraya o sayıyı yaz.
	# Örneğin 5 yolcu varsa 5 yaz.
	toplam_yolcu_sayisi = 7 # <-- BURAYI SAHNEDEKİ YOLCU SAYINA GÖRE GÜNCELLE!
	
	# Geçiş ekranını tamamen şeffaf yap (Shader factor 0)
	gecis_materyali.set_shader_parameter("factor", 0.0)

# --- YOLCU TETİKLEYİCİSİ ---
func yolcuya_tiklandi(yolcu_node, yok_olacak_mi):
	if not etkilesim_aktif: return 
	
	etkilesim_aktif = false 
	
	# 1. METİN GÖSTER
	altyazi_label.text = diyaloglar.pick_random()
	
	# 2. GLITCH EFEKTİ
	if kamera:
		var tween = create_tween()
		tween.tween_property(kamera, "fov", 110.0, 0.05).set_trans(Tween.TRANS_BOUNCE)
		tween.parallel().tween_property(kamera, "h_offset", 0.05, 0.05)
		tween.tween_property(kamera, "fov", 60.0, 0.05)
		tween.parallel().tween_property(kamera, "h_offset", -0.05, 0.05)
		tween.tween_property(kamera, "fov", varsayilan_fov, 0.1)
		tween.parallel().tween_property(kamera, "h_offset", 0.0, 0.1)

	# 3. YOLCU İŞLEMİ
	if yok_olacak_mi:
		yolcu_node.visible = false
		yok_edilen_yolcu_sayisi += 1 # Sayacı artır
		
		# HERKES BİTTİ Mİ KONTROLÜ
		if yok_edilen_yolcu_sayisi >= toplam_yolcu_sayisi:
			bolum_sonu_gecisi_yap()
			return # Fonksiyondan çık, alttaki timer çalışmasın
			
	else:
		# Titretme
		var y_tween = create_tween()
		var org_pos = yolcu_node.position
		y_tween.tween_property(yolcu_node, "position", org_pos + Vector3(0.05, 0.05, 0), 0.05)
		y_tween.tween_property(yolcu_node, "position", org_pos, 0.05)

	# 4. BEKLEME SÜRESİ
	await get_tree().create_timer(2.5).timeout
	
	altyazi_label.text = ""
	etkilesim_aktif = true

func bolum_sonu_gecisi_yap():
	print("Tüm yolcular yok oldu. Sahne kararıyor...")
	altyazi_label.text = "" 
	
	# YENİ SATIR: Oyuncunun titremesini durdur
	# (Sahne kararırken sarsıntı dursun, huzurlu bir bayılma hissi versin)
	$Oyuncu.titreme_aktif = false 
	
	var tween = create_tween()
	tween.tween_property(gecis_materyali, "shader_parameter/factor", 1.0, 3.0)
	
	await tween.finished
	get_tree().change_scene_to_file("res://Sahne2_Ev.tscn")
