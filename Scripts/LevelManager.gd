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
			if is_instance_valid(oyuncu_ref) and oyuncu_ref.has_method("disable_controls"):
				oyuncu_ref.disable_controls()
		else:
			# Boss isi bittiginde veya zorla acildiginda (Level bitis vb.) mouse modunu geri getir
			if is_instance_valid(oyuncu_ref):
				if oyuncu_ref.has_method("enable_controls"):
					oyuncu_ref.enable_controls()
				
				if "mouse_serbest_modu" in oyuncu_ref and oyuncu_ref.mouse_serbest_modu:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
var boss_konumlari: Dictionary = {} # Boss Ismi -> Vector3 (Orijinal Sahne Konumlari)
var yanci_markerlari: Array[Node3D] = [] # Sahnedeki Yancilar node'u icindeki Marker3D'ler
var bitis_yoneticisi: Node = null

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
	
	# 1. Önce markerları kaydet (Boss sistemi bunlara ihtiyaç duyar)
	_yanci_markerlarini_guncelle()
	
	# 2. Sonra boss referanslarını ve pozisyonlarını ayarla
	_boss_sistemini_ayarla()
	
	# 3. GameManager'da bölüm verilerini sıfırla/başlat
	var d_veri = bolum_verilerini_getir()
	if GameManager and d_veri.has("hedef_puan"):
		GameManager.level_baslat(d_veri["hedef_puan"])
	
	# Katman Bitiş Yöneticisini kur
	_bitis_yoneticisini_kur()
	
	# Bölüm yüklendiğinde oyuncuyu spawn noktasına ışınla
	if suanki_katman > 1 and oyuncu_ref:
		# Oyuncu grid üstüne oturmuş veya move_and_slide'da sıkışmış olabilir. 
		# Bu yüzden global_position atamasını bir frame sonra yaparız.
		call_deferred("_oyuncuyu_baslangica_isinla")

func _yanci_markerlarini_guncelle():
	yanci_markerlari.clear()
	if is_instance_valid(oyun_odasi_ref):
		var yanci_node = oyun_odasi_ref.find_child("Yancilar", true, false)
		if yanci_node:
			var markers = []
			for child in yanci_node.get_children():
				if child is Node3D: # Marker3D veya Node3D farketmeksizin al
					markers.append(child)
			
			# İsim sırasına göre diz (yanci1, yanci2...)
			markers.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
			for m in markers:
				yanci_markerlari.append(m)
			print("📍 LevelManager'a ", yanci_markerlari.size(), " adet sıralı yanci noktası kaydedildi.")
	
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
		
		# Bölüm geçişinde can ve ilerleme durumunu kaydet
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
	boss_konumlari.clear()
	if normal_boss_ref: boss_konumlari["NormalBoss"] = normal_boss_ref.global_position
	if acid_boss_ref: boss_konumlari["AcidBoss"] = acid_boss_ref.global_position
	if stone_boss_ref: boss_konumlari["StoneBoss"] = stone_boss_ref.global_position
	
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
	
	if is_instance_valid(aktif_ana_boss):
		aktif_ana_boss.visible = true
		aktif_ana_boss.add_to_group("Dusman")
		_set_boss_collision(aktif_ana_boss, true) # Aktif boss collision aç
		print("🎯 Aktif Ana Boss Belirlendi: ", aktif_ana_boss.name)
		if aktif_ana_boss.has_method("boss_durumu_sifirla"):
			aktif_ana_boss.boss_durumu_sifirla()
		# Boss ana pozisyonunda - SAHNEDEKİ KONUM KULLANILIYOR
		# aktif_boss.global_position = start_pos + Vector3(0, -0.5, -4.5) 
		
		# --- 👹 BOSS KAÇTI: TÜM YANCILARI SPAWN ET ---
		if GameManager and GameManager.boss_kacti:
			for i in range(GameManager.kacan_bosslar.size()):
				var data = GameManager.kacan_bosslar[i]
				var spawn_pos = Vector3.ZERO
				if i < yanci_markerlari.size() and is_instance_valid(yanci_markerlari[i]):
					spawn_pos = yanci_markerlari[i].global_position
				
				_yanci_spawn_et(data["tip"], data["hp"], spawn_pos)
			
			GameManager.boss_kacti = false
			GameManager.kacan_bosslar.clear()
		
		# Tüm bossları (ana + yancılar) hizala
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

