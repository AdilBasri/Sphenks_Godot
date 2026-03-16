extends Node

# --- OYUN DURUMU ---
var suanki_katman: int = 1
var isleme_alindi_mi: bool = false
var saldiri_devrede: bool = false
var is_pyro_encounter: bool = false # Rastgele ara katman durumunu takip eder
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
var normal_boss_ref: Node3D = null
var acid_boss_ref: Node3D = null
var stone_boss_ref: Node3D = null
var aktif_ana_boss: Node3D = null # Suanki seviyenin ana bossu

func is_acid_boss_level() -> bool:
	# 1, 4, 7... pattern (katman % 3 == 1)
	return suanki_katman % 3 == 1

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
	if is_pyro_encounter:
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
	
	# Boss referanslarını bul ve ayarla
	_boss_sistemini_ayarla()
	
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
	
	# Katman geçiş mantığı
	if is_pyro_encounter:
		# Pyro ara katmanından geliyorsak katman artırma, sadece geri dön
		is_pyro_encounter = false
		print("🔥 Pyro ara katmanı tamamlandı, katman sabit: ", suanki_katman)
	else:
		# Normal katman bitti, katmanı artır ve %20 ihtimalle Pyro'ya sok
		suanki_katman += 1
		if randf() < 0.20:
			is_pyro_encounter = true
			print("🎲 Zar atıldı: Rastgele Pyro karşına çıktı!")
		else:
			is_pyro_encounter = false
	
	if SaveManager:
		var alinacak_yildiz = 3
		if GameManager and GameManager.oyuncu_suanki_hp <= 5:
			alinacak_yildiz = 1
		elif GameManager and GameManager.oyuncu_suanki_hp <= 8:
			alinacak_yildiz = 2
		SaveManager.complete_level(onceki_katman, alinacak_yildiz)
		
	if GameManager:
		GameManager.suanki_seviye = suanki_katman
		GameManager.silah_cekildi = false # KESİN SİLAH KAPATMA
		GameManager.pyro_aktif = false    # KESİN PYRO KAPATMA
		GameManager.yeme_aktif_mi = false
		
		# Bölüm geçişinde buff efektlerini sıfırla (item'lar envanterde kalır,
		# sadece o bölümde aktif olan efektler — puan_carpani, revive, fener vb. — kapanır)
		GameManager.bolum_bufflarini_sifirla()
		
		# İlk seviyelerde direkt kaydet ki kediye gitmese de tutorials vb. kaybolmasın
		if suanki_katman <= 1:
			GameManager.oyunu_kaydet()
	
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
		
	# Sahneyi temizle ve referansları sıfırla (Bellek sızıntısı önleme)
	oyun_odasi_ref = null
	oyuncu_ref = null
	
	call_deferred("_sahne_yenile")

