extends StaticBody3D

# OYUNCU İLE ETKİLEŞİM İÇİN DEĞİŞKENLER
var sinematik_aktif: bool = false
var orjinal_kamera = null
var sinematik_kamera: Camera3D = null
var oyuncu_node = null

# SİNEMATİK AYARLARI
@export var klavye_hizi: float = 0.05
@export var yazi_bekleme: float = 2.5
var metin_sayaci: int = 0

# UI ELEMANLARI
var canvas: CanvasLayer = null
var shader_rect: ColorRect = null
var yazi_rt: RichTextLabel = null
var etkilesim_yazi: Label3D = null

# KAMERA SALLANMASI
var kamera_sallanma_gucu: float = 0.004
var kamera_sallaniyor_mu: bool = false

var anubis_metinleri = [
	"anubis_diyalog_1",
	"anubis_diyalog_2",
	"anubis_diyalog_3",
	"anubis_diyalog_4",
	"anubis_diyalog_5",
	"anubis_diyalog_6",
	"anubis_diyalog_7",
	"anubis_diyalog_8",
	"anubis_diyalog_9",
	"anubis_diyalog_10"
]

func _ready():
	# Root düğümdeki [E] Konuş yazısını bul
	etkilesim_yazi = get_parent().get_node_or_null("EtkilesimYazisi")
	if etkilesim_yazi:
		etkilesim_yazi.visible = false
	
	if DilYoneticisi:
		DilYoneticisi.dil_degisti.connect(_metinleri_guncelle)
		_metinleri_guncelle()

func _metinleri_guncelle():
	if etkilesim_yazi:
		etkilesim_yazi.text = DilYoneticisi.metin_al("anubis_konus_etkilesim")
	
	if sinematik_aktif and is_instance_valid(yazi_rt) and metin_sayaci < anubis_metinleri.size():
		var anahtar = anubis_metinleri[metin_sayaci]
		var suanki_metin = DilYoneticisi.metin_al(anahtar)
		var korkunc_yazi = "[center][shake rate=30.0 level=8 connected=1]" + suanki_metin + "[/shake][/center]"
		yazi_rt.text = korkunc_yazi

func _process(_delta):
	# Kamera sallama efekti — SinematikKamera aktifken ONU salla
	if kamera_sallaniyor_mu and sinematik_kamera and is_instance_valid(sinematik_kamera):
		var t = Time.get_ticks_msec() / 1000.0
		# Düzensiz, korkutucu sarsıntı
		sinematik_kamera.h_offset = sin(t * 23.7) * kamera_sallanma_gucu + randf_range(-0.001, 0.001)
		sinematik_kamera.v_offset = cos(t * 31.3) * kamera_sallanma_gucu + randf_range(-0.001, 0.001)
		sinematik_kamera.rotation.z = sin(t * 17.0) * 0.003

func _on_bakis_basladi():
	if not sinematik_aktif and etkilesim_yazi:
		etkilesim_yazi.visible = true

func _on_bakis_bitti():
	if etkilesim_yazi:
		etkilesim_yazi.visible = false

# RAYCAST İLE ETKİLEŞİM İÇİN
# oyuncu.gd interact(self) çağırır — bu fonksiyon köprü görevi görür
func interact(_oyuncu = null):
	if not sinematik_aktif:
		sinematik_baslat()

func etkilesim_baslat():
	if not sinematik_aktif:
		sinematik_baslat()

# Ayrıca "E" tuşuna basmasalar bile Raycast ile bakıldığında "[E] Konuş" görünsün diye 
# Inceleme modulune benzer "odaklanma" fonksiyonlarına ihtiyacımız olabilir.
# Oyununuzda genelde RayCast odaklanmayı nasıl yapıyor bilmiyoruz ama 
# "E" tuşuna bastığında zaten "etkilesim_baslat" çalışacaktır.
# Etkileşim yazısını oyuncu üzerine geldiğinde göstermek için (opsiyonel):
func _on_mouse_entered():
	_on_bakis_basladi()

