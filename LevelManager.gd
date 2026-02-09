extends Node

# --- OYUN DURUMU ---
var suanki_katman: int = 1
var isleme_alindi_mi: bool = false

# --- KONUM REFERANSLARI ---
var market_pos: Vector3
var campfire_pos: Vector3
var start_pos: Vector3
var oyuncu_ref: CharacterBody3D

# --- REFERANSLAR ---
var oyun_odasi_ref: Node = null 

func oyunu_baslat():
	suanki_katman = 1
	get_tree().change_scene_to_file("res://Scenes/OyunOdasi.tscn")

func konumlari_kaydet(p1: Vector3, p2: Vector3, p3: Vector3, oyuncu: CharacterBody3D, oda_ref: Node):
	market_pos = p1
	campfire_pos = p2
	start_pos = p3
	oyuncu_ref = oyuncu
	oyun_odasi_ref = oda_ref
	
	if suanki_katman > 1 and oyuncu_ref:
		oyuncu_ref.global_position = start_pos

func odaya_don_ve_level_atla():
	suanki_katman += 1
	print(">>> YENİ KATMAN YÜKLENİYOR: " + str(suanki_katman))
	
	# --- DEĞİŞEN KISIM ---
	# Eskiden sadece mantarı kapatıyorduk, şimdi toplu temizlik yapıyoruz.
	if GameManager:
		GameManager.bolum_bufflarini_sifirla()
		
		# Arayüzdeki mantar efektini de garanti olsun diye kapatıyoruz
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz and arayuz.has_method("mantar_efekti_yonet"):
			arayuz.mantar_efekti_yonet(false) 
	# ---------------------
	
	call_deferred("_sahne_yenile")

func _sahne_yenile():
	# --- 🔥 KRİTİK: PYRO MODU AÇ/KAPA 🔥 ---
	if suanki_katman % 3 == 0:
		GameManager.pyro_aktif = true
		print("🔥🔥🔥 PYRO MODU AKTİF! (Katman: " + str(suanki_katman) + ") 🔥🔥🔥")
	else:
		GameManager.pyro_aktif = false
		print("🌲 Normal Mod (Katman: " + str(suanki_katman) + ")")
	# ---------------------------------------
	
	get_tree().reload_current_scene()

func bolum_verilerini_getir() -> Dictionary:
	var veri = {}
	
	# --- 🔥 PYRO MODU (KATMAN 3 ve KATLARI) 🔥 ---
	if suanki_katman % 3 == 0:
		var pyro_level = suanki_katman / 3
		veri["bolum_adi"] = "PYRO " + str(pyro_level)
		veri["hedef_puan"] = 540 + ((suanki_katman - 2) * 200) 
		veri["blok_limiti"] = 15 + (suanki_katman - 2) 
		veri["boss_resmi"] = "res://hammer.png" 
		
		# Pyro'ya özel ekstralar
		veri["dusman_sayisi"] = 5 + ((pyro_level - 1) * 2)
		veri["atmosfer_rengi"] = Color(0.8, 0.1, 0.1, 1.0) # Kırmızı Atmosfer
		
		# --- 🛠️ DÜZELTME: Dictionary Hatasını Çözen Satır ---
		veri["katman"] = suanki_katman 
		# ---------------------------------------------------
		
		return veri
	# -----------------------------------------------

	# NORMAL MOD
	match suanki_katman:
		1:
			veri["hedef_puan"] = 300; veri["blok_limiti"] = 12; veri["boss_resmi"] = "res://blob.png"
		2:
			veri["hedef_puan"] = 540; veri["blok_limiti"] = 15; veri["boss_resmi"] = "res://hammer.png"
		_:
			veri["hedef_puan"] = 540 + ((suanki_katman - 2) * 200)
			veri["blok_limiti"] = 15 + (suanki_katman - 2)
			veri["boss_resmi"] = "res://hammer.png"
	veri["katman"] = suanki_katman
	veri["atmosfer_rengi"] = Color(1, 1, 1, 1) # Normal Beyaz
	return veri