func _boss_sistemini_ayarla():
	if not oyun_odasi_ref: 
		print("HATA: oyun_odasi_ref bulunamadi!")
		return
	
	# Daha agrasif arama
	normal_boss_ref = oyun_odasi_ref.find_child("NormalBoss", true, false)
	acid_boss_ref = oyun_odasi_ref.find_child("AcidBoss", true, false)
	stone_boss_ref = oyun_odasi_ref.find_child("StoneBoss", true, false)
	
	var tabure = oyun_odasi_ref.find_child("Tabure", true, false)
	var acid_mi = is_acid_boss_level()
	
	print("--- BOSS YAPILANDIRMASI BASLADI ---")
	print("NormalBoss: ", "BULDUM" if normal_boss_ref else "YOK")
	print("AcidBoss: ", "BULDUM" if acid_boss_ref else "YOK")
	print("StoneBoss: ", "BULDUM" if stone_boss_ref else "YOK")
	print("Katman: ", suanki_katman)

	# Bölüm başında blok sayacını sıfırla (Zar Bossu kuralı için)
	if "blok_sayaci" in oyun_odasi_ref:
		oyun_odasi_ref.blok_sayaci = 0
		print("🔄 Blok sayacı sıfırlandı.")

	# 1. Garanti temizlik
	if normal_boss_ref:
		normal_boss_ref.visible = false
		normal_boss_ref.remove_from_group("Dusman")
		if "sfx_snore" in normal_boss_ref and normal_boss_ref.sfx_snore:
			normal_boss_ref.sfx_snore.stop()
		var n_cam = normal_boss_ref.find_child("Camera3D", true, false)
		if n_cam and n_cam is Camera3D: n_cam.current = false

	if acid_boss_ref:
		acid_boss_ref.visible = false
		acid_boss_ref.remove_from_group("Dusman")

	if stone_boss_ref:
		stone_boss_ref.visible = false
		stone_boss_ref.remove_from_group("Dusman")
	
	# Garanti collision temizliği
	disable_all_boss_collisions()

	# 2. Aktif Boss'u Belirle
	var aktif_boss: Node3D = null
	var mod_katman = suanki_katman % 3
	
	if mod_katman == 1: aktif_ana_boss = acid_boss_ref
	elif mod_katman == 2: aktif_ana_boss = stone_boss_ref
	else: aktif_ana_boss = normal_boss_ref
	
	aktif_boss = aktif_ana_boss
	
	if aktif_boss:
		aktif_boss.visible = true
		aktif_boss.add_to_group("Dusman")
		_set_boss_collision(aktif_boss, true) # Aktif boss collision aç
		if aktif_boss.has_method("boss_durumu_sifirla"):
			aktif_boss.boss_durumu_sifirla()
		aktif_boss.scale = Vector3(1.5, 1.5, 1.5)
		
		# Boss ana pozisyonunda
		aktif_boss.global_position = start_pos + Vector3(0, -0.5, -4.5) 
		
		# --- 👹 BOSS KAÇTI: YANCI BOSS SPAWN ---
		if GameManager and GameManager.boss_kacti:
			var kacan_tip = GameManager.kacan_boss_tipi
			var kacan_hp = GameManager.boss_kalan_hp
			
			# Kaçan boss'u sağa (Minion 1) veya sola (Minion 2) spawn et
			# USER REQUEST: 3'lü spawn desteği (eğer zaten minion varsa öbürü dolu olmalı)
			# Şimdilik kaçan boss'u sağa, eğer stone boss katmanı ise ve normal boss kaçtıysa sola da ekleyebiliriz
			_yanci_spawn_et(kacan_tip, kacan_hp)
			
			GameManager.boss_kacti = false
			GameManager.boss_kalan_hp = 0
		
		_bosslari_yeniden_konumlandir()
		
		# Birleşik Boss kamerasını bul ve başlangıçta kapat
		var boss_cam = oyun_odasi_ref.find_child("BossCamera", true, false)
		if boss_cam and boss_cam is Camera3D:
			boss_cam.current = false
	else:
		print("KRITIK HATA: Aktif boss bulunamadi!")

	# 3. Yan Parcalar (Tabure) sadece NormalBoss'ta görünür
	if tabure:
		tabure.visible = (aktif_boss == normal_boss_ref)
		if tabure.visible:
			tabure.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			tabure.process_mode = Node.PROCESS_MODE_DISABLED

	print("--- YAPILANDIRMA BITTI ---")

func _yanci_spawn_et(tip: int, hp: int):
	var yanci_prefab: Node3D = null
	if tip == 1: yanci_prefab = acid_boss_ref
	elif tip == 2: yanci_prefab = stone_boss_ref
	else: yanci_prefab = normal_boss_ref
	
	if yanci_prefab:
		var twin = yanci_prefab.duplicate()
		yanci_prefab.get_parent().add_child(twin)
		twin.name = yanci_prefab.name + "_Minion_" + str(randi() % 1000)
		twin.visible = true
		twin.add_to_group("Dusman")
		_set_boss_collision(twin, true)
		twin.scale = Vector3(1.0, 1.0, 1.0) # Yancılar daha küçük
		
		if hp > 0:
			# HP atamasını hemen yap (BlokDagiticisi HP kontrolü için beklememeli)
			twin.boss_hp = hp
			get_tree().create_timer(0.2).timeout.connect(func():
				if is_instance_valid(twin):
					if twin.has_method("boss_durumu_sifirla"): twin.boss_durumu_sifirla()
			)