func _on_mouse_exited():
	_on_bakis_bitti()


func sinematik_baslat():
	sinematik_aktif = true
	if etkilesim_yazi:
		etkilesim_yazi.visible = false
	
	# 1. Oyuncunun kontrolünü dondur
	oyuncu_node = get_tree().get_first_node_in_group("Oyuncu")
	if not oyuncu_node:
		# yenisahne.tscn'de Oyuncu grubu olmayabilir — isimle de ara
		oyuncu_node = get_tree().current_scene.find_child("Oyuncu", true, false)
	
	if oyuncu_node:
		oyuncu_node.set_process(false)
		oyuncu_node.set_physics_process(false)
		oyuncu_node.set_process_input(false)  # OyuncuBus.gd _input() kullanıyor
		
		# Kamerayı bul
		for child in oyuncu_node.get_children():
			if child is Camera3D:
				orjinal_kamera = child
				break
	
	# 2. SinematikKamera BU NODE'un (AnubisEtkilesim) ÇOCUĞU
	sinematik_kamera = get_node_or_null("SinematikKamera")
	if not sinematik_kamera:
		# Fallback: parent (Anubis) altında da ara
		sinematik_kamera = get_parent().get_node_or_null("SinematikKamera")
	
	if sinematik_kamera:
		print("🎥 SinematikKamera bulundu: ", sinematik_kamera.get_path())
		# Oyuncu kamerasını deaktif et ve sinematik kamerayı aktif et
		if orjinal_kamera:
			orjinal_kamera.current = false
		sinematik_kamera.current = true
	else:
		push_warning("⚠️ SinematikKamera bulunamadı!")
	
	# 3. Ekran Shader ve UI Katmanını oluştur
	await get_tree().create_timer(1.0).timeout
	ui_katmanini_kur()
	
	# 4. Kamera hafifçe sallanmaya başlasın
	kamera_sallaniyor_mu = true
	
	# 5. Yazılar akmaya başlasın
	metin_sayaci = 0
	
	# Audio Sync Tweak: Metinleri sese uyumlu hızda yazsın
	klavye_hizi = 0.06
	yazi_bekleme = 2.3
	
	_siradaki_metni_yaz()

var ses_oynatici: AudioStreamPlayer

func ui_katmanini_kur():
	canvas = CanvasLayer.new()
	canvas.layer = 90
	get_tree().current_scene.add_child(canvas)
	
	# Ses Oynatıcıyı Kur
	if not ses_oynatici:
		ses_oynatici = AudioStreamPlayer.new()
		ses_oynatici.stream = load("res://anubis_dialog.wav")
		ses_oynatici.bus = "Dialogue"
		add_child(ses_oynatici)
	
	# B&W Matrix Screen Shader
	var shader = load("res://Materials_Shaders/ghost_shader.gdshader")
	if shader:
		shader_rect = ColorRect.new()
		shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var mat = ShaderMaterial.new()
		mat.shader = shader
		shader_rect.material = mat
		
		# Efectin alfa (saydamlık) değerini yavaşça artır
		shader_rect.modulate.a = 0.0
		canvas.add_child(shader_rect)
		
		var tween = get_tree().create_tween()
		tween.tween_property(shader_rect, "modulate:a", 1.0, 1.5)
	
	# Yazı RichTextLabel'ı (Korkutucu Titreme İçin)
	yazi_rt = RichTextLabel.new()
	yazi_rt.bbcode_enabled = true
	yazi_rt.scroll_active = false
	yazi_rt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	
	# Layout'u Intro sahnelerindeki gibi alt merkeze itelim, daha dar ve okunaklı
	yazi_rt.offset_left = 200
	yazi_rt.offset_right = -200
	yazi_rt.offset_top = -180
	yazi_rt.offset_bottom = -20
	
	# Daha ideal Piramit Intro Boyutu
	yazi_rt.add_theme_font_size_override("normal_font_size", 24)
	
	# Kırmızı Font, kalın hatlar
	yazi_rt.add_theme_color_override("default_color", Color(0.9, 0.1, 0.1, 1.0))
	yazi_rt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	yazi_rt.add_theme_constant_override("outline_size", 5)
	
	# Fontu ata (Projedeki retro fontu kullan)
	var retro_font = load("res://Assets/Fonts/PressStart2P-Regular.ttf")
	if retro_font:
		yazi_rt.add_theme_font_override("normal_font", retro_font)
		
	yazi_rt.text = ""
	canvas.add_child(yazi_rt)

	# Bütün diyalog boyunca süreceği için sesi BAŞLANGIÇTA sadece 1 kere başlat (her metinde baştan başlatma)
	if ses_oynatici:
		ses_oynatici.play()

