extends CanvasLayer

# --- GARANTİLİ YÖNTEM: Sürükle Bırak Bağlantısı ---
@export var tekrar_butonu: Button
@export var menu_butonu: Button

func _ready():
	# 1. Mouse'u görünür yap
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# 2. Butonları Bağla
	if tekrar_butonu:
		tekrar_butonu.pressed.connect(_on_tekrar_pressed)
	else:
		print("HATA: Tekrar Butonu bağlanmamış! Inspector'dan ata.")
		
	if menu_butonu:
		menu_butonu.pressed.connect(_on_menu_pressed)
	else:
		print("HATA: Menü Butonu bağlanmamış! Inspector'dan ata.")
	
	metinleri_guncelle()
	DilYoneticisi.dil_degisti.connect(metinleri_guncelle)

func metinleri_guncelle():
	if tekrar_butonu:
		tekrar_butonu.text = DilYoneticisi.metin_al("tekrar")
	if menu_butonu:
		menu_butonu.text = DilYoneticisi.metin_al("ana_menu")
	
	var baslik = get_node_or_null("CenterContainer/Label")
	if baslik and baslik is Label:
		baslik.text = DilYoneticisi.metin_al("oyun_bitti")

func _on_tekrar_pressed():
	print("🔄 Tekrar Deneniyor... Veriler sıfırlanıyor.")
	get_tree().paused = false # Oyunu devam ettir
	
	var is_pyro_active = false
	if GameManager:
		is_pyro_active = GameManager.pyro_aktif
		GameManager.verileri_sifirla()
		if is_pyro_active:
			GameManager.mermi_sayisi = 3
	
	get_tree().reload_current_scene()

func _on_menu_pressed():
	print("🏠 Menüye Dönülüyor...")
	get_tree().paused = false # Oyunu devam ettir
	
	if GameManager:
		GameManager.verileri_sifirla()
	
	# Ana Menü yolunun doğruluğundan emin ol
	get_tree().change_scene_to_file("res://UI/ana_menu.tscn")
