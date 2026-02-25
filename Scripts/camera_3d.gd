extends Camera3D

# Ayarlar
var fare_hassasiyeti = 0.003
var yurume_hizi = 2.0

func _ready():
	# Oyunu başlatınca fare imlecini gizle ve ekrana kilitle
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# Fare hareket edince kamerayı döndür
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * fare_hassasiyeti
		rotation.x -= event.relative.y * fare_hassasiyeti
		
		# Yukarı/Aşağı bakmayı 90 dereceyle sınırla (Takla atmayalım)
		rotation.x = clamp(rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _process(delta):
	# Klavyeden çıkış (ESC)
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# --- YÜRÜME (WASD) ---
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		global_position += direction * yurume_hizi * delta
