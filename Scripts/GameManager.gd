extends Node

# --- SİNYALLER ---
signal envanter_guncellendi 
signal blok_yerlestirildi
signal satir_patladi        
signal boss_oldu            
signal saglik_guncellendi(bar, hp) 
signal altin_guncellendi(miktar)   
signal mermi_degisti(yeni_sayi)
signal shotgun_mermi_degisti(yeni_sayi)
signal mide_guncellendi(doluluk, kapasite)
signal seviye_tamamlandi # Seviye bitişini (puan+boss) her yere duyurur
signal puan_degisti(yeni_puan)
signal boss_hp_degisti(tip, yeni_hp)

# --- OYUNCU SAĞLIK VERİLERİ ---
var oyuncu_max_bar: int = 4
var oyuncu_kalan_bar: int = 4
var oyuncu_suanki_hp: int = 10

# --- OYUN İLERLEMESİ ---
var suanki_seviye: int = 1 
var kayitli_seviye: int = 1
var toplam_altin: int = 10 
var intro_tamamlandi: bool = false
var tutorial_tamamlandi: bool = false
var completed_tutorials: Array[String] = [] # "base", "market", "campfire", "pyro"
var uyku_sahnesi_giris_sayisi: int = 0
var total_fingers_cut: int = 0
var cuts_in_current_layer: int = 0

# --- SEVİYE BİTİRME KONTROLÜ ---
var suanki_puan: int = 0
var hedef_puan: int = 0
var grid_tamamlandi: bool = false
var boss_oldu_durumu: bool = false
var seviye_bitti_islem_yapildi: bool = false

# --- ENVANTER ---
var envanter: Array[ItemData] = []
var max_totem_sayisi = 5 

# --- BUFFLAR ---
var puan_carpani: float = 1.0
var revive_aktif: bool = false
var zar_atlama_hakki: int = 0 
var mouse_hassasiyeti: float = 0.05
var zar_yok_sayma: bool = false
var pyro_yavaslatma: bool = false

# --- TV VIDEO PROGRESSION ---
var current_video_index: int = 0      # 0: anubis, 1: ktm2, 2: ktm3
var last_video_watched_layer: int = -1 # En son izlenen VİDEONUN katmanı (ilk izleme)
var is_new_video_available: bool = true # Ünlem işaretini kontrol eder
var yarasa_bonusu: bool = false
var mantar_modu: bool = false
var tek_zar_modu: bool = false
var fener_aktif: bool = false
var kanli_civi_aktif: bool = false
var kahin_gozu_aktif: bool = false   # Pasif: boss'un sıradaki hamlesi gösterilir
var curuk_temel_aktif: bool = false  # Tek kullanımlık: grid'i temizle (wand)
var kanli_indirim_aktif: bool = false # Pasif: market %50 indir, -3 HP giriş bedeli
var sonraki_boss_saldirisi: String = "" # Kahin Gözü tarafından doldurulur

# --- 🫁 MİDE SİSTEMİ ---
var mide_kapasite: int = 1   # (Eski logic - UI için tutulabilir veya get_stomach_capacity() ile değiştirilir)
var mide_doluluk: int = 0    # Şu anki doluluk (Görsel)
var gore_intensity: float = 0.0  # Kalıcı gore birikimi (0.0-1.0)
var limbs_eaten_this_round: int = 0  # Bu tur kaç uzuv yendi

# --- 🔥 PYRO MODU & SİLAH SİSTEMİ DEĞİŞKENLERİ ---
var pyro_aktif: bool = false
var mermi_sayisi: int = 10
var max_mermi: int = 40
var mermi_parcasi_sayisi: int = 0  # 3 parça = 1 mermi
var shotgun_mermi_count: int = 0
var max_shotgun_mermi: int = 10
var silah_cekildi: bool = false 
var yeme_aktif_mi: bool = false  # Oyuncu uzuv yerken true — pyro_filtresi gizlenir
var pyro_dogacak_dusman: int = 0 # Pyro modunda doğması beklenen düşman sayısı

# --- 👁️ GLITCH PARRY SİSTEMİ ---
var glitch_face_aktif: bool = false
var is_parry_window_open: bool = false
var ghost_move_active: bool = false
var ghost_canvas: CanvasLayer = null

# --- 👹 BOSS KAÇTI SİSTEMİ ---
var boss_kacti: bool = false
var kacan_bosslar: Array = [] # [{ "tip": int, "hp": int }, ...] dizisi
var boss_kalici_hp: Dictionary = { # { "asit": 2, "golem": 2, "zar": 2 }
	"asit": 2,
	"golem": 2,
	"zar": 2
}

func _ready():
	randomize()
	print("GameManager Başlatıldı.")
	# Oyun açıldığında pencereyi ön plana getir (Focus fix)
	DisplayServer.window_move_to_foreground()
	
	_setup_gamepad()
	_init_audio()
	# Sadece intro durumunu yükle — oyun state'i her açılışta sıfır başlar
	_intro_durumu_yukle()
	boss_oldu.connect(_on_boss_oldu_gm)

func level_baslat(hp: int):
	"""Bölüm her başladığında veya resetlendiğinde çağrılır."""
	suanki_puan = 0
	hedef_puan = hp
	grid_tamamlandi = false
	boss_oldu_durumu = false
	seviye_bitti_islem_yapildi = false
	cuts_in_current_layer = 0 # Her katman başında sıfırla
	
	# TV Video Kontrolü (Sadece Sphenks katmanlarında)
	if not pyro_aktif:
		_video_kilit_kontrolu()
		
	print("📊 Level Başlatıldı: Hedef Puan = %d" % hedef_puan)

func _video_kilit_kontrolu():
	# Eğer video izlenmişse ve üzerinden 2 katman geçmişse yeni video ver
	if last_video_watched_layer != -1:
		var katman_farki = suanki_seviye - last_video_watched_layer
		if katman_farki >= 2 and current_video_index < 2:
			if not is_new_video_available:
				is_new_video_available = true
				print("📺 TV: Yeni video (ktm%d) hazir!" % (current_video_index + 2))

