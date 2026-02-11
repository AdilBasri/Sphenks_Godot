extends CharacterBody3D

# --- AYARLAR ---
var inceleme_modu_aktif = false
var yurume_hizi = 3.0
var yer_cekimi = 9.8
var fare_hassasiyeti = 0.003
var titreme_gucu = 0.005
@export var titreme_aktif : bool = false

var kamera = null
var raycast = null
var crosshair_ui = null

# --- RESİMLER ---
# Klasör adının BÜYÜK/KÜÇÜK harf uyumuna dikkat et!
var crosshair_idle = preload("res://Assets/1.png") 
var crosshair_click = preload("res://Assets/2.png") 

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# --- 1. KAMERAYI BUL ---
	# Direkt çocuklarda Camera3D ara
	for child in get_children():
		if child is Camera3D:
			kamera = child
			kamera.fov = 90.0
			break
	
	# --- 2. RAYCAST'İ BUL ---
	if kamera:
		# Önce isme göre ara
		if kamera.has_node("RayCast3D"):
			raycast = kamera.get_node("RayCast3D")
		else:
			# Bulamazsan kameranın içine girip TİPİNE göre ara (Garanti Yöntem)
			for child in kamera.get_children():
				if child is RayCast3D:
					raycast = child
					break
		
		if not raycast:
			print("⚠️ UYARI: Kameranın içinde RayCast3D nesnesi yok!")
	else:
		print("⛔ HATA: Oyuncu içinde Camera3D bulunamadı!")

	# --- 3. CROSSHAIR BUL ---
	# Sahne kökünde 'Nisangah' ismini ara
	var root = get_tree().current_scene
	crosshair_ui = root.find_child("Nisangah", true, false)
	
	if crosshair_ui:
		crosshair_ui.texture = crosshair_idle
	else:
		print("⚠️ UYARI: Sahnede 'Nisangah' isimli bir nesne bulunamadı.")

func _input(event):
	if inceleme_modu_aktif: return
		
	if kamera and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * fare_hassasiyeti)
		kamera.rotate_x(-event.relative.y * fare_hassasiyeti)
		kamera.rotation.x = clamp(kamera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		crosshair_tiklama_efekti()
		kontrol_et_ve_tikla()

func _physics_process(delta):
	if kamera:
		if titreme_aktif:
			kamera.h_offset = randf_range(-titreme_gucu, titreme_gucu)
			kamera.v_offset = randf_range(-titreme_gucu, titreme_gucu)
		else:
			kamera.h_offset = 0
			kamera.v_offset = 0

	if not is_on_floor():
		velocity.y -= yer_cekimi * delta

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
	if raycast == null: return

	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var carpan = raycast.get_collider()
		
		if carpan.has_method("etkilesim_baslat"):
			carpan.etkilesim_baslat()
		elif carpan.get_parent() and carpan.get_parent().has_method("etkilesim_baslat"):
			carpan.get_parent().etkilesim_baslat()
		else:
			# Çarpılan nesnenin adını yazdır ki neye vurduğumuzu görelim
			print("Etkileşimsiz nesneye çarpıldı: ", carpan.name)

func crosshair_tiklama_efekti():
	if not crosshair_ui: return
	crosshair_ui.texture = crosshair_click
	await get_tree().create_timer(0.5).timeout
	if crosshair_ui: 
		crosshair_ui.texture = crosshair_idle
