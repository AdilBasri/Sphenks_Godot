extends CharacterBody3D

var speed = 5.0
var mouse_sensitivity = 0.003
var gravity = 9.8

@onready var kamera = $Camera3D

func _ready():
	# Mouse ARTIK KAYBOLMAYACAK! Hep görünür.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event):
	# SAĞ TIK basılıyken etrafa bakma modu açılır
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Basınca gizle/kilitle
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Bırakınca göster

	# Kafa Çevirme (Sadece mouse kilitliyken/basılıyken çalışır)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * mouse_sensitivity)
			kamera.rotate_x(-event.relative.y * mouse_sensitivity)
			kamera.rotation.x = clamp(kamera.rotation.x, -1.2, 1.2)

func _physics_process(delta):
	# Yerçekimi (Zemine basmak için şart!)
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Yürüme (WASD)
	var input_dir = Input.get_vector("sol", "sag", "ileri", "geri")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
