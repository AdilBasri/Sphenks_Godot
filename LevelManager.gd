extends Node

# --- OYUN DURUMU ---
var suanki_katman: int = 1

# --- KONUM REFERANSLARI ---
var market_pos: Vector3
var campfire_pos: Vector3
var start_pos: Vector3
var oyuncu_ref: CharacterBody3D

# --- REFERANSLAR (Otomatik Bulunacak) ---
var oyun_odasi_ref: Node = null # OyunOdasi scriptine erişim için

# Oyun ilk açıldığında
func oyunu_baslat():
	suanki_katman = 1
	get_tree().change_scene_to_file("res://Scenes/OyunOdasi.tscn")

# OyunOdasi.gd _ready() fonksiyonunda burayı çağırıyor.
func konumlari_kaydet(p1: Vector3, p2: Vector3, p3: Vector3, oyuncu: CharacterBody3D, oda_ref: Node):
	market_pos = p1
	campfire_pos = p2
	start_pos = p3
	oyuncu_ref = oyuncu
	oyun_odasi_ref = oda_ref
	
	# Eğer oyun reload edildiyse (Katman > 1), oyuncuyu başlangıç noktasına taşı
	if suanki_katman > 1 and oyuncu_ref:
		oyuncu_ref.global_position = start_pos

# Bölüm bitti, her şey sıfırlanıp zorluk artacak
func odaya_don_ve_level_atla():
	suanki_katman += 1
	print(">>> YENİ KATMAN YÜKLENİYOR: " + str(suanki_katman))
	
	# 1. Mantar modunu veritabanından kapat
	if GameManager: GameManager.mantar_modu = false
	
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("mantar_efekti_yonet"):
		arayuz.mantar_efekti_yonet(false) # ZORLA KAPAT
		
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

# --- 🔥 GÜNCELLENEN BOSS SALDIRI SİSTEMİ 🔥 ---
# Bu fonksiyon OyunOdasi.gd tarafından çağrılır (Blok yerleşince)
func boss_saldirisi_baslat():
	print("🦁 LevelManager: Boss'a saldırı emri veriliyor...")
	
	# 1. Boss'u Bul
	var boss = get_tree().get_first_node_in_group("Dusman")
	
	if boss:
		# 2. Boss'un işi bitince haber vermesi için sinyal bağla
		if not boss.saldiri_tamamlandi.is_connected(_on_boss_isi_bitti):
			boss.saldiri_tamamlandi.connect(_on_boss_isi_bitti)
		
		# 3. KARARI BOSS'A BIRAK
		if boss.has_method("saldiri_baslat"):
			boss.saldiri_baslat()
		else:
			print("🔴 HATA: Boss bulundu ama 'saldiri_baslat' fonksiyonu yok!")
			_on_boss_isi_bitti()
	else:
		print("🔴 HATA: Sahnede 'Dusman' grubunda kimse yok! (Boss ölmüş olabilir)")
		_on_boss_isi_bitti() # Oyun donmasın diye turu bitir

# Boss işini bitirince (Taş attı veya Zar attı bitti) burası çalışır
func _on_boss_isi_bitti():
	print("✅ Tur tamamlandı. Sıra oyuncuda.")
	
	# OyunOdasi referansı varsa turu bitir
	if oyun_odasi_ref:
		if oyun_odasi_ref.has_method("tur_sonrasi_islemler"):
			oyun_odasi_ref.tur_sonrasi_islemler()
		elif oyun_odasi_ref.has_method("oyunu_devam_ettir"):
			oyun_odasi_ref.oyunu_devam_ettir()

# --- ZAR SİSTEMİ (Boss "Zar" seçerse burayı çağırır) ---
func zar_at_animasyonunu_baslat():
	print("🎲 LevelManager: Zar Animasyonu Başlatılıyor...")
	
	# OyunOdasi'ndaki görsel zar atma fonksiyonunu çağır
	if oyun_odasi_ref and oyun_odasi_ref.has_method("zar_at"):
		oyun_odasi_ref.zar_at() 
	else:
		# Yedek Plan: Animasyonsuz direkt hasar ver
		var hasar = randi_range(1, 3)
		oyuncuya_saldir(hasar)
		_on_boss_isi_bitti()

# --- MERKEZİ HASAR SİSTEMİ ---
func oyuncuya_saldir(hasar_miktari: int):
	print("⚔️ Saldırı Geldi! Ham Hasar: ", hasar_miktari)

	# 1. CLOAK (PELERİN) KONTROLÜ
	if GameManager and GameManager.zar_atlama_hakki > 0:
		GameManager.zar_atlama_hakki -= 1 
		
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz: arayuz.bilgi_goster("Pelerin Korudu!")
		print("👻 Pelerin sayesinde hasar engellendi!")
		return 

	# 2. DICE (ZAR) KONTROLÜ
	if GameManager and GameManager.zar_yok_sayma:
		hasar_miktari = int(hasar_miktari / 2.0)
		GameManager.zar_yok_sayma = false 
		
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz: arayuz.bilgi_goster("Zar Şansı: Az Hasar")
		print("🎲 Zar atıldı, hasar düştü.")

	# 3. HASARI OYUNCUYA UYGULA
	if oyuncu_ref:
		oyuncu_ref.hasar_al(hasar_miktari)
	else:
		var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
		if oyuncu:
			oyuncu.hasar_al(hasar_miktari)
