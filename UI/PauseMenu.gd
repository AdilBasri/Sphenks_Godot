extends CanvasLayer

@onready var ana_menu_ui = $RenkZemini/AnaMenuUI
@onready var ayarlar_ui = $RenkZemini/AyarlarUI

# Butonlar
@onready var btn_devam = $RenkZemini/AnaMenuUI/Btn_Devam
@onready var btn_ayarlar = $RenkZemini/AnaMenuUI/Btn_Ayarlar
@onready var btn_cikis = $RenkZemini/AnaMenuUI/Btn_Cikis

# Ayarlar Ogeleri
@onready var dil_secimi = $RenkZemini/AyarlarUI/VBox/DilAlani/DilSec
@onready var coz_secimi = $RenkZemini/AyarlarUI/VBox/CozAlani/CozSec
@onready var btn_tam_ekran = $RenkZemini/AyarlarUI/VBox/Btn_TamEkran
@onready var kontrol_metni = $RenkZemini/AyarlarUI/VBox/KontrolMetni
@onready var btn_ayarlar_kapat = $RenkZemini/AyarlarUI/VBox/Btn_AyarKapat

# Sabit Çeviriler - Dil aracıları
@onready var baslik_duraklatildi = $RenkZemini/AnaMenuUI/Baslik_Duraklatildi
@onready var baslik_ayarlar = $RenkZemini/AyarlarUI/VBox/Baslik_Ayarlar
@onready var lbl_dil = $RenkZemini/AyarlarUI/VBox/DilAlani/Lbl_Dil
@onready var lbl_coz = $RenkZemini/AyarlarUI/VBox/CozAlani/Lbl_Coz

var cozunurlukler = [
	Vector2(1920, 1080),
	Vector2(1600, 900),
	Vector2(1366, 768),
	Vector2(1280, 720)
]

func _ready():
	visible = false
	ayarlar_ui.visible = false
	
	btn_devam.pressed.connect(uykudan_uyan)
	btn_ayarlar.pressed.connect(ayarlari_ac)
	btn_cikis.pressed.connect(ana_menuye_don)
	btn_ayarlar_kapat.pressed.connect(ayarlari_kapat)
	
	dil_secimi.item_selected.connect(_on_dil_degisti)
	coz_secimi.item_selected.connect(_on_coz_degisti)
	btn_tam_ekran.toggled.connect(_on_tam_ekran_degisti)
	
	DilYoneticisi.dil_degisti.connect(metinleri_guncelle)
	
	# Ayarlari Doldur
	dil_secimi.clear()
	dil_secimi.add_item("English", 0)
	dil_secimi.add_item("Türkçe", 1)
	
	if DilYoneticisi.secili_dil == "en":
		dil_secimi.selected = 0
	else:
		dil_secimi.selected = 1
	
	for c in cozunurlukler:
		coz_secimi.add_item("%dx%d" % [c.x, c.y])
	
	metinleri_guncelle()

func metinleri_guncelle():
	btn_devam.text = DilYoneticisi.metin_al("devam_et")
	btn_ayarlar.text = DilYoneticisi.metin_al("ayarlar")
	btn_cikis.text = DilYoneticisi.metin_al("ana_menu")
	btn_ayarlar_kapat.text = DilYoneticisi.metin_al("kapat")
	
	baslik_ayarlar.text = DilYoneticisi.metin_al("ayarlar")
	lbl_dil.text = DilYoneticisi.metin_al("dil")
	lbl_coz.text = DilYoneticisi.metin_al("cozunurluk")
	if baslik_duraklatildi:
		baslik_duraklatildi.text = DilYoneticisi.metin_al("duraklatildi")
	
	btn_tam_ekran.text = DilYoneticisi.metin_al("tam_ekran")
	
	# Kontrol tablosunu guncelle
	var kb = "[b]" + DilYoneticisi.metin_al("oyun_tuslari") + ":[/b]\n"
	kb += "- " + DilYoneticisi.metin_al("action_drag") + "\n"
	kb += "- " + DilYoneticisi.metin_al("action_parry") + "\n"
	kb += "- " + DilYoneticisi.metin_al("action_turn") + "\n"
	kb += "- " + DilYoneticisi.metin_al("action_sprint") + "\n"
	kb += "- " + DilYoneticisi.metin_al("action_interact") + "\n"
	kb += "- " + DilYoneticisi.metin_al("action_eat") + "\n"
	kb += "- " + DilYoneticisi.metin_al("action_inspect")
	kontrol_metni.text = kb

func _input(event):
	if not event.is_action_pressed("ui_cancel"): return
	# AnaMenu sahnesindeyse sadece ayarları kapat
	if get_tree().current_scene and get_tree().current_scene.name == "AnaMenu":
		if ayarlar_ui.visible:
			ayarlari_kapat()
		get_viewport().set_input_as_handled()
		return
		
	get_viewport().set_input_as_handled()
	if visible:
		if ayarlar_ui.visible:
			ayarlari_kapat()
		else:
			uykudan_uyan()
	else:
		uykuya_dal()

func uykuya_dal():
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func uykudan_uyan():
	visible = false
	ayarlar_ui.visible = false
	ana_menu_ui.visible = true
	get_tree().paused = false
	
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu:
		if oyuncu.is_sitting:
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func ayarlari_ac():
	ana_menu_ui.visible = false
	ayarlar_ui.visible = true

func ayarlari_kapat():
	ayarlar_ui.visible = false
	
	if get_tree().current_scene and get_tree().current_scene.name == "AnaMenu":
		visible = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		ana_menu_ui.visible = true

func ana_menuye_don():
	uykudan_uyan()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Ana menüye dönerken mouse görünür olmalı
	get_tree().change_scene_to_file("res://UI/ana_menu.tscn")

func _on_dil_degisti(index: int):
	if index == 0:
		DilYoneticisi.dili_degistir("en")
	else:
		DilYoneticisi.dili_degistir("tr")

func _on_coz_degisti(index: int):
	var secilen = cozunurlukler[index]
	DisplayServer.window_set_size(secilen)

func _on_tam_ekran_degisti(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)