func puan_ekle(miktar: int):
	"""GridYoneticisi'nden gelen puanları toplar ve hedefi kontrol eder."""
	suanki_puan += miktar
	
	if not grid_tamamlandi and suanki_puan >= hedef_puan:
		grid_tamamlandi = true
		print("✅ HEDEF PUAN AŞILDI! (%d/%d)" % [suanki_puan, hedef_puan])
		_kapi_kontrol()
	
	# --- YENİ: 1.5 KAT PUAN KONTROLÜ ---
	if suanki_puan >= (hedef_puan * 1.5) and not seviye_bitti_islem_yapildi:
		print("🔥 1.5 KAT PUAN LIMITI ASILDI! Otomatik bitiş tetikleniyor.")
		_seviye_bitis_kontrolu(true) # Force end
	
	emit_signal("puan_degisti", suanki_puan)

func boss_oldu_tetiklendi():
	"""Boss öldüğünde çağrılır (AcidBoss, StoneBoss, BossCanavar)."""
	if boss_oldu_durumu: return # Zaten öldü olarak işaretlenmiş
	
	boss_oldu_durumu = true
	print("☠️ Boss Ölümü GameManager'a Bildirildi.")
	_seviye_bitis_kontrolu()

func _kapi_kontrol():
	"""Kapı açılma ve carry-over kurallarını uygular."""
	# TUTORIAL ÖNCELİĞİ: Eğer Katman 1'de isek ve tutorial henüz bitmemişse beklet
	if suanki_seviye == 1:
		if TutorialManager and TutorialManager.tutorial_aktif:
			print("🎓 GameManager: Tutorial aktif, kapı kontrolü bekletiliyor.")
			return
		if not is_tutorial_segment_completed("base"):
			print("🎓 GameManager: Tutorial 'base' tamamlanmadığı için kapı kontrolü bekletiliyor.")
			return

	if grid_tamamlandi:
		# Puan doldu
		var bosslar = get_tree().get_nodes_in_group("Dusman")
		var yasayan_boss_var = false
		var toplam_hp = 0
		for b in bosslar:
			if is_instance_valid(b) and not b.get("oldu_mu"):
				yasayan_boss_var = true
				toplam_hp += b.get("boss_hp") if b.get("boss_hp") != null else 1
				
		var toplam_mermi = mermi_sayisi + shotgun_mermi_count
		var mermi_yeterli = (toplam_mermi >= toplam_hp)
		
		# EĞER MERMİ YETERLİYSE VE BOSS YAŞIYORSA, KAPIYI AÇMA! Bekle...
		if yasayan_boss_var and mermi_yeterli:
			print("🚪 GameManager: Hedef puana ulaşıldı ancak mermi yeterli ve boss hayatta (Kapı Bekletiliyor).")
			
			# UI'da "Boss'u Öldür" uyarısı göster
			var arayuz = get_tree().get_first_node_in_group("Arayuz")
			if arayuz and arayuz.has_method("bilgi_goster"):
				arayuz.bilgi_goster(DilYoneticisi.metin_al("kill_the_boss") if DilYoneticisi else "KILL THE BOSS", 4.0)
		else:
			_kapiyi_ac_gercek()
			
		_seviye_bitis_kontrolu()
	
	elif boss_oldu_durumu and not grid_tamamlandi:
		# Boss öldü ama grid bitmedi
		# Kapı açılmıyor, uyarı gösteriliyor
		_eksik_puan_uyarisi_goster()

func _seviye_bitis_kontrolu(force: bool = false):
	"""Masa sisteminin ne zaman kalkacağına karar verir."""
	if (not grid_tamamlandi and not force) or seviye_bitti_islem_yapildi:
		return
		
	# Ghost Move sürüyorsa bitene kadar bekle
	if ghost_move_active:
		return

	# Eğer boss hayattaysa ve mermi var ise beklet (oyuncu boss'u vurabilsin)
	# ANCAK: Eğer force true ise (1.5x puan) bekleme, masayı kaldır!
	var bosslar = get_tree().get_nodes_in_group("Dusman")
	var yasayan_boss_var = false
	var toplam_hp = 0
	for b in bosslar:
		if is_instance_valid(b) and not b.get("oldu_mu"):
			yasayan_boss_var = true
			toplam_hp += b.get("boss_hp") if b.get("boss_hp") != null else 1
			
	var toplam_mermi = mermi_sayisi + shotgun_mermi_count
	var mermi_yeterli = (toplam_mermi >= toplam_hp)
	
	if yasayan_boss_var and mermi_yeterli and not force:
		print("🔫 GameManager: Puan tamam ama boss hayatta ve mermi yeterli. Bekletiliyor...")
		return
		
	# KRİTİK: Masa kalkıyor!
	seviye_bitti_islem_yapildi = true
	
	if yasayan_boss_var:
		if not mermi_yeterli:
			# Mermi yetersizse boss carry-over olur ve kaybolur
			print("🏃 Mermi yetersiz! Boss kaçıyor.")
			_bosslari_carry_over_yap()
			# Boss'u sahnede gizle (veya animasyonunu oynat)
			for b in bosslar:
				if is_instance_valid(b) and not b.get("oldu_mu"):
					if b.has_method("kacis_baslat"): b.kacis_baslat()
					else: b.visible = false
			
			# Kapıyı aç (mermi yoksa boss kaçtı, geçiş serbest)
			_kapiyi_ac_gercek()
		else:
			# Mermi var ve boss yaşıyor (özellikle force true iken buraya gireriz)
			print("🔫 GameManager: Masa kalktı, oyuncunun mermisi var. BOSS FIGHT BAŞLIYOR!")
			# UI'da "Boss'u Öldür" uyarısı göster (Garantile)
			var arayuz = get_tree().get_first_node_in_group("Arayuz")
			if arayuz and arayuz.has_method("bilgi_goster"):
				arayuz.bilgi_goster(DilYoneticisi.metin_al("kill_the_boss") if DilYoneticisi else "KILL THE BOSS", 5.0)
	else:
		# Boss zaten öldüyse kapıyı aç
		_kapiyi_ac_gercek()

	print("🏁 SEVİYE TAMAMLANDI: Masa sistemi kaldırılıyor. (Force: %s)" % str(force))
	emit_signal("seviye_tamamlandi")

