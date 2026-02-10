extends CharacterBody3D

# --- AYARLAR ---
var yurume_hizi = 3.0 
var yer_cekimi = 9.8
var fare_hassasiyeti = 0.003
var titreme_gucu = 0.005 

# YENİ EKLENEN SATIR: Editörden açıp kapatabileceğin bir kutucuk
@export var titreme_aktif : bool = false 

@onready var kamera = $Camera3D
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
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		kontrol_et_ve_tikla()

func _physics_process(delta):
	# --- TİTREŞİM KONTROLÜ (GÜNCELLENDİ) ---
	if kamera:
		if titreme_aktif:
			# Eğer kutucuk işaretliyse salla
			kamera.h_offset = randf_range(-titreme_gucu, titreme_gucu)
			kamera.v_offset = randf_range(-titreme_gucu, titreme_gucu)
		else:
			# Değilse kamerayı sabit tut (Sıfırla)
			kamera.h_offset = 0
			kamera.v_offset = 0

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

func kontrol_et_ve_tikla():
	if raycast.is_colliding():
		var carpan_nesne = raycast.get_collider()
		if carpan_nesne.has_method("etkilesim_baslat"):
			carpan_nesne.etkilesim_baslat()
