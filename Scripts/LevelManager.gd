extends Node

# --- OYUN DURUMU ---
var suanki_katman: int = 1
var isleme_alindi_mi: bool = false
var is_boss_acting: bool = false:
	set(value):
		is_boss_acting = value
		if value:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		else:
			if is_instance_valid(oyuncu_ref) and "mouse_serbest_modu" in oyuncu_ref and oyuncu_ref.mouse_serbest_modu:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			elif not is_instance_valid(oyuncu_ref):
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- KONUM REFERANSLARI ---
var market_pos: Vector3
var campfire_pos: Vector3
var start_pos: Vector3
var oyuncu_ref: CharacterBody3D
var oyun_odasi_ref: Node = null 

func oyunu_baslat():
	# GameManager'dan kayıtlı seviyeyi kontrol et
	if GameManager.kayitli_seviye > 1:
		suanki_katman = GameManager.kayitli_seviye
		print("💾 Kayıtlı seviyeden devam ediliyor: Katman " + str(suanki_katman))
	else:
		suanki_katman = 1
		print("🆕 Yeni oyun başlatılıyor: Katman 1")

	_sahne_yukle_ve_kontrol_et()

func _sahne_yukle_ve_kontrol_et():
	# Sahne ismine göre state'i kesinleştiriyoruz
	if suanki_katman % 3 == 0:
		GameManager.pyro_aktif = true
		GameManager.silah_cekildi = true
		get_tree().change_scene_to_file("res://Scenes/PyroKoridoru.tscn")
		
		# --- PYRO TUTORIALINI BAŞLAT ---
		if TutorialManager:
			TutorialManager.call_deferred("start_tutorial_segment", "pyro")
	else:
		GameManager.pyro_aktif = false 
		GameManager.silah_cekildi = false
		get_tree().change_scene_to_file("res://Scenes/Sphenks.tscn")

func konumlari_kaydet(p1: Vector3, p2: Vector3, p3: Vector3, oyuncu: CharacterBody3D, oda_ref: Node):
	market_pos = p1
	campfire_pos = p2
	start_pos = p3
	oyuncu_ref = oyuncu
	oyun_odasi_ref = oda_ref
	
	# Bölüm yüklendiğinde oyuncuyu spawn noktasına ışınla
	if suanki_katman > 1 and oyuncu_ref:
		# Oyuncu grid üstüne oturmuş veya move_and_slide'da sıkışmış olabilir. 
		# Bu yüzden global_position atamasını bir frame sonra yaparız.
		call_deferred("_oyuncuyu_baslangica_isinla")

func _oyuncuyu_baslangica_isinla():
	if is_instance_valid(oyuncu_ref):
		oyuncu_ref.global_position = start_pos + Vector3(0, 0.5, 0)
		oyuncu_ref.velocity = Vector3.ZERO

func odaya_don_ve_level_atla():
	var onceki_katman = suanki_katman
	# Katmanı bir artır ve ilerlemeyi kaydet
	suanki_katman += 1
	
	if SaveManager:
		var alinacak_yildiz = 3
		if GameManager and GameManager.oyuncu_suanki_hp <= 5:
			alinacak_yildiz = 1
		elif GameManager and GameManager.oyuncu_suanki_hp <= 8:
			alinacak_yildiz = 2
		SaveManager.complete_level(onceki_katman, alinacak_yildiz)
		
	if GameManager:
		GameManager.suanki_seviye = suanki_katman
		GameManager.mantar_modu = false
		GameManager.silah_cekildi = false # KESİN SİLAH KAPATMA
		GameManager.pyro_aktif = false    # KESİN PYRO KAPATMA
		GameManager.yeme_aktif_mi = false
	
	is_boss_acting = false # KESİN BOSS KİLİDİ AÇMA
	
	# Oyuncunun elde tuttuğu nesneyi/eşya temizle
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu:
		if oyuncu.get("tutulan_nesne") and oyuncu.has_method("birak_veya_firlat"):
			oyuncu.birak_veya_firlat()
		if oyuncu.get("eldeki_ozel_esya") and oyuncu.has_method("esya_birak"):
			oyuncu.esya_birak()
	
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("mantar_efekti_yonet"):
		arayuz.mantar_efekti_yonet(false) 
		
	call_deferred("_sahne_yenile")

func _sahne_yenile():
	_sahne_yukle_ve_kontrol_et()