func _bosslari_carry_over_yap():
	"""Hayatta kalan tüm boss'ları kacan_bosslar listesine ekler."""
	var dusmanlar = get_tree().get_nodes_in_group("Dusman")
	var carry_sayisi = 0
	
	for d in dusmanlar:
		if is_instance_valid(d) and not d.get("oldu_mu"):
			# Boss tipini tespiti
			var tip = 0 # Default zar
			var boss_adi = d.name.to_lower()
			if "acid" in boss_adi: tip = 1
			elif "stone" in boss_adi or "golem" in boss_adi: tip = 2
			
			var hp = d.get("boss_hp") if d.get("boss_hp") != null else 2
			boss_kacti_ekle(tip, hp)
			carry_sayisi += 1
			
	if carry_sayisi > 0:
		print("🚀 %d boss carry-over'a alındı." % carry_sayisi)

func _kapiyi_ac_gercek():
	"""Sahnede KapiSistemi'ni bulup kapıyı açar."""
	# TUTORIAL CHECK:
	if suanki_seviye == 1 and not is_tutorial_segment_completed("base"):
		print("🎓 GameManager: Tutorial bitmediği için kapı açma isteği REDDEDİLDİ.")
		return
		
	var kapi = get_tree().current_scene.find_child("KapiSistemi", true, false)
	if kapi and kapi.has_method("kapiyi_ac"):
		if "kilitli_mi" in kapi:
			kapi.kilitli_mi = false
		kapi.kapiyi_ac()
		print("🚪 Bölüm Sonu Kapısı GameManager tarafından açıldı.")

func _eksik_puan_uyarisi_goster():
	"""Oyuncuya puan toplamas gerektiğini hatırlatır."""
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("bilgi_goster"):
		var mesaj = DilYoneticisi.metin_al("eksik_puan_uyarisi")
		arayuz.bilgi_goster(mesaj, 3.0)

func _on_boss_oldu_gm():
	boss_kacti = false
	kacan_bosslar.clear()
	if ghost_move_active:
		end_ghost_move()

func boss_kacti_ekle(tip: int, hp: int):
	"""Kaçan bossları listeye ekler (max 2 yancı desteklenir)."""
	if kacan_bosslar.size() >= 2:
		# En eski kaçanı çıkarıp yeniye yer açabiliriz veya doluluğu koruruz
		# Genelde 2 yancı sınırı olduğu için limitli tutuyoruz
		return
	
	kacan_bosslar.append({"tip": tip, "hp": hp})
	boss_kacti = true
	print("👹 Kaçan boss listeye eklendi (Tip: %d, HP: %d). Toplam: %d" % [tip, hp, kacan_bosslar.size()])

func boss_hp_guncelle(tip: String, hp: int):
	"""Boss canını kalıcı olarak günceller (Katmanlar arası koruma)."""
	if boss_kalici_hp.has(tip):
		boss_kalici_hp[tip] = hp
		print("💾 Persistent HP Updated: %s -> %d" % [tip, hp])
		emit_signal("boss_hp_degisti", tip, hp)

func boss_hp_al(tip: String) -> int:
	"""Kayıtlı boss canını döner."""
	return boss_kalici_hp.get(tip, 2)

var bgm_player: AudioStreamPlayer
var suanki_muzik: int = 1

func _init_audio():
	bgm_player = AudioStreamPlayer.new()
	bgm_player.volume_db = -10.0
	bgm_player.bus = "BGM"
	add_child(bgm_player)
	
	bgm_player.finished.connect(_sonraki_muzige_gec)
	_sonraki_muzige_gec()

func _sonraki_muzige_gec():
	var muzik_yolu = "res://Assets/Audio/background_music_1.mp3"
	if suanki_muzik == 2:
		muzik_yolu = "res://Assets/Audio/background_music_2.mp3"
		suanki_muzik = 1
	else:
		suanki_muzik = 2
		
	var stream = load(muzik_yolu)
	
	# Döngüyü Kapat ki bittiğinde finished sinyali tetiklensin
	if stream and stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream and stream is AudioStreamMP3:
		stream.loop = false
		
	bgm_player.stream = stream
	bgm_player.play()