# --- BOSS & HASAR SİSTEMLERİ ---
# --- BOSS SALDIRI SİSTEMİ ---
func boss_saldirisi_baslat():
	# Pyro modunda sıra tabanlı boss saldırısı olmaz, gerçek zamanlı olur.
	if GameManager.pyro_aktif:
		print("🔥 PYRO Modundayız: Sıra tabanlı saldırı iptal.")
		return

	var boss = get_tree().get_first_node_in_group("Dusman")
	if boss:
		if not boss.saldiri_tamamlandi.is_connected(_on_boss_isi_bitti):
			boss.saldiri_tamamlandi.connect(_on_boss_isi_bitti)
		
		if boss.has_method("saldiri_baslat"):
			boss.saldiri_baslat()
		else:
			_on_boss_isi_bitti()
	else:
		_on_boss_isi_bitti()
		_on_boss_isi_bitti()

func _on_boss_isi_bitti():
	print("✅ Tur tamamlandı. Sıra oyuncuda.")
	if oyun_odasi_ref:
		if oyun_odasi_ref.has_method("tur_sonrasi_islemler"): oyun_odasi_ref.tur_sonrasi_islemler()
		elif oyun_odasi_ref.has_method("oyunu_devam_ettir"): oyun_odasi_ref.oyunu_devam_ettir()

# --- ZAR SİSTEMİ ve PELERİN KONTROLÜ ---
func zar_at_animasyonunu_baslat():
	if isleme_alindi_mi: return 
	isleme_alindi_mi = true

	# --- 1. PELERİN (CLOAK) KONTROLÜ ---
	if GameManager and GameManager.pelerin_korumasi_var_mi():
		# Hakkı 1 düş
		GameManager.pelerin_hak_dus()
		
		var kalan = GameManager.zar_atlama_hakki
		print("👻 Pelerin aktif! Zar sekansı atlanıyor. Kalan Hak: ", kalan)
		
		# Ekrana bilgi yaz
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz: 
			if kalan > 0:
				arayuz.bilgi_goster("PELERİN KORUDU! (Kalan: %d)" % kalan, 2.0)
			else:
				arayuz.bilgi_goster("PELERİN PARÇALANDI!", 2.0)
		
		# Zarları HİÇ çağırmadan direkt turu bitir
		# Biraz bekle ki oyuncu mesajı okusun
		await get_tree().create_timer(1.5).timeout
		
		# Flag'i aç ki sonraki turda tekrar çalışabilsin
		isleme_alindi_mi = false
		
		_on_boss_isi_bitti() 
		return 

	# --- 2. NORMAL ZAR ATMA SÜRECİ ---
	print("🎲 LevelManager: Koruma yok. Zar atılıyor...")
	
	if oyun_odasi_ref and oyun_odasi_ref.has_method("zar_at"):
		oyun_odasi_ref.zar_at()
	else:
		oyuncuya_saldir(randi_range(1, 3))
		_on_boss_isi_bitti()
		
	# Flag'i sle (Oyun odası işini bitirince yapacak ama garanti olsun)
	await get_tree().create_timer(1.0).timeout
	isleme_alindi_mi = false

func oyuncuya_saldir(hasar_miktari: int):
	print("⚔️ Saldırı Geldi! Ham Hasar: ", hasar_miktari)

	if GameManager and GameManager.pelerin_korumasi_var_mi():
		GameManager.pelerin_hak_dus()
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz: arayuz.bilgi_goster("Pelerin Hasarı Engelledi!")
		return 

	if GameManager and GameManager.zar_yok_sayma:
		hasar_miktari = int(hasar_miktari / 2.0)
		GameManager.zar_yok_sayma = false 
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz: arayuz.bilgi_goster("Zar Şansı: Az Hasar")

	if oyuncu_ref:
		oyuncu_ref.hasar_al(hasar_miktari)
	else:
		var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
		if oyuncu: oyuncu.hasar_al(hasar_miktari)
