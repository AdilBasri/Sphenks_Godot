extends Node3D

# --- DEĞİŞKENLER ---
var kamera = null
var altyazi_label = null
var gecis_perdesi = null
var oyuncu = null

var etkilesim_aktif = true 
var varsayilan_fov = 90.0
var toplam_yolcu_sayisi = 7 # <-- Yolcu sayın
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
	# --- 1. OYUNCUYU VE KAMERAYI BUL (DEDEKTİF YÖNTEMİ) ---
	# Sahne içindeki ismi "Oyuncu" olan düğümü ara (Recursive: True)
	oyuncu = find_child("Oyuncu", true, false)
	
	if oyuncu:
		# Oyuncunun içindeki Kamerayı ara
		kamera = oyuncu.find_child("Camera3D", true, false)
		if kamera:
			varsayilan_fov = kamera.fov
	
	# --- 2. UI ELEMANLARINI BUL ---
	# İsmi tam olarak "Label" olanı bul
	altyazi_label = find_child("Label", true, false)
	if altyazi_label: altyazi_label.text = "" 

	# İsmi "GecisEkrani" olanı bul
	gecis_perdesi = find_child("GecisEkrani", true, false)
	
	if gecis_perdesi:
		if gecis_perdesi.material:
			gecis_perdesi.material.set_shader_parameter("factor", 0.0)
	else:
		print("⚠️ 'GecisEkrani' bulunamadı! (İsmini kontrol et veya sahneyi kaydet)")

# --- YOLCU TETİKLEYİCİSİ ---
func yolcuya_tiklandi(yolcu_node, yok_olacak_mi):
	if not etkilesim_aktif: return 
	
	etkilesim_aktif = false 
	
	if altyazi_label:
		altyazi_label.text = diyaloglar.pick_random()
	
	if kamera:
		var tween = create_tween()
		tween.tween_property(kamera, "fov", 110.0, 0.05).set_trans(Tween.TRANS_BOUNCE)
		tween.parallel().tween_property(kamera, "h_offset", 0.05, 0.05)
		tween.tween_property(kamera, "fov", 60.0, 0.05)
		tween.parallel().tween_property(kamera, "h_offset", -0.05, 0.05)
		tween.tween_property(kamera, "fov", varsayilan_fov, 0.1)
		tween.parallel().tween_property(kamera, "h_offset", 0.0, 0.1)

	if yok_olacak_mi:
		yolcu_node.visible = false
		yok_edilen_yolcu_sayisi += 1 
		
		if yok_edilen_yolcu_sayisi >= toplam_yolcu_sayisi:
			bolum_sonu_gecisi_yap()
			return 
	else:
		var y_tween = create_tween()
		var org_pos = yolcu_node.position
		y_tween.tween_property(yolcu_node, "position", org_pos + Vector3(0.05, 0.05, 0), 0.05)
		y_tween.tween_property(yolcu_node, "position", org_pos, 0.05)

	await get_tree().create_timer(2.5).timeout
	
	if altyazi_label:
		altyazi_label.text = ""
	etkilesim_aktif = true

func bolum_sonu_gecisi_yap():
	print("Sahne kararıyor...")
	if altyazi_label: altyazi_label.text = "" 
	
	if oyuncu and "titreme_aktif" in oyuncu:
		oyuncu.titreme_aktif = false 
	
	if gecis_perdesi and gecis_perdesi.material:
		var tween = create_tween()
		tween.tween_property(gecis_perdesi.material, "shader_parameter/factor", 1.0, 3.0)
		await tween.finished
	else:
		await get_tree().create_timer(3.0).timeout

	get_tree().change_scene_to_file("res://Scenes/Sahne2_Ev.tscn")