func _setup_gamepad():
	# Sol Tik (A)
	if not InputMap.has_action("sol_tik"): InputMap.add_action("sol_tik")
	var ev_a = InputEventJoypadButton.new()
	ev_a.button_index = JOY_BUTTON_A
	InputMap.action_add_event("sol_tik", ev_a)

	# Sag Tik (B)
	if not InputMap.has_action("sag_tik"): InputMap.add_action("sag_tik")
	var ev_b = InputEventJoypadButton.new()
	ev_b.button_index = JOY_BUTTON_B
	InputMap.action_add_event("sag_tik", ev_b)

	# Etkilesim (Y)
	if not InputMap.has_action("etkilesim"): InputMap.add_action("etkilesim")
	var ev_y = InputEventJoypadButton.new()
	ev_y.button_index = JOY_BUTTON_Y
	InputMap.action_add_event("etkilesim", ev_y)
	
	# Incele (X)
	if not InputMap.has_action("incele"): InputMap.add_action("incele")
	var ev_x = InputEventJoypadButton.new()
	ev_x.button_index = JOY_BUTTON_X
	InputMap.action_add_event("incele", ev_x)
	
	# Kosma (R1)
	if not InputMap.has_action("kosma"): 
		InputMap.add_action("kosma")
		var ev_shift = InputEventKey.new()
		ev_shift.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("kosma", ev_shift)
	var ev_r1 = InputEventJoypadButton.new()
	ev_r1.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event("kosma", ev_r1)
	
	# Yurume (Sol Analog - Joypad Motion)
	if not InputMap.has_action("ileri"): InputMap.add_action("ileri")
	var ev_up = InputEventJoypadMotion.new()
	ev_up.axis = JOY_AXIS_LEFT_Y
	ev_up.axis_value = -1.0
	InputMap.action_add_event("ileri", ev_up)
	
	if not InputMap.has_action("geri"): InputMap.add_action("geri")
	var ev_down = InputEventJoypadMotion.new()
	ev_down.axis = JOY_AXIS_LEFT_Y
	ev_down.axis_value = 1.0
	InputMap.action_add_event("geri", ev_down)
	
	if not InputMap.has_action("sol"): InputMap.add_action("sol")
	var ev_left = InputEventJoypadMotion.new()
	ev_left.axis = JOY_AXIS_LEFT_X
	ev_left.axis_value = -1.0
	InputMap.action_add_event("sol", ev_left)
	
	if not InputMap.has_action("sag"): InputMap.add_action("sag")
	var ev_right = InputEventJoypadMotion.new()
	ev_right.axis = JOY_AXIS_LEFT_X
	ev_right.axis_value = 1.0
	InputMap.action_add_event("sag", ev_right)
	
	# Ates Et (A)
	if not InputMap.has_action("ates_et"): InputMap.add_action("ates_et")
	var ev_ates = InputEventJoypadButton.new()
	ev_ates.button_index = JOY_BUTTON_A
	InputMap.action_add_event("ates_et", ev_ates)

	# Uzuv Ye (L1)
	if not InputMap.has_action("uzuv_ye"): InputMap.add_action("uzuv_ye")
	var ev_lb = InputEventJoypadButton.new()
	ev_lb.button_index = JOY_BUTTON_LEFT_SHOULDER
	InputMap.action_add_event("uzuv_ye", ev_lb)

	# Panel Ac (Q / Back-Select)
	if not InputMap.has_action("panel_ac"): 
		InputMap.add_action("panel_ac")
		var ev_q = InputEventKey.new()
		ev_q.physical_keycode = KEY_Q
		InputMap.action_add_event("panel_ac", ev_q)
	var ev_back = InputEventJoypadButton.new()
	ev_back.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event("panel_ac", ev_back)

	# Pause / Cancel (Start)
	if not InputMap.has_action("ui_cancel"): InputMap.add_action("ui_cancel")
	var ev_start = InputEventJoypadButton.new()
	ev_start.button_index = JOY_BUTTON_START
	InputMap.action_add_event("ui_cancel", ev_start)

	# --- KAMERA KONTROLU (Saga Analog) ---
	if not InputMap.has_action("kamera_yukari"): InputMap.add_action("kamera_yukari")
	var ev_cam_up = InputEventJoypadMotion.new()
	ev_cam_up.axis = JOY_AXIS_RIGHT_Y
	ev_cam_up.axis_value = -1.0
	InputMap.action_add_event("kamera_yukari", ev_cam_up)
	
	if not InputMap.has_action("kamera_asagi"): InputMap.add_action("kamera_asagi")
	var ev_cam_down = InputEventJoypadMotion.new()
	ev_cam_down.axis = JOY_AXIS_RIGHT_Y
	ev_cam_down.axis_value = 1.0
	InputMap.action_add_event("kamera_asagi", ev_cam_down)
	
	if not InputMap.has_action("kamera_sol"): InputMap.add_action("kamera_sol")
	var ev_cam_left = InputEventJoypadMotion.new()
	ev_cam_left.axis = JOY_AXIS_RIGHT_X
	ev_cam_left.axis_value = -1.0
	InputMap.action_add_event("kamera_sol", ev_cam_left)
	
	if not InputMap.has_action("kamera_sag"): InputMap.add_action("kamera_sag")
	var ev_cam_right = InputEventJoypadMotion.new()
	ev_cam_right.axis = JOY_AXIS_RIGHT_X
	ev_cam_right.axis_value = 1.0
	InputMap.action_add_event("kamera_sag", ev_cam_right)
	
	# --- MASA DONDURME (LT / RT) ---
	if not InputMap.has_action("masa_don_sol"): InputMap.add_action("masa_don_sol")
	# Klavye (Q)
	var ev_masa_q = InputEventKey.new()
	ev_masa_q.physical_keycode = KEY_A
	InputMap.action_add_event("masa_don_sol", ev_masa_q)
	# Gamepad (LT)
	var ev_lt = InputEventJoypadMotion.new()
	ev_lt.axis = JOY_AXIS_TRIGGER_LEFT
	ev_lt.axis_value = 1.0
	InputMap.action_add_event("masa_don_sol", ev_lt)
	
	if not InputMap.has_action("masa_don_sag"): InputMap.add_action("masa_don_sag")
	# Klavye (R)
	var ev_masa_e = InputEventKey.new()
	ev_masa_e.physical_keycode = KEY_D
	InputMap.action_add_event("masa_don_sag", ev_masa_e)
	# Gamepad (RT)
	var ev_rt = InputEventJoypadMotion.new()
	ev_rt.axis = JOY_AXIS_TRIGGER_RIGHT
	ev_rt.axis_value = 1.0
	InputMap.action_add_event("masa_don_sag", ev_rt)

	print("🎮 Gamepad (Xbox) kontrolleri eklendi!")

