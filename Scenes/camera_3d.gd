extends Camera3D

# --- SİNEMATİK AYARLAR ---
@export var ucus_hizi: float = 5.0
@export var fare_hassasiyeti: float = 0.005

var yaw: float = 0.0
var pitch: float = 0.0

func _ready():
	# Fareyi gizle
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Kameranın sahnedeki mevcut açısını al
	yaw = rotation.y
	pitch = rotation.x
	
	# BÜTÜN DİĞER KAMERALARI EZ VE ZORLA KONTROLÜ AL (Sihirli Satır)
	call_deferred("make_current")

func _input(event):
	# FARE İLE ETRAFA BAKMA
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * fare_hassasiyeti
		pitch -= event.relative.y * fare_hassasiyeti
		
		# Kafanın tam arkaya dönmesini engelle (Boyun kırılmasın)
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
		
		rotation.y = yaw
		rotation.x = pitch

	# VİDEO KAYDINI DURDURMAK İÇİN FAREYİ SERBEST BIRAKMA (ESC)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	# EKRANA TIKLAYINCA TEKRAR UÇUŞA GEÇME
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	var yon = Vector3.ZERO

	# KLAVYE İLE HAREKET (Kameranın baktığı yöne göre)
	if Input.is_key_pressed(KEY_W):
		yon -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		yon += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		yon -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		yon += transform.basis.x
		
	# Q ve E TUŞLARIYLA ASANSÖR GİBİ AŞAĞI/YUKARI İNİP ÇIKMA
	if Input.is_key_pressed(KEY_E):
		yon += transform.basis.y
	if Input.is_key_pressed(KEY_Q):
		yon -= transform.basis.y

	# Çapraz giderken hızlanmayı önlemek için vektörü normalize et
	if yon != Vector3.ZERO:
		yon = yon.normalized()

	# SHIFT TUŞUNA BASILI TUTUNCA HIZLI UÇMA (Mekanlar arası hızlı geçiş için)
	var anlik_hiz = ucus_hizi
	if Input.is_key_pressed(KEY_SHIFT):
		anlik_hiz *= 3.0

	# Kamerayı yumuşakça hareket ettir
	position += yon * anlik_hiz * delta
