extends CanvasLayer

func _ready():
	# Oyun bittiği için Mouse'u görünür ve serbest yapıyoruz
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# --- BUTON BAĞLANTILARI (Senin verdiğin yollara göre) ---
	
	# Tekrar Dene Butonu
	$ColorRect/Label/VBoxContainer/TekrarButonu.pressed.connect(_on_tekrar_pressed)
	
	# Ana Menü Butonu
	$ColorRect/Label/VBoxContainer/MenuButonu.pressed.connect(_on_menu_pressed)

func _on_tekrar_pressed():
	# Oyun durdurulmuşsa (pause) devam ettir
	get_tree().paused = false
	
	# Bölümü baştan yükle
	get_tree().reload_current_scene()

func _on_menu_pressed():
	# Oyun durdurulmuşsa devam ettir
	get_tree().paused = false
	
	# Ana Menüye dön
	# DİKKAT: Eğer AnaMenu.tscn dosyan "Scenes" klasöründe değilse, 
	# aşağıdaki yolu kendi dosya konumuna göre düzeltmelisin (Örn: "res://AnaMenu.tscn")
	get_tree().change_scene_to_file("res://ana_menu.tscn")