func verileri_sifirla():
	"""Tüm oyun verilerini başlangıç değerlerine sıfırlar."""
	oyuncu_kalan_bar = 4
	oyuncu_suanki_hp = 10
	suanki_seviye = 1
	toplam_altin = 10
	uyku_sahnesi_giris_sayisi = 0
	mermi_sayisi = 10
	mermi_parcasi_sayisi = 0
	pyro_aktif = false
	silah_cekildi = false
	shotgun_mermi_count = 0
	envanter.clear()
	bolum_bufflarini_sifirla()
	zar_atlama_hakki = 0
	kahin_gozu_aktif = false
	curuk_temel_aktif = false
	kanli_indirim_aktif = false
	sonraki_boss_saldirisi = ""
	boss_kacti = false
	kacan_bosslar.clear()
	
	mide_doluluk = 0
	limbs_eaten_this_round = 0
	mide_kapasite = get_stomach_capacity()
	gore_intensity = 0.0
	total_fingers_cut = 0
	cuts_in_current_layer = 0
	if GlobalHealthManager:
		GlobalHealthManager.permanent_max_hp_reduction = 0.0
	
	_arayuz_guncelle()



# --- 🫁 MİDE FONKSİYONLARI ---

func get_stomach_capacity() -> int:
	"""Seviyeye göre mide kapasitesini döndürür."""
	if suanki_seviye >= 9:
		return 2
	return 1

func reset_stomach_round():
	"""Pyro koridoruna girince yeme sayacını sıfırla."""
	limbs_eaten_this_round = 0
	print("🫁 Mide round sıfırlandı. Kapasite: %d" % get_stomach_capacity())

func uzuv_yendi():
	"""Bir uzuv yendiğinde çağrılır."""
	limbs_eaten_this_round += 1
	
	# Görsel doluluk (UI için)
	# UI doluluk barı sadece bu round'un doluluğunu göstersin
	mide_kapasite = get_stomach_capacity()
	mide_doluluk = limbs_eaten_this_round
	
	# Gore intensity (artık görselde kullanılmıyor ama logic'te kalsın)
	gore_intensity = clamp(gore_intensity + 0.12, 0.0, 0.85)
	
	print("🫁 Uzuv yendi! Tur: %d/%d" % [limbs_eaten_this_round, mide_kapasite])
	emit_signal("mide_guncellendi", mide_doluluk, mide_kapasite)

func mide_sifirla():
	"""Yeni seviyede (Pyro dışı) mideyi sıfırla."""
	mide_doluluk = 0
	mide_kapasite = get_stomach_capacity()
	emit_signal("mide_guncellendi", mide_doluluk, mide_kapasite)
func _arayuz_guncelle():
	await get_tree().process_frame 
	emit_signal("saglik_guncellendi", oyuncu_kalan_bar, oyuncu_suanki_hp)
	emit_signal("envanter_guncellendi")
	emit_signal("altin_guncellendi", toplam_altin)
	emit_signal("mermi_degisti", mermi_sayisi)
	emit_signal("shotgun_mermi_degisti", shotgun_mermi_count)

func bolum_bufflarini_sifirla():
	puan_carpani = 1.0
	revive_aktif = false
	zar_yok_sayma = false
	pyro_yavaslatma = false
	yarasa_bonusu = false
	mantar_modu = false
	zar_atlama_hakki = 0
	tek_zar_modu = false
	fener_aktif = false
	kanli_civi_aktif = false
	glitch_face_aktif = false
	# NOT: kahin_gozu_aktif, curuk_temel_aktif ve kanli_indirim_aktif bölüm sıfırlamada temizlenmez
	# çünkü bunlar sandık odası perkleridir. Yeni oyunda verileri_sifirla() siler onları.
	curuk_temel_aktif = false   # Çürük Temel tek kullanımlık — her bölümde sıfırla
	kanli_indirim_aktif = false  # Kanlı İndirim her bölümde sıfırlanır
	sonraki_boss_saldirisi = ""

func oyunu_kaydet():
	var config = ConfigFile.new()
	# Kayıt anında LevelManager'dan güncel katmanı al (varsa)
	var kayit_seviyesi = suanki_seviye
	if LevelManager and LevelManager.get("suanki_katman") != null:
		kayit_seviyesi = LevelManager.suanki_katman
	config.set_value("Oyun", "KayitliSeviye", kayit_seviyesi)
	config.set_value("Oyun", "Altin", toplam_altin)
	config.set_value("Oyuncu", "KalanBar", oyuncu_kalan_bar)
	config.set_value("Oyuncu", "SuankiHP", oyuncu_suanki_hp)
	config.set_value("Oyuncu", "MermiSayisi", mermi_sayisi)
	config.set_value("Oyuncu", "MermiParcasi", mermi_parcasi_sayisi)
	config.set_value("Oyuncu", "ShotgunMermi", shotgun_mermi_count)
	config.set_value("Oyuncu", "PyroAktif", pyro_aktif)
	config.set_value("Oyuncu", "GoreIntensity", gore_intensity)
	config.set_value("Oyuncu", "TotalFingersCut", total_fingers_cut)
	
	config.set_value("Bufflar", "PuanCarpani", puan_carpani)
	config.set_value("Bufflar", "ReviveAktif", revive_aktif)
	config.set_value("Bufflar", "FenerAktif", fener_aktif)
	config.set_value("Bufflar", "ZamanYavas", pyro_yavaslatma)
	config.set_value("Bufflar", "KanliCiviAktif", kanli_civi_aktif)
	config.set_value("Bufflar", "KahinGozuAktif", kahin_gozu_aktif)
	config.set_value("Bufflar", "KanliIndirimAktif", kanli_indirim_aktif)
	config.set_value("Bufflar", "MantarModu", mantar_modu)
	config.set_value("Bufflar", "YarasaBonusu", yarasa_bonusu)
	config.set_value("Bufflar", "TekZarModu", tek_zar_modu)
	config.set_value("Bufflar", "ZarYokSayma", zar_yok_sayma)
	config.set_value("Bufflar", "ZarAtlamaHakki", zar_atlama_hakki)
	
	# Envanterı etki_id listesi olarak kaydet (resource_path olmayan dinamik item'lar için güvenli)
	var esya_id_listesi = []
	for esya in envanter:
		if esya != null and esya.etki_id != "":
			esya_id_listesi.append(esya.etki_id)
	config.set_value("Oyun", "EnvanterIDler", esya_id_listesi)
	# Eski Envanter key'ini de temizle (uyumluluk için boş yaz)
	config.set_value("Oyun", "Envanter", [])
	config.set_value("Oyun", "IntroTamamlandi", intro_tamamlandi)
	# tutorial_tamamlandi'yı completed_tutorials'dan otomatik hesapla (tutarsızlığı önle)
	tutorial_tamamlandi = ("base" in completed_tutorials and "market" in completed_tutorials \
		and "campfire" in completed_tutorials and "pyro" in completed_tutorials)
	config.set_value("Oyun", "TutorialTamamlandi", tutorial_tamamlandi)
	config.set_value("Oyun", "CompletedTutorials", completed_tutorials)
	config.set_value("Oyun", "UykuSahnesiGirisSayisi", uyku_sahnesi_giris_sayisi)
	config.set_value("Oyun", "BossKacti", boss_kacti)
	config.set_value("Oyun", "KacanBosslar", kacan_bosslar)
	config.set_value("Oyun", "BossKaliciHP", boss_kalici_hp)
	config.save("user://savegame.cfg")
	print("💾 Oyun kaydedildi. (Seviye: %d, Envanter: %s)" % [kayit_seviyesi, str(esya_id_listesi)])

