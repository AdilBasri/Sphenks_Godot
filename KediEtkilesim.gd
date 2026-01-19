extends Sprite3D

# --- AYARLAR ---
@export var normal_hal : Texture2D
@export var uzayan_hal : Texture2D 

# Diyalog sırasında kedinin duracağı yer (SOLDA)
var diyalog_pozisyonu = Vector3(-0.5, -0.6, -1.0) 
# Normal taşıma pozisyonu (ORTADA)
var normal_tasi_pozisyonu = Vector3(0, -0.6, -1.0)

# Kediyi kameranın ne kadar önüne koyalım? (Daha uzağa attık: -1.0)
var kamera_pozisyonu = Vector3(0, -1.0, -1.0)
# Tutulurken boyutunu küçültelim ki ekranı kaplamasın
var tutulma_boyutu = Vector3(0.2, 0.2, 0.2) 

# --- DEĞİŞKENLER ---
var tutuluyor = false
var orjinal_ebeveyn = null      
var orjinal_konum = Vector3.ZERO
var orjinal_boyut = Vector3.ONE 

func _ready():
	if normal_hal: texture = normal_hal
	orjinal_boyut = scale # Başlangıç boyutunu hatırla

# --- TIKLAMA (Sadece Yakalamak İçin) ---
# Parametre isimlerinin başına _ koyduk ki sarı uyarılar gitsin
func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not tutuluyor:
			yakala()

# --- GLOBAL INPUT (Bırakmak ve Sallamak İçin) ---
func _input(event):
	if tutuluyor:
		# 1. BIRAKMA KONTROLÜ (Ekranın her yerinde çalışır)
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				birak()
		
		# 2. SALLAMA EFEKTİ
		elif event is InputEventMouseMotion:
			position.x += event.relative.x * 0.0005 # Hassasiyeti azalttım
			position.y -= event.relative.y * 0.0005
			
			# Sınırları biraz daralttım
			position.x = clamp(position.x, -0.3, 0.3)
			position.y = clamp(position.y, -1.0, -0.3)

# --- MEKANİK ---
func yakala():
	tutuluyor = true
	orjinal_ebeveyn = get_parent()
	orjinal_konum = global_position
	
	# Resmi ve ayarları değiştir
	if uzayan_hal: texture = uzayan_hal
	no_depth_test = true 
	render_priority = 10 
	
	# Kameraya taşı
	var kamera = get_viewport().get_camera_3d()
	if kamera:
		reparent(kamera, false) 
		position = kamera_pozisyonu 
		rotation = Vector3.ZERO 
		scale = tutulma_boyutu # KÜÇÜLTME HAMLESİ BURADA

func birak():
	tutuluyor = false
	
	# Her şeyi eski haline getir
	if normal_hal: texture = normal_hal
	no_depth_test = false
	render_priority = 0
	
	if orjinal_ebeveyn:
		reparent(orjinal_ebeveyn, false)
		global_position = orjinal_konum 
		scale = orjinal_boyut # ESKİ BOYUTUNA DÖN
