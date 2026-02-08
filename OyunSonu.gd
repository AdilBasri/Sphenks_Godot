extends CanvasLayer

func _ready():
	# Oyun bittiği için Mouse'u görünür yapıyoruz
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Buton Bağlantıları
	if has_node("ColorRect/Label/VBoxContainer/TekrarButonu"):
		$ColorRect/Label/VBoxContainer/TekrarButonu.pressed.connect(_on_tekrar_pressed)
	
	if has_node("ColorRect/Label/VBoxContainer/MenuButonu"):
		$ColorRect/Label/VBoxContainer/MenuButonu.pressed.connect(_on_menu_pressed)

func _on_tekrar_pressed():
	print("🔄 Tekrar Deneniyor... Veriler sıfırlanıyor.")
	get_tree().paused = false
	
	# --- KRİTİK EKLEME ---
	# Bunu yapmazsak can 0 kalır ve oyun başlar başlamaz tekrar ölürsün!
	if GameManager:
		GameManager.verileri_sifirla()
	
	# Sahneyi Yenile
	get_tree().reload_current_scene()

func _on_menu_pressed():
	print("🏠 Menüye Dönülüyor...")
	get_tree().paused = false
	
	# Menüye dönerken de sıfırlayalım
	if GameManager:
		GameManager.verileri_sifirla()
	
	# Ana Menü yolunu kontrol et (Dosya adın ana_manu.gd idi, sahne adı ne?)
	# Genelde: res://Scenes/AnaMenu.tscn veya res://AnaMenu.tscn
	get_tree().change_scene_to_file("res://Scenes/AnaMenu.tscn")