func oyunu_yukle():
	"""Kaydedilen TÜM verileri yükler."""
	var config = ConfigFile.new()
	var hata = config.load("user://savegame.cfg")
	if hata == OK:
		kayitli_seviye = config.get_value("Oyun", "KayitliSeviye", 1)
		toplam_altin = config.get_value("Oyun", "Altin", 10)
		oyuncu_kalan_bar = config.get_value("Oyuncu", "KalanBar", 4)
		oyuncu_suanki_hp = config.get_value("Oyuncu", "SuankiHP", 10)
		mermi_sayisi = config.get_value("Oyuncu", "MermiSayisi", 10)
		mermi_parcasi_sayisi = config.get_value("Oyuncu", "MermiParcasi", 0)
		shotgun_mermi_count = config.get_value("Oyuncu", "ShotgunMermi", 0)
		pyro_aktif = config.get_value("Oyuncu", "PyroAktif", false)
		gore_intensity = config.get_value("Oyuncu", "GoreIntensity", 0.0)
		total_fingers_cut = config.get_value("Oyuncu", "TotalFingersCut", 0)
		
		# GlobalHealthManager'ı senkronize et
		if GlobalHealthManager:
			GlobalHealthManager.permanent_max_hp_reduction = total_fingers_cut * 3.0
		
		puan_carpani = config.get_value("Bufflar", "PuanCarpani", 1.0)
		revive_aktif = config.get_value("Bufflar", "ReviveAktif", false)
		fener_aktif = config.get_value("Bufflar", "FenerAktif", false)
		pyro_yavaslatma = config.get_value("Bufflar", "ZamanYavas", false)
		kanli_civi_aktif = config.get_value("Bufflar", "KanliCiviAktif", false)
		kahin_gozu_aktif = config.get_value("Bufflar", "KahinGozuAktif", false)
		kanli_indirim_aktif = config.get_value("Bufflar", "KanliIndirimAktif", false)
		mantar_modu = config.get_value("Bufflar", "MantarModu", false)
		yarasa_bonusu = config.get_value("Bufflar", "YarasaBonusu", false)
		tek_zar_modu = config.get_value("Bufflar", "TekZarModu", false)
		zar_yok_sayma = config.get_value("Bufflar", "ZarYokSayma", false)
		zar_atlama_hakki = config.get_value("Bufflar", "ZarAtlamaHakki", 0)
		
		envanter.clear()
		# Yeni format: etki_id listesi
		var esya_id_listesi = config.get_value("Oyun", "EnvanterIDler", [])
		if esya_id_listesi.size() > 0:
			for eid in esya_id_listesi:
				var item = _etki_id_den_item_yukle(eid)
				if item: envanter.append(item)
		else:
			# Eski format: resource_path (gerçe yoldan yükle)
			var esya_yollari = config.get_value("Oyun", "Envanter", [])
			for yol in esya_yollari:
				if typeof(yol) == TYPE_STRING and yol.begins_with("res://") and ResourceLoader.exists(yol):
					envanter.append(load(yol))

		intro_tamamlandi = config.get_value("Oyun", "IntroTamamlandi", false)
		completed_tutorials.assign(config.get_value("Oyun", "CompletedTutorials", []))
		# tutorial_tamamlandi'yı completed_tutorials'dan otomatik hesapla (tutarsızlığı önle)
		tutorial_tamamlandi = ("base" in completed_tutorials and "market" in completed_tutorials \
			and "campfire" in completed_tutorials and "pyro" in completed_tutorials)
		# Boş veya hatalı değere karşı güvenli yükleme (tip kontrolü ile)
		var _uyku_raw = config.get_value("Oyun", "UykuSahnesiGirisSayisi", 0)
		if typeof(_uyku_raw) == TYPE_STRING:
			uyku_sahnesi_giris_sayisi = int(_uyku_raw) if _uyku_raw != "" else 0
		elif _uyku_raw != null:
			uyku_sahnesi_giris_sayisi = int(_uyku_raw)
		else:
			uyku_sahnesi_giris_sayisi = 0
		
		# suanki_seviye'yi de senkronize et ki LevelManager doğru okusun
		suanki_seviye = kayitli_seviye
		boss_kacti = config.get_value("Oyun", "BossKacti", false)
		kacan_bosslar = config.get_value("Oyun", "KacanBosslar", [])
		boss_kalici_hp = config.get_value("Oyun", "BossKaliciHP", {"asit": 2, "golem": 2, "zar": 2})

		# Corrupt save fix: HP sıfırsa tam sağlığa döndür
		if oyuncu_kalan_bar <= 0 or oyuncu_suanki_hp <= 0:
			print("⚠️ Yükleme: Corrupt HP tespit edildi, tam sağlığa sıfırlanıyor.")
			oyuncu_kalan_bar = oyuncu_max_bar
			oyuncu_suanki_hp = 10
		print("✅ oyunu_yukle: tutorial=%s, kayitli_seviye=%d, envanter=%s" % [str(tutorial_tamamlandi), kayitli_seviye, str(envanter.size())])
	else:
		kayitli_seviye = 1
		print("⚠️ oyunu_yukle: save yüklenemedi, seviye 1'e sıfırlandı.")