func _yanci_spawn_et(tip: int, hp: int, pos: Vector3 = Vector3.ZERO):
	var yanci_prefab: Node3D = null
	if tip == 1: yanci_prefab = acid_boss_ref
	elif tip == 2: yanci_prefab = stone_boss_ref
	else: yanci_prefab = normal_boss_ref
	
	if yanci_prefab:
		var twin = yanci_prefab.duplicate()
		yanci_prefab.get_parent().add_child(twin)
		twin.name = yanci_prefab.name + "_Minion_" + str(randi() % 1000)
		
		# Spawn edildiği anda pozisyonu ayarla (USER REQUEST: Marker3D'de spawn olsun)
		if pos != Vector3.ZERO:
			twin.global_position = pos
		
		twin.visible = true
		twin.add_to_group("Dusman")
		if "oldu_mu" in twin: twin.oldu_mu = false
		_set_boss_collision(twin, true)
		
		if hp > 0:
			twin.boss_hp = hp
			get_tree().create_timer(0.2).timeout.connect(_reset_twin_state.bind(twin))

func _bosslari_yeniden_konumlandir():
	var dusmanlar = get_tree().get_nodes_in_group("Dusman")
	var yasayanlar = []
	for d in dusmanlar:
		if is_instance_valid(d) and not d.get("oldu_mu"):
			yasayanlar.append(d)
	
	# Sıralama: Aktif ana boss hayattaysa onu merkez (index 0) yap
	var sirali_yasayanlar = []
	if is_instance_valid(aktif_ana_boss) and not aktif_ana_boss.get("oldu_mu"):
		sirali_yasayanlar.append(aktif_ana_boss)
	
	for d in yasayanlar:
		if d != aktif_ana_boss:
			sirali_yasayanlar.append(d)
	
	for i in range(sirali_yasayanlar.size()):
		var b = sirali_yasayanlar[i]
		
		if i == 0: # ANA BOSS (MERKEZ)
			# Sahnedeki pozisyonunu ("tek başına olduklarındaki konumları doğru") koruyor.
			# Eğer ana boss değil de bir yancıysa (ana boss ölmüşse), KENDİ tipine ait orijinal sahne pozisyonuna geç
			var b_adi = b.name.to_lower()
			var target_ana_pos = b.global_position
			
			if "normalboss" in b_adi and boss_konumlari.has("NormalBoss"):
				target_ana_pos = boss_konumlari["NormalBoss"]
			elif "acidboss" in b_adi and boss_konumlari.has("AcidBoss"):
				target_ana_pos = boss_konumlari["AcidBoss"]
			elif "stoneboss" in b_adi and boss_konumlari.has("StoneBoss"):
				target_ana_pos = boss_konumlari["StoneBoss"]
			
			b.global_position = target_ana_pos
			b.scale = Vector3(1.5, 1.5, 1.5) # Ana boss boyutu
			
			if b.has_method("update_base_position"):
				b.update_base_position(b.global_position)
			continue
		
		# YANCI (Minion)
		# USER REQUEST: yanci1, yanci2 Marker3D'lerine git
		var marker_idx = i - 1
		var target_pos = b.global_position
		
		if marker_idx < yanci_markerlari.size() and is_instance_valid(yanci_markerlari[marker_idx]):
			target_pos = yanci_markerlari[marker_idx].global_position
		else:
			# Eğer marker yetmezse (2'den fazla yancı) son markerın yanına yerleştir
			var offset_dir = Vector3(1.5, 0, 0) if i % 2 == 0 else Vector3(-1.5, 0, 0)
			target_pos = start_pos + Vector3(2.3, -0.5, -4.5) + (offset_dir * floor(i / 2.0))
		
		b.global_position = target_pos
		
		# --- 📍 NORMALBOSS SCALE FIX ---
		var scale_val = 1.2
		if "normalboss" in b.name.to_lower():
			scale_val *= 1.4 # NormalBoss yancı iken x1.4 daha büyük olsun
		b.scale = Vector3(scale_val, scale_val, scale_val)
		
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
		print("⚠️ Boss saldırısı zaten devrede, kopya çağrı engellendi. Kilit açılıyor...")
		# Eğer kilitliysek ama saldırı başlatılamıyorsa oyuncuyu kurtar
		await get_tree().create_timer(1.0).timeout
		_on_boss_isi_bitti()
		return
		
	saldiri_devrede = true
	is_boss_acting = true # Hemen kilitle
	get_tree().call_group("Blok", "iptal_et")

	# Canlı bossları bul ve sırala (Önce ana boss, sonra yancılar)
	var dusmanlar = get_tree().get_nodes_in_group("Dusman")
	var yasayanlar = []
	
	# Ana boss hayattaysa başa ekle
	if is_instance_valid(aktif_ana_boss) and not aktif_ana_boss.get("oldu_mu"):
		yasayanlar.append(aktif_ana_boss)
	
	for d in dusmanlar:
		if is_instance_valid(d) and not d.get("oldu_mu") and d != aktif_ana_boss:
			yasayanlar.append(d)

	if yasayanlar.size() > 0:
		var lider_boss = yasayanlar[0]
		print("🔒 Boss saldırı sırası: ", lider_boss.name, " (Lider). Diğerleri bekliyor.")
		
		if is_instance_valid(lider_boss) and not lider_boss.get("oldu_mu"):
			print("⚔️ Lider boss saldırıyor...")
			lider_boss.saldiri_baslat()
			
			# Liderin saldırısını bekle
			if lider_boss.has_signal("saldiri_tamamlandi"):
				await lider_boss.saldiri_tamamlandi
			else:
				await get_tree().create_timer(2.0).timeout
		
		_on_boss_isi_bitti()
	else:
		print("❓ Saldiracak boss bulunamadi, kilit aciliyor.")
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
		boss_node.call_deferred("set_collision_layer_value", 8, enabled) # Boss Layer: 8
		boss_node.call_deferred("set_collision_mask_value", 8, enabled)
	
	# Cocuklar arasindaki CollisionShape ve Area'lari bul
	for child in boss_node.get_children(true):
		if child is CollisionShape3D:
			child.set_deferred("disabled", !enabled)
		elif child is CollisionObject3D:
			child.call_deferred("set_collision_layer_value", 8, enabled)
			child.call_deferred("set_collision_mask_value", 8, enabled)
		elif child is Area3D:
			child.set_deferred("monitoring", enabled)
			child.set_deferred("monitorable", enabled)
		
		# Rekursif devam et (alt node'lar icin)
		if child.get_child_count() > 0:
			_set_boss_collision(child, enabled)

func _reset_twin_state(twin: Node):
	if is_instance_valid(twin):
		if twin.has_method("boss_durumu_sifirla"):
			twin.boss_durumu_sifirla()

func _bitis_yoneticisini_kur():
	if is_instance_valid(bitis_yoneticisi):
		bitis_yoneticisi.queue_free()
	
	var script = load("res://Scripts/katman_bitis_yoneticisi.gd")
	if script:
		bitis_yoneticisi = Node.new()
		bitis_yoneticisi.set_script(script)
		bitis_yoneticisi.name = "KatmanBitisYoneticisi"
		add_child(bitis_yoneticisi)
		print("🛠️ KatmanBitisYoneticisi sisteme eklendi.")
