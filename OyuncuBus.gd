extends CharacterBody3D

# --- AYARLAR ---
var yurume_hizi = 3.0 
var yer_cekimi = 9.8
var fare_hassasiyeti = 0.003
var titreme_gucu = 0.005 

@onready var kamera = $Camera3D
# Az önce eklediğin RayCast'i buluyoruz
@onready var raycast = $Camera3D/RayCast3D 

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if kamera: kamera.fov = 90.0 

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * fare_hassasiyeti)
		kamera.rotate_x(-event.relative.y * fare_hassasiyeti)
		kamera.rotation.x = clamp(kamera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# --- TIKLAMA (ETKİLEŞİM) SİSTEMİ ---
	# Mouse tıklandığında (veya 'etkilesim' tuşuna basıldığında)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		kontrol_et_ve_tikla()

func _physics_process(delta):
	# Sarsıntı Efekti
	if kamera:
		kamera.h_offset = randf_range(-titreme_gucu, titreme_gucu)
		kamera.v_offset = randf_range(-titreme_gucu, titreme_gucu)

	# Yerçekimi
	if not is_on_floor():
		velocity.y -= yer_cekimi * delta

	# Hareket
	var input_dir = Input.get_vector("sol", "sag", "ileri", "geri")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * yurume_hizi
		velocity.z = direction.z * yurume_hizi
	else:
		velocity.x = move_toward(velocity.x, 0, yurume_hizi)
		velocity.z = move_toward(velocity.z, 0, yurume_hizi)

	move_and_slide()

# --- YENİ FONKSİYON: BAKTIĞIM ŞEYE DOKUN ---
func kontrol_et_ve_tikla():
	# RayCast bir şeye çarpıyor mu?
	if raycast.is_colliding():
		var carpan_nesne = raycast.get_collider()
		
		# Çarptığımız şeyin içinde "etkilesim_baslat" diye bir kod var mı?
		if carpan_nesne.has_method("etkilesim_baslat"):
			print("Yolcuya dokundum!")
			carpan_nesne.etkilesim_baslat()