func _bosslari_yeniden_konumlandir():
	var dusmanlar = get_tree().get_nodes_in_group("Dusman")
	var yasayanlar = []
	for d in dusmanlar:
		if is_instance_valid(d) and not d.get("oldu_mu"):
			yasayanlar.append(d)
	
	var merkez = start_pos + Vector3(0, -1.76, -4.5)
	
	# Sıralama: Aktif ana boss hayattaysa onu merkez (index 0) yap
	var sirali_yasayanlar = []
	if is_instance_valid(aktif_ana_boss) and not aktif_ana_boss.get("oldu_mu"):
		sirali_yasayanlar.append(aktif_ana_boss)
	
	for d in yasayanlar:
		if d != aktif_ana_boss:
			sirali_yasayanlar.append(d)
	
	for i in range(sirali_yasayanlar.size()):
		var b = sirali_yasayanlar[i]
		var target_pos = merkez
		var target_scale = Vector3(1.5, 1.5, 1.5) # DEFAULT: Ana Boss boyutu
		
		if sirali_yasayanlar.size() == 1:
			target_pos = merkez
			target_scale = Vector3(1.5, 1.5, 1.5)
		elif sirali_yasayanlar.size() == 2:
			if i == 0: # MERKEZ/ANA BOSS (Eğer aktif_ana_boss ise merkeze yakın durur)
				target_pos = merkez + Vector3(1.0, 0, 0.4)
				target_scale = Vector3(1.4, 1.4, 1.4)
			else: # Yanci
				target_pos = merkez + Vector3(-1.8, 0, 0.5)
				target_scale = Vector3(0.9, 0.9, 0.9)
		elif sirali_yasayanlar.size() >= 3:
			if i == 0: # ANA BOSS ORTADA
				target_pos = merkez
				target_scale = Vector3(1.5, 1.5, 1.5)
			elif i == 1: # Sağ
				target_pos = merkez + Vector3(2.5, 0, 0.8)
				target_scale = Vector3(0.9, 0.9, 0.9)
			else: # Sol
				target_pos = merkez + Vector3(-2.5, 0, 0.8)
				target_scale = Vector3(0.9, 0.9, 0.9)
		
		b.global_position = target_pos
		b.scale = target_scale
		
		# Normal Boss (BossCanavar) ise animasyon driftini önlemek için base position'ı güncelle
		if b.has_method("update_base_position"):
			b.update_base_position(target_pos)

func _sahne_yenile():
	_sahne_yukle_ve_kontrol_et()

func bolum_verilerini_getir() -> Dictionary:
	var veri = {}
	if is_pyro_encounter:
		# Pyro bir ara katman olduğu için katman ismi yazılmayacak
		veri["bolum_adi"] = DilYoneticisi.metin_al("karanlik_koridor") if DilYoneticisi else "Karanlik Koridor"
		veri["hedef_puan"] = 540 + ((suanki_katman - 2) * 200) 
		veri["blok_limiti"] = 15 + (suanki_katman - 2) 
		veri["boss_resmi"] = "res://Assets/Images/hammer.png" 
		veri["dusman_sayisi"] = 5 + ((suanki_katman / 3) * 2) # Tahmini zorluk
		veri["atmosfer_rengi"] = Color(0.8, 0.1, 0.1, 1.0) 
		veri["katman"] = 0 # UI'da katman yazılmaması için 0 veya özel flag
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
	
	if saldiri_devrede:
		print("⚠️ Boss saldırısı zaten devrede, kopya çağrı engellendi.")
		return
	saldiri_devrede = true

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
	saldiri_devrede = false
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
	sfx_dice.stream = load("res://Assets/Audio/dice_roll.mp3")
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

# --- COLLISION YONETIMI ---
func disable_all_boss_collisions():
	if normal_boss_ref: _set_boss_collision(normal_boss_ref, false)
	if acid_boss_ref: _set_boss_collision(acid_boss_ref, false)
	if stone_boss_ref: _set_boss_collision(stone_boss_ref, false)
	# Tum yanci bosslari da bul ve kapat
	get_tree().call_group("Dusman", "set_collision_layer_value", 8, false)
	get_tree().call_group("Dusman", "set_collision_mask_value", 8, false)

func _set_boss_collision(boss_node: Node, enabled: bool):
	if not is_instance_valid(boss_node): return
	
	# Ust seviye CharacterBody3D veya StaticBody3D ise 
	if boss_node is CollisionObject3D:
		boss_node.set_collision_layer_value(8, enabled) # Boss Layer: 8
		boss_node.set_collision_mask_value(8, enabled)
	
	# Cocuklar arasindaki CollisionShape ve Area'lari bul
	for child in boss_node.get_children(true):
		if child is CollisionShape3D:
			child.disabled = !enabled
		elif child is CollisionObject3D:
			child.set_collision_layer_value(8, enabled)
			child.set_collision_mask_value(8, enabled)
		elif child is Area3D:
			child.monitoring = enabled
			child.monitorable = enabled
		
		# Rekursif devam et (alt node'lar icin)
		if child.get_child_count() > 0:
			_set_boss_collision(child, enabled)