func _siradaki_metni_yaz():
	if metin_sayaci >= anubis_metinleri.size():
		sinematigi_bitir()
		return
		
	var anahtar = anubis_metinleri[metin_sayaci]
	var suanki_metin = DilYoneticisi.metin_al(anahtar) if DilYoneticisi else anahtar
	
	# Korkunç hava için metni titretecek BBCode etiketi ekle [shake]
	var korkunc_yazi = "[center][shake rate=30.0 level=8 connected=1]" + suanki_metin + "[/shake][/center]"
	
	yazi_rt.text = korkunc_yazi
	yazi_rt.visible_ratio = 0.0
	
	var metin_uzunlugu = suanki_metin.length()
	var yazma_suresi = metin_uzunlugu * klavye_hizi
	
	var tween = get_tree().create_tween()
	tween.tween_property(yazi_rt, "visible_ratio", 1.0, yazma_suresi)
	
	# Yazım bittikten sonra ekranda kalma süresi
	tween.tween_interval(yazi_bekleme)
	tween.tween_callback(_metin_bitti)

func _metin_bitti():
	metin_sayaci += 1
	var tween = get_tree().create_tween()
	tween.tween_property(yazi_rt, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		yazi_rt.modulate.a = 1.0
		_siradaki_metni_yaz()
	)

func sinematigi_bitir():
	kamera_sallaniyor_mu = false
	
	# Müzik çalıyorsa kapat
	if ses_oynatici:
		ses_oynatici.stop()
	
	# SinematikKamera offsetlerini sıfırla
	if sinematik_kamera and is_instance_valid(sinematik_kamera):
		sinematik_kamera.h_offset = 0
		sinematik_kamera.v_offset = 0
		sinematik_kamera.rotation.z = 0
	
	# --- GEÇİŞ EFEKTİ: Intro sahnelerindeki gibi fade-to-black ---
	# 1. Önce yazıyı gizle
	if yazi_rt:
		var yazi_tween = get_tree().create_tween()
		yazi_tween.tween_property(yazi_rt, "modulate:a", 0.0, 0.5)
		await yazi_tween.finished
	
	# 2. Geçiş perdesi oluştur (Siyah fade)
	var gecis_perdesi = ColorRect.new()
	gecis_perdesi.set_anchors_preset(Control.PRESET_FULL_RECT)
	gecis_perdesi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gecis_perdesi.color = Color(0, 0, 0, 0)  # Başlangıç: tamamen saydam
	canvas.add_child(gecis_perdesi)
	# Perdenin shader'dan önde olması için en üste taşı 
	canvas.move_child(gecis_perdesi, canvas.get_child_count() - 1)
	
	# 3. Fade-to-black animasyonu (3 saniye — intro ile aynı tempo)
	var gecis_tween = get_tree().create_tween()
	gecis_tween.tween_property(gecis_perdesi, "color:a", 1.0, 3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Eş zamanlı: B&W shader'ı da solduralim
	if shader_rect:
		gecis_tween.parallel().tween_property(shader_rect, "modulate:a", 0.0, 2.0)
	
	await gecis_tween.finished
	
	# 4. Sahne geçişi: Sahne2_Ev.tscn'e yükle
	print("🎬 Anubis sinematik bitti — Sahne2_Ev.tscn yükleniyor...")
	get_tree().change_scene_to_file("res://Scenes/Sahne2_Ev.tscn")