func _intro_durumu_yukle():
	"""Sadece intro ve tutorial tamamlandı mı bilgisini yükler."""
	var config = ConfigFile.new()
	var hata = config.load("user://savegame.cfg")
	if hata == OK:
		intro_tamamlandi = config.get_value("Oyun", "IntroTamamlandi", false)
		completed_tutorials.assign(config.get_value("Oyun", "CompletedTutorials", []))
		# tutorial_tamamlandi'yı completed_tutorials'dan otomatik hesapla (tutarsızlığı önle)
		tutorial_tamamlandi = ("base" in completed_tutorials and "market" in completed_tutorials \
			and "campfire" in completed_tutorials and "pyro" in completed_tutorials)
		print("📂 Intro/Tutorial durumu yülendi: Intro=", intro_tamamlandi, " Tutorial=", tutorial_tamamlandi, " Segments=", completed_tutorials)
	else:
		intro_tamamlandi = false
		tutorial_tamamlandi = false
		completed_tutorials.clear()
		print("📂 Save dosyası bulunamadı, intro sıfır.")

func _etki_id_den_item_yukle(etki_id: String) -> ItemData:
	"""etki_id'ye göre ilgili .tres dosyasını bulur ve yükler."""
	var yol_map = {
		"asit":        "res://Assets/Models/Items/Asit.tres",
		"kilic":       "res://Assets/Models/Items/Kılıc.tres",
		"dig":         "res://Assets/Models/Items/Dig.tres",
		"paint":       "res://Assets/Models/Items/Paint.tres",
		"mantar":      "res://Assets/Models/Items/Mantar.tres",
		"serbet":      "res://Assets/Models/Items/Mantar.tres",
		"guc":         "res://Assets/Models/Items/Guc.tres",
		"canlan":      "res://Assets/Models/Items/Revive.tres",
		"revive":      "res://Assets/Models/Items/Revive.tres",
		"fener":       "res://Assets/Models/Items/Fener.tres",
		"kumsaati":    "res://Assets/Models/Items/Time.tres",
		"magnet":      "res://Assets/Models/Items/Magnet.tres",
		"cloak":       "res://Assets/Models/Items/Cloak.tres",
		"dice":        "res://Assets/Models/Items/Dice.tres",
		"kedimamasi":  "res://Assets/Models/Items/KediMamasi.tres",
		"shotgun_mermi":"res://Assets/Models/Items/Mermi_Kutusu.tres",
		"mermi_kutusu":"res://Assets/Models/Items/Mermi_Kutusu.tres",
		"curuk_temel": "",  # Dinamik yaratılan, .tres yok — özel yarat
	}
	if etki_id == "curuk_temel":
		# Dinamik item — sandik_odasi.\_wand_item_verisi_olustur() ile aynı şekilde oluştur
		var item = ItemData.new()
		item.esya_adi = DilYoneticisi.metin_al("curuk_temel_isim") if DilYoneticisi else "Çürük Temel"
		item.etki_id = "curuk_temel"
		item.animasyon_tipi = "kirma"
		item.fiyat = 0
		return item
	var yol = yol_map.get(etki_id, "")
	if yol != "" and ResourceLoader.exists(yol):
		return load(yol)
	push_warning("_etki_id_den_item_yukle: '%s' için .tres dosyası bulunamadı!" % etki_id)
	return null

func dosyalari_tamamen_sil():
	"""Kullanıcının kayıt dosyasını siler ve değişkenleri sıfırlar."""
	if FileAccess.file_exists("user://savegame.cfg"):
		var dir = DirAccess.open("user://")
		dir.remove("savegame.cfg")
		print("🗑️ Kayıt dosyası silindi.")
	else:
		print("📂 Kayıt dosyası zaten yok.")
	
	if SaveManager:
		SaveManager.dosyalari_tamamen_sil()
	
	intro_tamamlandi = false
	tutorial_tamamlandi = false
	completed_tutorials.clear()
	verileri_sifirla()

func mermi_ekle(miktar: int) -> bool:
	if mermi_sayisi >= max_mermi: return false
	mermi_sayisi = min(mermi_sayisi + miktar, max_mermi)
	emit_signal("mermi_degisti", mermi_sayisi)
	return true

func mermiyi_kullan():
	if mermi_sayisi > 0:
		mermi_sayisi -= 1
		emit_signal("mermi_degisti", mermi_sayisi)
		if mermi_sayisi == 0: _seviye_bitis_kontrolu()
		return true
	return false

func shotgun_mermi_ekle(miktar: int) -> bool:
	if shotgun_mermi_count >= max_shotgun_mermi: return false
	shotgun_mermi_count = min(shotgun_mermi_count + miktar, max_shotgun_mermi)
	emit_signal("shotgun_mermi_degisti", shotgun_mermi_count)
	return true

func shotgun_mermiyi_kullan() -> bool:
	if shotgun_mermi_count > 0:
		shotgun_mermi_count -= 1
		emit_signal("shotgun_mermi_degisti", shotgun_mermi_count)
		if shotgun_mermi_count == 0: _seviye_bitis_kontrolu()
		return true
	return false