func bolum_verilerini_getir() -> Dictionary:
	var veri = {}
	if suanki_katman % 3 == 0:
		var pyro_level = suanki_katman / 3
		veri["bolum_adi"] = "PYRO " + str(pyro_level)
		veri["hedef_puan"] = 540 + ((suanki_katman - 2) * 200) 
		veri["blok_limiti"] = 15 + (suanki_katman - 2) 
		veri["boss_resmi"] = "res://Assets/Images/hammer.png" 
		veri["dusman_sayisi"] = 5 + ((pyro_level - 1) * 2)
		veri["atmosfer_rengi"] = Color(0.8, 0.1, 0.1, 1.0) 
		veri["katman"] = suanki_katman 
		return veri

	match suanki_katman:
		1:
			veri["hedef_puan"] = 300; veri["blok_limiti"] = 12; veri["boss_resmi"] = "res://Assets/Images/blob.png"
		2:
			veri["hedef_puan"] = 540; veri["blok_limiti"] = 15; veri["boss_resmi"] = "res://Assets/Images/hammer.png"
		_:
			veri["hedef_puan"] = 540 + ((suanki_katman - 2) * 200)
			veri["blok_limiti"] = 15 + (suanki_katman - 2)
			veri["boss_resmi"] = "res://Assets/Images/hammer.png"
	
	veri["katman"] = suanki_katman
	veri["atmosfer_rengi"] = Color(1, 1, 1, 1)
	return veri

func boss_saldirisi_baslat():
	# Sadece Pyro olmayan seviyelerde çalışır
	if GameManager.pyro_aktif: return

	# is_boss_acting oyuncunun blok atmasını engellemek için dışarıdan (oyun_odasi) set edilir.
	# Dolayısıyla boss'un kendi saldırmasını burada durdurmamalı.
	# (Double-call vs olmaz çünkü dışarıdan kontrollü)

	var boss = get_tree().get_first_node_in_group("Dusman")
	if boss:
		# KİLİTLE — oyuncu blok koyamaz
		is_boss_acting = true
		get_tree().call_group("Blok", "iptal_et")
		print("🔒 Boss sırası KİLİTLENDİ. Eldeki bloklar iptal edildi.")

		if not boss.saldiri_tamamlandi.is_connected(_on_boss_isi_bitti):
			boss.saldiri_tamamlandi.connect(_on_boss_isi_bitti)
		
		# Boss uyanma ve saldırı sürecini başlatır
		boss.saldiri_baslat()
	else:
		_on_boss_isi_bitti()

func _on_boss_isi_bitti():
	# KİLİDİ AÇ — oyuncu tekrar blok koyabilir
	is_boss_acting = false
	print("🔓 Boss sırası AÇILDI.")

	# Kamera Güvenliği: Boss saldırısı veya zar bittiğinde kamera oyuncuya döner
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu:
		var cam = oyuncu.find_child("Camera3D", true, false)
		if cam and not cam.current:
			cam.make_current()

	if oyun_odasi_ref and oyun_odasi_ref.has_method("tur_sonrasi_islemler"):
		oyun_odasi_ref.tur_sonrasi_islemler()

func zar_at_animasyonunu_baslat():
	if isleme_alindi_mi: return 
	isleme_alindi_mi = true

	# Pelerin korumasi varsa: ses çalma, zarı engelle ve geç
	if GameManager and GameManager.pelerin_korumasi_var_mi():
		GameManager.pelerin_hak_dus()
		print("🛡️ Pelerin zar engelledi! Kalan hak: ", GameManager.zar_atlama_hakki)
		await get_tree().create_timer(1.5).timeout
		isleme_alindi_mi = false
		_on_boss_isi_bitti() 
		return 

	# Pelerin yok → Zar gerçekten atılıyor, şimdi ses çal
	var sfx_dice = AudioStreamPlayer.new()
	sfx_dice.stream = load("res://Sesler/dice_roll.mp3")
	sfx_dice.bus = "SFX"
	add_child(sfx_dice)
	sfx_dice.play()
	sfx_dice.finished.connect(sfx_dice.queue_free)

	if oyun_odasi_ref and oyun_odasi_ref.has_method("zar_at"):
		oyun_odasi_ref.zar_at()
	else:
		oyuncuya_saldir(randi_range(1, 3))
		_on_boss_isi_bitti()
	
	# isleme_alindi_mi'yi burada sıfırlarsam, odanın zarı atmasını beklemeden kilidi açar.
	# Bunu önlemek için oyun odası zar işlemini bitirince sıfırlanmalıdır.
	# LevelManager'dan bu kilidi açacak fonksiyon ekliyoruz (veya zar bitince false yapıyoruz).

func oyuncuya_saldir(hasar_miktari: int):
	if GameManager and GameManager.pelerin_korumasi_var_mi():
		GameManager.pelerin_hak_dus()
		return 

	if GameManager and GameManager.zar_yok_sayma:
		hasar_miktari = int(hasar_miktari / 2.0)
		GameManager.zar_yok_sayma = false 

	if oyuncu_ref:
		oyuncu_ref.hasar_al(hasar_miktari)
