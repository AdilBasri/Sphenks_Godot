extends Sprite3D

@export var grid_yoneticisi : GridYonetici 
@export var normal_hal : Texture2D
@export var uzayan_hal : Texture2D 

var tutuluyor = false
var orjinal_ebeveyn = null      
var orjinal_konum = Vector3.ZERO
var orjinal_boyut = Vector3.ONE 
var tutulma_boyutu = Vector3(0.2, 0.2, 0.2) 

func _ready():
	add_to_group("Kedi")
	if normal_hal: texture = normal_hal
	orjinal_boyut = scale
	orjinal_konum = global_position
	orjinal_ebeveyn = get_parent()

func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not tutuluyor:
			yakala()
		elif not event.pressed and tutuluyor:
			birak()

func _input(event):
	if tutuluyor:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				birak()
		
		elif event is InputEventMouseMotion:
			var kamera = get_viewport().get_camera_3d()
			if not kamera: return
			
			# Ekrandaki fare koordinatını kameranın 1 metre ilerisindeki 3D koordinata dönüştür
			var mouse_pos = get_viewport().get_mouse_position()
			var depth = 1.0
			var world_pos = kamera.project_position(mouse_pos, depth)
			
			global_position = world_pos
			# Kameraya tam bakması için rotasyonu temizle
			rotation = Vector3.ZERO

func yakala():
	tutuluyor = true
	if grid_yoneticisi:
		grid_yoneticisi.release_owner(self)
	
	if uzayan_hal: texture = uzayan_hal
	no_depth_test = true 
	render_priority = 10 
	
	var kamera = get_viewport().get_camera_3d()
	if kamera:
		reparent(kamera, true) 
		rotation = Vector3.ZERO 
		scale = tutulma_boyutu

func birak():
	# Zaten bırakılmışsa tekrar tetikleme
	if not tutuluyor: return 
	
	tutuluyor = false
	if normal_hal: texture = normal_hal
	no_depth_test = false
	render_priority = 0
	
	var yerlesti = false
	
	if grid_yoneticisi:
		var world_pos = grid_yoneticisi.get_masa_world_noktasi()
		if world_pos != null:
			var cell = grid_yoneticisi.world_to_cell(world_pos)
			if cell != null:
				if grid_yoneticisi.can_place(cell, [Vector2i(0,0)]):
					yerlesti = true
					reparent(grid_yoneticisi.masa_node, true) 
					var merkez = grid_yoneticisi.cell_center_world(cell)
					global_position = Vector3(merkez.x, merkez.y + 0.05, merkez.z)
					rotation_degrees = Vector3(-90, 0, 0) # Masaya yatır
					scale = orjinal_boyut
					grid_yoneticisi.occupy(cell, [Vector2i(0,0)], self)
					print("✅ Kedi Grid'e oturdu: ", cell)

	if not yerlesti:
		print("↩️ Kedi eve döndü.")
		if orjinal_ebeveyn:
			reparent(orjinal_ebeveyn, true)
			var tween = create_tween()
			tween.tween_property(self, "global_position", orjinal_konum, 0.3)
			tween.parallel().tween_property(self, "scale", orjinal_boyut, 0.3)
			tween.parallel().tween_property(self, "rotation", Vector3.ZERO, 0.3)
