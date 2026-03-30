extends Node3D

@onready var oyuncu = $Oyuncu
@onready var alt_yazi = $UI/Label 
# EKLENEN 1: Geçiş Ekranına ulaşıyoruz
@onready var gecis_perdesi = $UI/GecisEkrani

# Kapı Alanları 
@onready var kapilar = [$Kapi_On, $Kapi_Arka, $Kapi_Sag, $Kapi_Sol]

var diyaloglar = [
	"misir_diyalog_1",
	"misir_diyalog_2",
	"misir_diyalog_3",
	"misir_diyalog_4",
	"misir_diyalog_5",
	"misir_diyalog_6",
	"misir_diyalog_7",
	"misir_diyalog_8",
	"misir_diyalog_9"
]

func _ready():
	# DEMO İÇİN ASKIYA ALINDI - Doğrudan Sphenks.tscn'ye geç
	GameManager.intro_tamamlandi = true
	GameManager.oyunu_kaydet()
	get_tree().change_scene_to_file("res://Scenes/Sphenks.tscn")
	return

	# EKLENEN 2: SİYAH EKRANI YAVAŞÇA KALDIR (GÖZÜNÜ AÇMA EFEKTİ)
	acilis_efekti_yap()

	# Kapıların sinyallerini bağla
	for kapi in kapilar:
		if kapi: # Hata almamak için var mı diye kontrol et
			kapi.body_entered.connect(kapidan_giris)
	
	# Monoloğu başlat
	monolog_oynat()

	# --- TALİMAT YAZISINI EKLE ---
	_set_up_instruction_label("inst_sphenks")
	if DilYoneticisi:
		DilYoneticisi.dil_degisti.connect(func(): _set_up_instruction_label("inst_sphenks"))

func _set_up_instruction_label(key: String):
	var ui_layer = find_child("UI", true, false)
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UI"
		add_child(ui_layer)

	var label = ui_layer.get_node_or_null("InstructionLabel")
	if not label:
		label = Label.new()
		label.name = "InstructionLabel"
		ui_layer.add_child(label)

	label.text = DilYoneticisi.metin_al(key) if DilYoneticisi else key

	# Styling
	var font = load("res://Assets/Fonts/PressStart2P-Regular.ttf")
	if font: label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)

	# Layout (Orta Üst)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.position.y = 40
	label.offset_left = -label.size.x / 2.0
	label.offset_right = label.size.x / 2.0

func acilis_efekti_yap():
	if gecis_perdesi:
		# Önce ekranı simsiyah yap (Factor 1.0)
		gecis_perdesi.material.set_shader_parameter("factor", 1.0)
		
		# Sonra 3 saniye içinde yavaşça şeffaflaştır (Factor 0.0)
		var tween = create_tween()
		tween.tween_property(gecis_perdesi.material, "shader_parameter/factor", 0.0, 3.0)

func monolog_oynat():
	if not alt_yazi: return
	
	# Ekran açılana kadar bekle (3 saniye)
	await get_tree().create_timer(3.0).timeout
	
	for satir_key in diyaloglar:
		var txt = DilYoneticisi.metin_al(satir_key)
		alt_yazi.text = txt
		var sure = clamp(txt.length() * 0.08, 2.0, 5.0)
		await get_tree().create_timer(sure).timeout
		alt_yazi.text = ""
		await get_tree().create_timer(0.5).timeout

func kapidan_giris(body):
	if body.name == "Oyuncu" or body.is_in_group("Oyuncu"):
		print("Piramite giriliyor... Geçiş ekranı başlıyor.")
		# Hemen ekrana beyaz flash
		if gecis_perdesi:
			# Parıldayıp kararma: önce beyaza çek, sonra siyaha al
			gecis_perdesi.color = Color(1, 1, 1, 0)
			var t = create_tween()
			t.tween_property(gecis_perdesi, "color", Color(1, 1, 1, 1), 0.3)
			t.tween_property(gecis_perdesi.material, "shader_parameter/factor", 1.0, 0.5)
		ozel_gecis_yap()

func ozel_gecis_yap():
	# ... (Ekran karartma tween kodların varsa burada kalsın) ...
	
	# --- YENİ EKLENECEK KISIM ---
	print("Hikaye modu tamamlandı. Kaydediliyor...")
	GameManager.intro_tamamlandi = true
	GameManager.oyunu_kaydet() # Durumu dosyaya yaz
	# ----------------------------
	
	# Biraz bekle ve asıl oyuna geç
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://Scenes/Sphenks.tscn")
