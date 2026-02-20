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

func _on_tekrar_pressed():
	print("🔄 Tekrar Deneniyor... Veriler sıfırlanıyor.")
	get_tree().paused = false # Oyunu devam ettir
	
	if GameManager:
		GameManager.verileri_sifirla()
	
	get_tree().reload_current_scene()

func _on_menu_pressed():
	print("🏠 Menüye Dönülüyor...")
	get_tree().paused = false # Oyunu devam ettir
	
	if GameManager:
		GameManager.verileri_sifirla()
	
	# Ana Menü yolunun doğruluğundan emin ol
	get_tree().change_scene_to_file("res://ana_menu.tscn")
