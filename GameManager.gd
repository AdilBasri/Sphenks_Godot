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
	# Sadece intro durumunu yükle — oyun state'i her açılışta sıfır başlar
	_intro_durumu_yukle()

func verileri_sifirla():
	"""Tüm oyun verilerini başlangıç değerlerine sıfırlar."""
	oyuncu_kalan_bar = 4
	oyuncu_suanki_hp = 10
	suanki_seviye = 1
	kayitli_seviye = 1
	toplam_altin = 10
	mermi_sayisi = 10
	pyro_aktif = false
	silah_cekildi = false 
	envanter.clear()
	bolum_bufflarini_sifirla()
	zar_atlama_hakki = 0
	
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
	
	var esya_yollari = []
	for esya in envanter:
		if esya != null: esya_yollari.append(esya.resource_path)
	config.set_value("Oyun", "Envanter", esya_yollari)
	config.set_value("Oyun", "IntroTamamlandi", intro_tamamlandi)
	config.save("user://savegame.cfg")
	print("💾 Oyun kaydedildi.")

func oyunu_yukle():
	"""Kedi maması verildiğinde kaydedilen TÜM verileri yükler.
	Sadece ana_menu 'Devam Et' mantığında çağrılır."""
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
		
		envanter.clear()
		var esya_yollari = config.get_value("Oyun", "Envanter", [])
		for yol in esya_yollari:
			if ResourceLoader.exists(yol):
				envanter.append(load(yol))

		intro_tamamlandi = config.get_value("Oyun", "IntroTamamlandi", false)

		# Corrupt save fix: HP sıfırsa tam sağlığa döndür
		if oyuncu_kalan_bar <= 0 or oyuncu_suanki_hp <= 0:
			print("⚠️ Yükleme: Corrupt HP tespit edildi, tam sağlığa sıfırlanıyor.")
			oyuncu_kalan_bar = oyuncu_max_bar
			oyuncu_suanki_hp = 10
	else:
		kayitli_seviye = 1


func _intro_durumu_yukle():
	"""Sadece intro tamamlandı mı bilgisini yükler.
	Oyun state'i (HP, altın, envanter vb.) YÜKLENMİYOR — her açılışta sıfır."""
	var config = ConfigFile.new()
	var hata = config.load("user://savegame.cfg")
	if hata == OK:
		intro_tamamlandi = config.get_value("Oyun", "IntroTamamlandi", false)
		print("📂 Intro durumu yüklendi: ", intro_tamamlandi)
	else:
		intro_tamamlandi = false
		print("📂 Save dosyası bulunamadı, intro sıfır.")

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
	
	print("🌌 REALITY DENIED! Ghost Move Activated (5s B&W Blur).")
	
	# Create Shader UI Layer
	ghost_canvas = CanvasLayer.new()
	ghost_canvas.layer = 100 
	
	# B&W Matrix Screen Shader
	var cr = ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	var shader = load("res://ghost_shader.gdshader")
	if shader: mat.shader = shader
	cr.material = mat
	ghost_canvas.add_child(cr)
	
	# Scary Timer Label
	var lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 120)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var font = load("res://PressStart2P-Regular.ttf")
	if font: lbl.add_theme_font_override("font", font)
	
	lbl.text = "5"
	lbl.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	lbl.position = Vector2(100, (get_viewport().get_visible_rect().size.y / 2) - 100)
	ghost_canvas.add_child(lbl)
	
	get_tree().current_scene.add_child(ghost_canvas)
	
	# Disable Enemy processing and RETURN CAMERA TO PLAYER
	get_tree().call_group("Dusman", "set_process_mode", Node.PROCESS_MODE_DISABLED)
	get_tree().call_group("Dusman", "_kamerayi_oyuncuya_ver")
	
	var sayac = 5
	for i in range(5):
		await get_tree().create_timer(1.0).timeout
		if not ghost_move_active: return # Killed early due to block placement
		sayac -= 1
		lbl.text = str(sayac)
		
	# Time is up
	if ghost_move_active:
		end_ghost_move()
		var boss = get_tree().get_first_node_in_group("Dusman")
		if boss and boss.has_method("gercek_saldiri_basa_don"):
			boss.gercek_saldiri_basa_don()

func end_ghost_move():
	if not ghost_move_active: return
	ghost_move_active = false
	
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
