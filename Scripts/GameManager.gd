extends Node

# --- SİNYALLER ---
signal envanter_guncellendi 
signal blok_yerlestirildi
signal satir_patladi        
signal boss_oldu            
signal saglik_guncellendi(bar, hp) 
signal altin_guncellendi(miktar)   
signal mermi_degisti(yeni_sayi)
signal mide_guncellendi(doluluk, kapasite)

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
var uyku_sahnesi_giris_sayisi: int = 0

# --- ENVANTER ---
var envanter: Array[ItemData] = []
var max_totem_sayisi = 5 

# --- BUFFLAR ---
var puan_carpani: float = 1.0
var revive_aktif: bool = false
var zar_atlama_hakki: int = 0 
var zar_yok_sayma: bool = false
var pyro_yavaslatma: bool = false
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
var silah_cekildi: bool = false 
var yeme_aktif_mi: bool = false  # Oyuncu uzuv yerken true — pyro_filtresi gizlenir

# --- 👁️ GLITCH PARRY SİSTEMİ ---
var glitch_face_aktif: bool = false
var is_parry_window_open: bool = false
var ghost_move_active: bool = false
var ghost_canvas: CanvasLayer = null

func _ready():
	print("GameManager Başlatıldı.")
	_setup_gamepad()
	_init_audio()
	# Sadece intro durumunu yükle — oyun state'i her açılışta sıfır başlar
	_intro_durumu_yukle()

var bgm_player: AudioStreamPlayer
var suanki_muzik: int = 1

func _init_audio():
	bgm_player = AudioStreamPlayer.new()
	bgm_player.volume_db = -10.0
	bgm_player.bus = "Master"
	add_child(bgm_player)
	
	bgm_player.finished.connect(_sonraki_muzige_gec)
	_sonraki_muzige_gec()

func _sonraki_muzige_gec():
	var muzik_yolu = "res://Sesler/background_music_1.mp3"
	if suanki_muzik == 2:
		muzik_yolu = "res://Sesler/background_music_2.mp3"
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
	kayitli_seviye = 1
	toplam_altin = 10
	uyku_sahnesi_giris_sayisi = 0
	mermi_sayisi = 10
	pyro_aktif = false
	silah_cekildi = false
	envanter.clear()
	bolum_bufflarini_sifirla()
	zar_atlama_hakki = 0
	kahin_gozu_aktif = false
	curuk_temel_aktif = false
	kanli_indirim_aktif = false
	sonraki_boss_saldirisi = ""
	
	mide_doluluk = 0
	limbs_eaten_this_round = 0
	mide_kapasite = get_stomach_capacity()
	gore_intensity = 0.0
	
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
	config.set_value("Oyun", "KayitliSeviye", suanki_seviye)
	config.set_value("Oyun", "Altin", toplam_altin)
	config.set_value("Oyuncu", "KalanBar", oyuncu_kalan_bar)
	config.set_value("Oyuncu", "SuankiHP", oyuncu_suanki_hp)
	config.set_value("Oyuncu", "MermiSayisi", mermi_sayisi)
	config.set_value("Oyuncu", "PyroAktif", pyro_aktif)
	
	config.set_value("Bufflar", "PuanCarpani", puan_carpani)
	config.set_value("Bufflar", "ReviveAktif", revive_aktif)
	config.set_value("Bufflar", "FenerAktif", fener_aktif)
	config.set_value("Bufflar", "ZamanYavas", pyro_yavaslatma)
	config.set_value("Bufflar", "KanliCiviAktif", kanli_civi_aktif)
	config.set_value("Bufflar", "GlitchFaceAktif", glitch_face_aktif)
	config.set_value("Bufflar", "KahinGozuAktif", kahin_gozu_aktif)
	
	var esya_yollari = []
	for esya in envanter:
		if esya != null: esya_yollari.append(esya.resource_path)
	config.set_value("Oyun", "Envanter", esya_yollari)
	config.set_value("Oyun", "IntroTamamlandi", intro_tamamlandi)
	config.set_value("Oyun", "TutorialTamamlandi", tutorial_tamamlandi)
	config.set_value("Oyun", "UykuSahnesiGirisSayisi", uyku_sahnesi_giris_sayisi)
	config.save("user://savegame.cfg")
	print("💾 Oyun kaydedildi.")

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
		pyro_aktif = config.get_value("Oyuncu", "PyroAktif", false)
		
		puan_carpani = config.get_value("Bufflar", "PuanCarpani", 1.0)
		revive_aktif = config.get_value("Bufflar", "ReviveAktif", false)
		fener_aktif = config.get_value("Bufflar", "FenerAktif", false)
		pyro_yavaslatma = config.get_value("Bufflar", "ZamanYavas", false)
		kanli_civi_aktif = config.get_value("Bufflar", "KanliCiviAktif", false)
		kahin_gozu_aktif = config.get_value("Bufflar", "KahinGozuAktif", false)
		
		envanter.clear()
		var esya_yollari = config.get_value("Oyun", "Envanter", [])
		for yol in esya_yollari:
			if ResourceLoader.exists(yol):
				envanter.append(load(yol))

		intro_tamamlandi = config.get_value("Oyun", "IntroTamamlandi", false)
		tutorial_tamamlandi = config.get_value("Oyun", "TutorialTamamlandi", false)
		uyku_sahnesi_giris_sayisi = config.get_value("Oyun", "UykuSahnesiGirisSayisi", 0)

		# Corrupt save fix: HP sıfırsa tam sağlığa döndür
		if oyuncu_kalan_bar <= 0 or oyuncu_suanki_hp <= 0:
			print("⚠️ Yükleme: Corrupt HP tespit edildi, tam sağlığa sıfırlanıyor.")
			oyuncu_kalan_bar = oyuncu_max_bar
			oyuncu_suanki_hp = 10
	else:
		kayitli_seviye = 1


