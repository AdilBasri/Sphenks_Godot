extends Node3D

# --- AYARLAR ---
@export var masa_yuksekligi : float = 1.0  
@export var zemin_yuksekligi : float = 0.05 
@export var suruklenme_hizi : float = 20.0
@export var tilt_miktari : float = 0.4
@export var grid_boyutu : float = 0.2
@export var golge_duzeltme_acisi : float = -90.0 

# --- GRID SINIRLARI ---
@export var grid_min_x : float = -0.8
@export var grid_max_x : float = 0.65
@export var grid_min_z : float = -0.8
@export var grid_max_z : float = 0.8

# --- REFERANSLAR ---
@onready var gorsel_node = $Gorsel   
@onready var hayalet_node = $Hayalet 

# --- DURUMLAR ---
var tutuluyor : bool = false
var baslangic_pozisyonu : Vector3
var hedef_pozisyon : Vector3
var kamera : Camera3D
var hedef_rotasyon_y : float = 0.0
var gecerli_konumda_mi : bool = false 

# --- KONUMLAR ---
var parca_konumlari = [] 

func _ready():
	kamera = get_viewport().get_camera_3d()
	baslangic_pozisyonu = global_position 
	hedef_pozisyon = global_position
	hedef_pozisyon.y = masa_yuksekligi
	
	if hayalet_node:
		hayalet_node.visible = false
		hayalet_node.top_level = true 
		
		if gorsel_node:
			for cocuk in gorsel_node.get_children():
				if cocuk is Node3D:
					parca_konumlari.append(cocuk.position)

func _on_area_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tutuluyor = true

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if tutuluyor:
			tutuluyor = false
			blok_yerlestir()

func _process(delta):
	if tutuluyor and InputMap.has_action("ui_rotate") and Input.is_action_just_pressed("ui_rotate"):
		hedef_rotasyon_y += deg_to_rad(90)

	if tutuluyor:
		# --- 1. ANA GÖVDE HAREKETİ ---
		var mouse_pos = get_viewport().get_mouse_position()
		var from = kamera.project_ray_origin(mouse_pos)
		var to = from + kamera.project_ray_normal(mouse_pos) * 1000.0
		var masa_duzlemi = Plane(Vector3.UP, masa_yuksekligi)
		var carpisma = masa_duzlemi.intersects_ray(from, to)
		
		if carpisma:
			hedef_pozisyon = carpisma
		
		global_position = global_position.lerp(hedef_pozisyon, suruklenme_hizi * delta)
		rotation.y = lerp_angle(rotation.y, hedef_rotasyon_y, 15 * delta)
		
		# --- 2. GÖRSEL TILT ---
		if gorsel_node:
			var fark = hedef_pozisyon - global_position
			gorsel_node.rotation.z = lerp_angle(gorsel_node.rotation.z, -fark.x * tilt_miktari, 10 * delta)
			gorsel_node.rotation.x = lerp_angle(gorsel_node.rotation.x, fark.z * tilt_miktari, 10 * delta)
		
		# --- 3. GÖLGE VE GELİŞMİŞ GRID KONTROLÜ ---
		if hayalet_node:
			var grid_x = snapped(global_position.x, grid_boyutu)
			var grid_z = snapped(global_position.z, grid_boyutu)
			
			var hepsi_sigiyor = true
			var o_anki_rotasyon = rotation.y 
			
			# DÜZELTME BURADA: Bloğun ölçeğini (Scale) alıyoruz!
			var anlik_olcek = scale # Bloğun Inspector'daki Scale değeri (Örn: 0.2, 0.2, 0.2)

			for parca_pos in parca_konumlari:
				# ÖNCE ÖLÇEKLE ÇARPIYORUZ! (Artık devasa değil, gerçek boyutta)
				var olcekli_parca = parca_pos * anlik_olcek
				
				# Sonra döndürüyoruz
				var donmus_parca = olcekli_parca.rotated(Vector3.UP, o_anki_rotasyon)
				
				var parca_dunya_x = grid_x + donmus_parca.x
				var parca_dunya_z = grid_z + donmus_parca.z
				
				# Sınır kontrolü (Toleransı biraz arttırdım: 0.05)
				if parca_dunya_x < (grid_min_x - 0.05) or parca_dunya_x > (grid_max_x + 0.05) or \
				   parca_dunya_z < (grid_min_z - 0.05) or parca_dunya_z > (grid_max_z + 0.05):
					hepsi_sigiyor = false
					# Debug için (Hangi tarafın taştığını görmek istersen yorumu aç)
					# print("Taşan Parça X: ", parca_dunya_x, " Sınır Max: ", grid_max_x)
					break 

			if hepsi_sigiyor:
				hayalet_node.visible = true
				gecerli_konumda_mi = true
				hayalet_node.global_position = Vector3(grid_x, zemin_yuksekligi, grid_z)
				hayalet_node.global_rotation = Vector3(deg_to_rad(golge_duzeltme_acisi), rotation.y, 0)
			else:
				hayalet_node.visible = false 
				gecerli_konumda_mi = false
			
	else:
		global_position = global_position.lerp(baslangic_pozisyonu, 5.0 * delta)
		if hayalet_node: hayalet_node.visible = false
		if gorsel_node: gorsel_node.rotation = gorsel_node.rotation.lerp(Vector3.ZERO, 10 * delta)

func blok_yerlestir():
	if gecerli_konumda_mi:
		print("✅ Grid Hedefi: ", hayalet_node.global_position)
	else:
		print("❌ Parçalar sınır dışı!")