func mermi_parcasi_ekle(miktar: int = 1):
	"""Mermi parçası ekler. Her 3 parçada 1 mermi oluşur."""
	mermi_parcasi_sayisi += miktar
	print("🔩 Mermi parçası toplandı! Toplam: %d/3" % mermi_parcasi_sayisi)
	
	# UI'ı hemen güncelle (parça sayısı gösterilsin)
	emit_signal("mermi_degisti", mermi_sayisi)
	
	while mermi_parcasi_sayisi >= 3:
		mermi_parcasi_sayisi -= 3
		mermi_ekle(1)
		print("🎯 3 parça birleşti → +1 Mermi! Toplam mermi: %d" % mermi_sayisi)
		
		# Arayüze bilgi göster
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz and arayuz.has_method("bilgi_goster"):
			arayuz.bilgi_goster("🔩 +1 Mermi!", 2.0)

# ==========================================
# 🌌 GHOST MOVE PARRY MANTIĞI 🌌
# ==========================================

func activate_ghost_move():
	is_parry_window_open = false
	ghost_move_active = true
	
	if LevelManager:
		LevelManager.is_boss_acting = false # PARRY: unlock turn and show cursor
	
	print("🌌 REALITY DENIED! Ghost Move Activated (5s B&W Blur).")
	
	# Create Shader UI Layer
	ghost_canvas = CanvasLayer.new()
	ghost_canvas.layer = 100 
	
	# B&W Matrix Screen Shader
	var cr = ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	var shader = load("res://Materials_Shaders/ghost_shader.gdshader")
	if shader: mat.shader = shader
	cr.material = mat
	ghost_canvas.add_child(cr)
	
	# Scary Timer Label
	var lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 120)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var font = load("res://Assets/Fonts/PressStart2P-Regular.ttf")
	if font: lbl.add_theme_font_override("font", font)
	
	lbl.text = "5"
	lbl.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	lbl.position = Vector2(100, (get_viewport().get_visible_rect().size.y / 2) - 100)
	ghost_canvas.add_child(lbl)
	
	get_tree().current_scene.add_child(ghost_canvas)
	
	# Disable Enemy processing and RETURN CAMERA TO PLAYER
	get_tree().call_group("Dusman", "_kamerayi_oyuncuya_ver")
	get_tree().call_group("Dusman", "set_process_mode", Node.PROCESS_MODE_DISABLED)
	
	var sayac = 5
	for i in range(5):
		# --- TUTORIAL DONDURMASI (HAYALET HAMLE EĞİTİMİ) ---
		while TutorialManager and TutorialManager.tutorial_aktif and (TutorialManager.suanki_adim == 12 or TutorialManager.suanki_adim == 13):
			await get_tree().process_frame
			if not ghost_move_active: return
			
		await get_tree().create_timer(1.0, false).timeout
		if not ghost_move_active: return # Killed early due to block placement
		
		sayac -= 1
		if is_instance_valid(lbl): lbl.text = str(sayac)
		
	# Time is up
	if ghost_move_active:
		end_ghost_move()
		var boss = get_tree().get_first_node_in_group("Dusman")
		if boss and boss.has_method("gercek_saldiri_basa_don"):
			boss.gercek_saldiri_basa_don()
func grid_yonetici_kontrol():
	pass

func end_ghost_move():
	if not ghost_move_active: return
	ghost_move_active = false
	
	if LevelManager:
		var boss = get_tree().get_first_node_in_group("Dusman")
		var boss_dead = false
		if not is_instance_valid(boss): boss_dead = true
		elif boss.get("oldu_mu") != null and boss.oldu_mu == true: boss_dead = true
		
		# Sadece boss yasiyorsa sirayi geri ver
		if not boss_dead:
			LevelManager.is_boss_acting = true # Re-lock turn and hide cursor
	
	if is_instance_valid(ghost_canvas):
		ghost_canvas.queue_free()
		
	get_tree().call_group("Dusman", "set_process_mode", Node.PROCESS_MODE_INHERIT)
	print("🌍 REALITY RESTORED.")
	
	# Ghost Move bittiğinde eğer puan hedefi aşılmışsa kapıyı aç
	if suanki_puan >= hedef_puan:
		print("🏁 Ghost Move bitti ve puan yeterli. Seviye tamamlanıyor...")
		_kapi_kontrol()

func saglik_guncelle(bar: int, hp: int):
	oyuncu_kalan_bar = bar; oyuncu_suanki_hp = hp;
	emit_signal("saglik_guncellendi", bar, hp)

func altin_harca(miktar: int) -> bool:
	if toplam_altin >= miktar: 
		toplam_altin -= miktar
		emit_signal("altin_guncellendi", toplam_altin)
		return true
	return false

func pelerin_korumasi_var_mi() -> bool:
	return zar_atlama_hakki > 0

func pelerin_aktif_et():
	"""Pelerin kullanılınca 3 tur zar koruma hakkı verir."""
	zar_atlama_hakki = 3
	print("🛡️ Pelerin Aktif! zar_atlama_hakki = ", zar_atlama_hakki)

func pelerin_hak_dus():
	if zar_atlama_hakki > 0:
		zar_atlama_hakki -= 1

# --- TUTORIAL YARDIMCILARI ---

func is_tutorial_segment_completed(segment_name: String) -> bool:
	return segment_name in completed_tutorials

func complete_tutorial_segment(segment_name: String):
	if not segment_name in completed_tutorials:
		completed_tutorials.append(segment_name)
		print("🎓 %s tutorial segmenti tamamlandı." % segment_name)
		
		# TUTORIAL: Katman 1 (Base) bitmişse, puandan bağımsız olarak grid_tamamlandi sayıp kapıyı kontrol et.
		if segment_name == "base":
			grid_tamamlandi = true # Puandan bağımsız geçiş izni
			print("🎓 Tutorial: Base bitti. Puan bağımsız olarak kapı kontrolü tetikleniyor.")
			
			# Tutorial bittiğine göre artık kapı kontrolü çalışabilir
			_kapi_kontrol()
			
		oyunu_kaydet()

# --- 🫁 MİDE FONKSİYONLARI ---
