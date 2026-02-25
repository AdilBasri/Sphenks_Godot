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

# --- FPS ETKİLEŞİMİ ---
# (Area3d input ve _input silindi, artık oyuncu.gd üzerinden çağrılıyor)

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
		position = Vector3(0.4, -0.3, -1.0) # Sağ alta hizala
		scale = tutulma_boyutu

func birak(hedef_pozisyon: Vector3):
	if not tutuluyor: return 
	
	tutuluyor = false
	if normal_hal: texture = normal_hal
	no_depth_test = false
	render_priority = 0
	
	var yerlesti = false
	
	if grid_yoneticisi:
		var cell = grid_yoneticisi.world_to_cell(hedef_pozisyon)
		if cell != null and grid_yoneticisi.can_place(cell, [Vector2i(0,0)]):
			yerlesti = true
			reparent(grid_yoneticisi.masa_node, true) 
			var merkez = grid_yoneticisi.cell_center_world(cell)
			global_position = Vector3(merkez.x, merkez.y + 0.05, merkez.z)
			rotation_degrees = Vector3(-90, 0, 0) # Masaya yatır
			scale = orjinal_boyut
			grid_yoneticisi.occupy(cell, [Vector2i(0,0)], self)
			print("✅ Kedi Grid'e oturdu: ", cell)

	if not yerlesti:
		print("↩️ Kedi bırakıldı: ", hedef_pozisyon)
		var ana_sahne = get_tree().current_scene
		if ana_sahne:
			reparent(ana_sahne, true)
		
		# Ortada kalmaması için havadan aşağı (zemine kadar) raycast atalım
		var uzay = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.new()
		var start_pos = hedef_pozisyon + Vector3(0, 0.5, 0) # Hafif yukardan başla ki zemin içindeyse üstüne çıksın
		var end_pos = start_pos + Vector3(0, -10.0, 0)
		query.from = start_pos
		query.to = end_pos
		var sonuc = uzay.intersect_ray(query)
		
		# İlk olarak hedef noktayı tam baktığımız yere hizalayalım, animasyon buradan başlayacak
		global_position = hedef_pozisyon
		rotation_degrees = Vector3(0, 0, 0)
		scale = orjinal_boyut
		
		if sonuc:
			var zemin_yuksekligi = sonuc.position + Vector3(0, 0.45, 0)
			# Eğer kedi zaten zemindeyse (ya da çok yakınsa) tween yapmaya gerek yok
			if global_position.distance_to(zemin_yuksekligi) > 0.1:
				var drop_tween = create_tween()
				drop_tween.tween_property(self, "global_position", zemin_yuksekligi, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				global_position = zemin_yuksekligi
