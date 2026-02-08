extends Node

# --- OYUN DURUMU ---
var suanki_katman: int = 1

# --- KONUM REFERANSLARI ---
var market_pos: Vector3
var campfire_pos: Vector3
var start_pos: Vector3
var oyuncu_ref: CharacterBody3D

# Oyun ilk açıldığında
func oyunu_baslat():
	suanki_katman = 1
	get_tree().change_scene_to_file("res://Scenes/OyunOdasi.tscn")

# OyunOdasi.gd _ready() fonksiyonunda burayı çağırıyor.
func konumlari_kaydet(p1: Vector3, p2: Vector3, p3: Vector3, oyuncu: CharacterBody3D):
	market_pos = p1
	campfire_pos = p2
	start_pos = p3
	oyuncu_ref = oyuncu
	
	# Eğer oyun reload edildiyse (Katman > 1), oyuncuyu başlangıç noktasına taşı
	if suanki_katman > 1 and oyuncu_ref:
		oyuncu_ref.global_position = start_pos

# LevelManager.gd Dosyası:

# Bölüm bitti, her şey sıfırlanıp zorluk artacak
func odaya_don_ve_level_atla():
	suanki_katman += 1
	print(">>> YENİ KATMAN YÜKLENİYOR: " + str(suanki_katman))
	
	# --- YENİ EKLENEN KISIM ---
	# 1. Mantar modunu veritabanından kapat
	GameManager.mantar_modu = false
	
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("mantar_efekti_yonet"):
		arayuz.mantar_efekti_yonet(false) # ZORLA KAPAT
	# --------------------------
		
	call_deferred("_sahne_yenile")

func _sahne_yenile():
	get_tree().reload_current_scene()

# BlokDağıtıcısı bu fonksiyonu çağırıp zorluğu öğrenecek
func bolum_verilerini_getir() -> Dictionary:
	var veri = {}
	
	# ZORLUK AYARLARI
	match suanki_katman:
		1:
			veri["hedef_puan"] = 300
			veri["blok_limiti"] = 12
			veri["boss_resmi"] = "res://blob.png"
		2:
			veri["hedef_puan"] = 540 
			veri["blok_limiti"] = 15
			veri["boss_resmi"] = "res://hammer.png"
		_:
			# 3. Seviye ve sonrası (Formülize edilmiş zorluk)
			veri["hedef_puan"] = 540 + ((suanki_katman - 2) * 200)
			veri["blok_limiti"] = 15 + (suanki_katman - 2)
			veri["boss_resmi"] = "res://hammer.png"
	
	veri["katman"] = suanki_katman
	return veri

# --- 🔥 YENİ EKLENEN: MERKEZİ HASAR SİSTEMİ 🔥 ---
# Düşmanlar oyuncuya vurmak istediğinde DİREKT oyuncuya değil, BURAYA başvuracak.
func oyuncuya_saldir(hasar_miktari: int):
	print("Saldırı Geldi! Ham Hasar: ", hasar_miktari)

	# 1. CLOAK (PELERİN) KONTROLÜ
	if GameManager.zar_atlama_hakki > 0:
		GameManager.zar_atlama_hakki -= 1 # Hakkı 1 düşür
		
		# Bilgi Göster
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz: arayuz.bilgi_goster("Pelerin Korudu!")
		print("👻 Pelerin sayesinde hasar engellendi!")
		return # FONKSİYONDAN ÇIK (Hasar alma)

	# 2. DICE (ZAR) KONTROLÜ
	if GameManager.zar_yok_sayma:
		hasar_miktari = int(hasar_miktari / 2.0) # Hasarı yarıya indir
		# İstersen hasarı sıfırlayabilirsin veya rastgele azaltabilirsin
		
		GameManager.zar_yok_sayma = false # Tek kullanımlık
		
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz: arayuz.bilgi_goster("Zar Şansı: Az Hasar")
		print("🎲 Zar atıldı, hasar düştü.")

	# 3. HASARI OYUNCUYA UYGULA
	if oyuncu_ref:
		oyuncu_ref.hasar_al(hasar_miktari)
	else:
		# Yedek plan: Gruptan bul
		var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
		if oyuncu:
			oyuncu.hasar_al(hasar_miktari)
