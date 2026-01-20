extends Sprite3D

# --- YENİ TÜR TANIMI ---
# Node3D yerine senin yeni class_name'ini kullanıyoruz
@export var grid_yoneticisi : GridYonetici 

@export var diyalog_yoneticisi : CanvasLayer 
@export var normal_hal : Texture2D
@export var uzayan_hal : Texture2D 

var diyalog_pozisyonu = Vector3(-0.5, -0.6, -1.0)
var oyun_pozisyonu = Vector3(0.0, -0.6, -1.0) 

var tutuluyor = false
var hikaye_basladi_mi = false 
var orjinal_ebeveyn = null      
var orjinal_konum = Vector3.ZERO
var orjinal_boyut = Vector3.ONE 
var tutulma_boyutu = Vector3(0.2, 0.2, 0.2) 

func _ready():
	if normal_hal: texture = normal_hal
	orjinal_boyut = scale
	orjinal_konum = global_position
	orjinal_ebeveyn = get_parent()

func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not tutuluyor:
			yakala()

func _input(event):
	if tutuluyor:
		if hikaye_basladi_mi:
			return 

		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				birak()
		
		elif event is InputEventMouseMotion:
			# Kedi Mouse Takibi (Basit 2D projeksiyon)
			position.x += event.relative.x * 0.0005
			position.y -= event.relative.y * 0.0005
			position.x = clamp(position.x, -0.3, 0.3)
			position.y = clamp(position.y, -0.8, -0.3)

func yakala():
	tutuluyor = true
	# Kedi grid üzerinde bir yer kaplıyorsa serbest bırakalım
	if grid_yoneticisi:
		grid_yoneticisi.release_owner(self)
	
	if uzayan_hal: texture = uzayan_hal
	no_depth_test = true 
	render_priority = 10 
	
	if diyalog_yoneticisi and not hikaye_basladi_mi:
		hikaye_basladi_mi = true
		diyalog_yoneticisi.diyalog_baslat(self) 
		
		var kamera = get_viewport().get_camera_3d()
		if kamera:
			reparent(kamera, false) 
			position = diyalog_pozisyonu 
			rotation = Vector3.ZERO 
			scale = tutulma_boyutu
			
	else:
		var kamera = get_viewport().get_camera_3d()
		if kamera:
			reparent(kamera, false) 
			position = oyun_pozisyonu 
			rotation = Vector3.ZERO 
			scale = tutulma_boyutu

func birak():
	tutuluyor = false
	
	if normal_hal: texture = normal_hal
	no_depth_test = false
	render_priority = 0
	
	var yerlesti = false
	
	# --- GÜNCELLENMİŞ GRID MANTIĞI ---
	if grid_yoneticisi:
		# 1. Mouse'un dünyadaki yerini al
		var world_pos = grid_yoneticisi.get_masa_world_noktasi()
		
		if world_pos != null:
			# 2. Hücre koordinatına çevir
			var cell = grid_yoneticisi.world_to_cell(world_pos)
			
			if cell != null:
				# 3. Yer müsait mi? (Kedi tek kare kaplar [0,0])
				if grid_yoneticisi.can_place(cell, [Vector2i(0,0)]):
					yerlesti = true
					
					# Grid'in çocuğu yap
					reparent(grid_yoneticisi.masa_node, true) # Masa node'una ekle
					
					# Pozisyonla
					var merkez = grid_yoneticisi.cell_center_world(cell)
					# Local pozisyona çevirmemiz gerekebilir, ama global set etmek daha güvenli
					global_position = Vector3(merkez.x, merkez.y + 0.05, merkez.z)
					
					rotation_degrees = Vector3(-90, 0, 0) # Masaya yatır
					scale = orjinal_boyut
					
					# Grid'e işle
					grid_yoneticisi.occupy(cell, [Vector2i(0,0)], self)
					print("✅ Kedi Grid'e oturdu: ", cell)

	if not yerlesti:
		print("↩️ Kedi eve döndü.")
		if orjinal_ebeveyn:
			reparent(orjinal_ebeveyn, false)
			# Tween ile yumuşak dönüş
			var tween = create_tween()
			tween.tween_property(self, "global_position", orjinal_konum, 0.3)
			tween.parallel().tween_property(self, "scale", orjinal_boyut, 0.3)
			rotation = Vector3.ZERO # Dik dursun

func oyun_moduna_gec():
	print("🐈 Kedi: Özgürüm!")
	hikaye_basladi_mi = false
	diyalog_yoneticisi = null 
	birak()