func _intro_durumu_yukle():
	"""Sadece intro ve tutorial tamamlandı mı bilgisini yükler."""
	var config = ConfigFile.new()
	var hata = config.load("user://savegame.cfg")
	if hata == OK:
		intro_tamamlandi = config.get_value("Oyun", "IntroTamamlandi", false)
		tutorial_tamamlandi = config.get_value("Oyun", "TutorialTamamlandi", false)
		print("📂 Intro/Tutorial durumu yüklendi: Intro=", intro_tamamlandi, " Tutorial=", tutorial_tamamlandi)
	else:
		intro_tamamlandi = false
		tutorial_tamamlandi = false
		print("📂 Save dosyası bulunamadı, intro sıfır.")

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
	verileri_sifirla()

func mermi_ekle(miktar: int) -> bool:
	if mermi_sayisi >= max_mermi: return false
	mermi_sayisi = min(mermi_sayisi + miktar, max_mermi)
	emit_signal("mermi_degisti", mermi_sayisi)
	return true

func mermiyi_kullan():
	if mermi_sayisi > 0:
		mermi_sayisi -= 1
		_arayuz_guncelle()
		return true
	return false

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
		while TutorialManager and TutorialManager.tutorial_aktif and (TutorialManager.suanki_adim == 8 or TutorialManager.suanki_adim == 9):
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
		LevelManager.is_boss_acting = true # Re-lock turn and hide cursor
	
	if is_instance_valid(ghost_canvas):
		ghost_canvas.queue_free()
		
	get_tree().call_group("Dusman", "set_process_mode", Node.PROCESS_MODE_INHERIT)
	print("🌍 REALITY RESTORED.")

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

func pelerin_hak_dus():
	if zar_atlama_hakki > 0:
		zar_atlama_hakki -= 1

# --- 🫁 MİDE FONKSİYONLARI ---
