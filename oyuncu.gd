extends CharacterBody3D

# --- AYARLAR ---
var speed = 5.0
var mouse_sensitivity = 0.003
var gravity = 9.8

# --- REFERANSLAR ---
@onready var kamera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D 
@onready var etkilesim_label = $CanvasLayer/EtkilesimYazisi 
@onready var market_node = get_tree().current_scene.find_child("Market", true, false) 

# --- DURUM DEĞİŞKENLERİ ---
var mouse_serbest_modu: bool = false # Mouse serbest mi?

func _ready():
	# Başlangıçta FPS modu (Mouse gizli)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# --- SPACE TUŞU İLE MOD DEĞİŞTİRME ---
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		toggle_mouse_mode()

	# --- MOUSE HAREKETİ (Sadece mouse serbest DEĞİLSE çalışır) ---
	if not mouse_serbest_modu:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)
			kamera.rotate_x(-event.relative.y * mouse_sensitivity)
			kamera.rotation.x = clamp(kamera.rotation.x, -1.2, 1.2)
	
	# ESC ile çıkış veya reset
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_mouse_mode():
	# Durumu tersine çevir (Açıksa kapat, kapalıysa aç)
	mouse_serbest_modu = !mouse_serbest_modu
	
	if mouse_serbest_modu:
		# MOD 1: ETKİLEŞİM MODU (Blok Tutma)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		bloklari_cagir() # Blok çağırma fonksiyonunu tetikle
	else:
		# MOD 2: FPS MODU (Etrafa Bakma)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Blokları gizlemek istersen buraya fonksiyon ekleyebilirsin

func bloklari_cagir():
	print("Bloklar çağrıldı! Mouse artık serbest.")
	# Buraya blokları ekrana getiren veya görünür yapan kodunu yazacaksın.
	# Örn: $BlokMenusu.visible = true

func _physics_process(delta):
	# Yerçekimi
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- YÜRÜME (Sadece mouse kilitliyken yürüyebilsin istersen if ekle) ---
	# Şimdilik blok modundayken de yürüyebilsin diye kısıtlamadım.
	var input_dir = Input.get_vector("sol", "sag", "ileri", "geri")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	# Market etkileşimi her zaman çalışsın
	check_interaction()

func check_interaction():
	if not raycast or not etkilesim_label: return

	if raycast.is_colliding():
		var carpilan_nesne = raycast.get_collider()
		
		# Nesne kontrolü
		if carpilan_nesne and "esya_verisi" in carpilan_nesne and carpilan_nesne.esya_verisi:
			var veri = carpilan_nesne.esya_verisi
			
			# GÜNCELLEME: Açıklamayı da ekliyoruz
			# \n alt satıra geçer.
			etkilesim_label.text = "[E] SATIN AL\n" + veri.esya_adi + " (" + str(veri.fiyat) + " Altın)\n" + veri.aciklama
			
			if Input.is_action_just_pressed("etkilesim"):
				satin_al(carpilan_nesne)
		else:
			etkilesim_label.text = "" 
	else:
		etkilesim_label.text = ""

func satin_al(urun):
	var veri = urun.esya_verisi
	
	# Markete sor
	if market_node and market_node.has_method("satin_almaya_calis"):
		var basarili = market_node.satin_almaya_calis(veri.fiyat, veri)
		
		if basarili:
			# Fiziği HEMEN kapat ki hata vermesin
			if urun.has_node("CollisionShape3D"):
				urun.get_node("CollisionShape3D").set_deferred("disabled", true)
			
			var tween = create_tween()
			# DÜZELTME: Sıfıra değil, 0.01'e küçültüyoruz (Hata Çözümü)
			tween.tween_property(urun, "scale", Vector3(0.01, 0.01, 0.01), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_callback(urun.queue_free)
