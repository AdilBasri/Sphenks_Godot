extends CharacterBody3D

# --- AYARLAR ---
var inceleme_modu_aktif = false
var yurume_hizi = 3.0
var sprint_hizi = 5.5   # Shift ile sprint hızı
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

# --- SES ---
var walking_player: AudioStreamPlayer

# --- HEAD BOBBING ---
var t_bob: float = 0.0
var bob_freq: float = 2.0
var bob_amp: float = 0.035

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# --- SES KURULUMU ---
	walking_player = AudioStreamPlayer.new()
	var w_stream = load("res://Sesler/walking.mp3")
	# loop özelliği AudioStreamMP3 içinde olmayabilir, bu yüzden güvenli kontrol
	if w_stream:
		if w_stream is AudioStreamMP3: w_stream.loop = true
		elif w_stream is AudioStreamWAV: w_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	walking_player.stream = w_stream
	walking_player.bus = "Master"
	walking_player.volume_db = -6.0 # %50 daha kısık (Logaritmik olarak -6dB yaklaşık %50'dir)
	add_child(walking_player)
	
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
		
	if event.is_action_pressed("etkilesim"):
		kontrol_et_ve_tikla()

func _physics_process(delta):
	# --- HAREKET VE SES ---
	if not is_on_floor():
		velocity.y -= yer_cekimi * delta

	odaklanmayi_kontrol_et()

	var anlik_hiz = sprint_hizi if Input.is_action_pressed("kosma") else yurume_hizi

	var input_dir = Input.get_vector("sol", "sag", "ileri", "geri")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * anlik_hiz
		velocity.z = direction.z * anlik_hiz
	else:
		velocity.x = move_toward(velocity.x, 0, anlik_hiz)
		velocity.z = move_toward(velocity.z, 0, anlik_hiz)

	move_and_slide()
	
	# Yürüme sesi
	if is_on_floor() and direction.length_squared() > 0.01:
		if not walking_player.playing:
			walking_player.play()
	else:
		if walking_player.playing:
			walking_player.stop()

	# --- KAMERA EFEKTLERİ ---
	if kamera:
		# Titreme efekti (Varsa)
		if titreme_aktif:
			kamera.h_offset = randf_range(-titreme_gucu, titreme_gucu)
			kamera.v_offset = randf_range(-titreme_gucu, titreme_gucu)
		else:
			# Head Bobbing uygulanacak
			_head_bob_guncelle(delta)

func _head_bob_guncelle(delta: float):
	if not is_instance_valid(kamera) or inceleme_modu_aktif:
		return

	var yatay_hiz = Vector2(velocity.x, velocity.z).length()

	if is_on_floor() and yatay_hiz > 0.5:
		# Dinamik Frekans ve Genlik
		if Input.is_action_pressed("kosma"):
			bob_freq = 2.5
			bob_amp = 0.055
		else:
			bob_freq = 2.0
			bob_amp = 0.035

		t_bob += delta * yatay_hiz * bob_freq
		
		# Figure-8 bobbing
		var hedef_y = sin(t_bob) * bob_amp
		var hedef_x = cos(t_bob * 0.5) * (bob_amp * 0.5)

		kamera.v_offset = lerp(kamera.v_offset, hedef_y, delta * 12.0)
		kamera.h_offset = lerp(kamera.h_offset, hedef_x, delta * 12.0)
	else:
		t_bob = 0.0
		kamera.v_offset = lerp(kamera.v_offset, 0.0, delta * 8.0)
		kamera.h_offset = lerp(kamera.h_offset, 0.0, delta * 8.0)

func _etkilesim_nesnesi_bul(dugum: Node, metod_adi: String) -> Node:
	var current = dugum
	while current != null:
		if current.has_method(metod_adi):
			return current
		current = current.get_parent()
	return null

func kontrol_et_ve_tikla():
	if raycast == null: return

	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var carpan = raycast.get_collider()
		print("Raycast hit: ", carpan.name, " (", carpan, ")") # DEBUG: Hangi objeye değdiğini görelim
		
		var etkilesim_hedefi = _etkilesim_nesnesi_bul(carpan, "etkilesim_baslat")
		if etkilesim_hedefi:
			etkilesim_hedefi.etkilesim_baslat()
		else:
			print("Nesnenin veya üst nesnelerinin 'etkilesim_baslat' fonksiyonu yok!")
	else:
		print("Raycast hiçbir şeye değmiyor.")

var onceki_odaklanan = null

func odaklanmayi_kontrol_et():
	if raycast == null: return
	
	raycast.force_raycast_update()
	var suanki_odaklanan = raycast.get_collider() if raycast.is_colliding() else null
	
	if suanki_odaklanan != onceki_odaklanan:
		if onceki_odaklanan != null and is_instance_valid(onceki_odaklanan):
			var cikis_hedefi = _etkilesim_nesnesi_bul(onceki_odaklanan, "_on_mouse_exited")
			if cikis_hedefi:
				cikis_hedefi._on_mouse_exited()
				
		if suanki_odaklanan != null:
			var giris_hedefi = _etkilesim_nesnesi_bul(suanki_odaklanan, "_on_mouse_entered")
			if giris_hedefi:
				giris_hedefi._on_mouse_entered()
				
		onceki_odaklanan = suanki_odaklanan

func crosshair_tiklama_efekti():
	if not crosshair_ui: return
	crosshair_ui.texture = crosshair_click
	await get_tree().create_timer(0.5).timeout
	if crosshair_ui: 
		crosshair_ui.texture = crosshair_idle
