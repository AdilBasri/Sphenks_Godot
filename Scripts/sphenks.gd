extends Node3D

# --- SAHNE REFERANSLARI ---
# GÜNCELLEME: Grid artık "TumMasaSistemi" içinde olduğu için yolunu düzelttik.
# Eğer sahnedeki kutunun adı farklıysa (örn: MasaGrubu), aşağıdaki "TumMasaSistemi" ismini ona göre değiştir.
@onready var grid: GridYonetici = $TumMasaSistemi/GridYoneticisi
@onready var spawner: Node3D = $TumMasaSistemi/BlokDagiticisi
@onready var oyuncu: CharacterBody3D = $Oyuncu 

# --- DEĞİŞKENLER ---
var oyun_modu: bool = false # False = Yürüme Modu, True = Oyun (Grid) Modu
var _blink_busy: bool = false

# Teleport hedefi (kamera için global pozisyon)
const KAPI_TELEPORT_POS: Vector3 = Vector3(-0.2, 1.1, -22)

func _ready() -> void:
	# Güvenlik Kontrolü: Grid bulundu mu?
	if not grid:
		print("!!! HATA: GridYoneticisi bulunamadı! Yolunu kontrol et: $TumMasaSistemi/GridYoneticisi")
		return

	# Oyun başlarken Yürüyüş modundayız
	print("Oyun Başladı: Yürüyüş Modu")
	
	# Blokları gizle (Void içinde beklesinler)
	if spawner and spawner.has_method("bloklari_gizle"):
		spawner.bloklari_gizle()
	
	# Oyuncu yürüyebilsinn
	if oyuncu:
		oyuncu.set_physics_process(true)
		
	# --- TUTORIAL KONTROLÜ ---
	# Eğer intro bittiyse ama BAŞLANGIÇ tutorial'ı henüz tamamlanmadıysa başlat.
	# Diğer segmentler (market, pyro vs.) kendi sahnelerinde tetiklenir.
	if GameManager.intro_tamamlandi and not GameManager.is_tutorial_segment_completed("base"):
		if TutorialManager:
			await get_tree().create_timer(1.0).timeout 
			TutorialManager.start_tutorial()
		else:
			print("⚠️ TutorialManager (Autoload) bulunamadı!")

#func _input(event: InputEvent) -> void:
#	# SPACE tuşuna basınca mod değiştir
#	if event.is_action_pressed("ui_accept"): 
#		state_degistir()

func state_degistir() -> void:
	# Güvenlik: Eğer gerekli parçalar yoksa modu değiştirme
	if not grid or not spawner or not oyuncu:
		print("!!! HATA: Sahne bağlantıları eksik, mod değiştirilemiyor.")
		return

	oyun_modu = !oyun_modu
	
	if oyun_modu:
		# --- OYUN MODUNA GEÇİŞ (MASAYA OTURMA) ---
		print("Mod Değişti: OYUN (Grid)")
		
		# 1. Oyuncuyu dondur (Yürüyemesin)
		oyuncu.set_physics_process(false)
		
		# 2. Spawner'ı Oyuncunun olduğu açıya taşı ve döndür
		_spawneri_hizala()
		
		# 3. Blokları Animasyonla Çıkar
		if spawner.has_method("bloklari_goster"):
			spawner.bloklari_goster()
		
	else:
		# --- YÜRÜYÜŞ MODUNA GEÇİŞ ---
		print("Mod Değişti: YÜRÜYÜŞ")
		
		# 1. Blokları Sakla (Void'e geri dönsünler)
		if spawner.has_method("bloklari_gizle"):
			spawner.bloklari_gizle()
		
		# 2. Oyuncuyu çöz (Yürüyebilsin)
		oyuncu.set_physics_process(true)

func _spawneri_hizala() -> void:
	# CRASH ENGELLEYİCİ: Grid yoksa işlemi durdur
	if not grid:
		print("HATA: Grid yok, hizalama yapılamadı!")
		return
		
	var merkez = grid.global_position
	var oyuncu_pos = oyuncu.global_position
	oyuncu_pos.y = merkez.y
	
	spawner.global_position = merkez
	spawner.look_at(oyuncu_pos, Vector3.UP)
	
	# --- HİZALAMA ---
	# Blokların yüzü oyuncuya dönsün diye 180 derece çeviriyoruz.
	spawner.rotate_y(deg_to_rad(180)) 
	
	# Açıyı 90 derecelik ızgaraya oturt (Snap)
	var rot_y = spawner.rotation_degrees.y
	spawner.rotation_degrees.y = round(rot_y / 90.0) * 90.0


func _input(event: InputEvent) -> void:
	# Use _input so we receive the mouse even if other nodes accept it.
	if _blink_busy: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[sphenks] Mouse left pressed: ", event)

		var cam: Camera3D = get_viewport().get_camera_3d()
		if not cam:
			print("[sphenks] No active Camera3D on viewport")
			return

		var pos = Vector2()
		# InputEventMouseButton may have position; fall back to global mouse position
		if event.has_method("get_position"):
			pos = event.position
		else:
			pos = get_viewport().get_mouse_position()

		var from: Vector3 = cam.project_ray_origin(pos)
		var to: Vector3 = from + cam.project_ray_normal(pos) * 2000.0
		print("[sphenks] Ray from", from, "to", to)

		var space = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		# exclude the player to avoid self-hits if needed
		if is_instance_valid(oyuncu):
			query.exclude = [oyuncu]

		var res = space.intersect_ray(query)
		print("[sphenks] Raycast result:", res)
		if not res:
			return

		var collider = res.collider
		if not collider:
			print("[sphenks] No collider returned")
			return

		# Check ancestor chain for any node that either has the KapiSistemi script
		# or exposes a 'kapiyi_ac' method (robust to unnamed nodes)
		var node = collider
		var found_kapi := false
		var found_node: Node = null
		while node:
			# 1) If node has a direct API for doors
			if node.has_method("kapiyi_ac"):
				found_kapi = true
				found_node = node
				break

			# 2) If node's script resource path mentions KapiSistemi.gd (robust check)
			var sc = node.get_script()
			if sc:
				# Fallback to stringifying the script resource (contains path when loaded)
				var rpath = str(sc).to_lower()
				if rpath.find("kapisistemi.gd") != -1 or (rpath.find("kapi") != -1 and rpath.find("sistemi") != -1):
					found_kapi = true
					found_node = node
					break

			# 3) If node belongs to interaction group used by doors
			if node.is_in_group("Etkilesim"):
				found_kapi = true
				found_node = node
				break

			node = node.get_parent()

		if found_kapi and is_instance_valid(found_node):
			print("[sphenks] Kapi ancestor hit (by API/script):", found_node, "(collider=", collider, ")")
			_start_blink_and_teleport(cam)
			return
		else:
			print("[sphenks] No Kapi ancestor found for collider:", collider, "— listing ancestors:")
			var anc = collider
			var depth = 0
			while anc:
				var aname = "<no-name>"
				if typeof(anc.name) == TYPE_STRING and str(anc.name) != "":
					aname = str(anc.name)
				print("  [anc %d] %s (class=%s) script=%s" % [depth, aname, anc.get_class(), str(anc.get_script())])
				anc = anc.get_parent()
				depth += 1


func _start_blink_and_teleport(cam: Camera3D) -> void:
	if _blink_busy: return
	_blink_busy = true

	# Overlay oluştur
	var layer := CanvasLayer.new()
	layer.name = "BlinkLayer"
	layer.layer = 100
	add_child(layer)

	var rect := ColorRect.new()
	rect.name = "BlinkRect"
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)

	# Kısa fade-out -> teleport -> fade-in
	# Fade out
	await get_tree().create_timer(0.01).timeout # allow a frame
	var duration_out = 0.12
	var elapsed := 0.0
	while elapsed < duration_out:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		rect.color = Color(0,0,0, clamp(elapsed / duration_out, 0.0, 1.0))

	# Tam kapandıktan hemen sonra teleport the player (prefer LevelManager API)
	if LevelManager and LevelManager.has_method("perform_blink_transition") and is_instance_valid(oyuncu):
		# Use LevelManager's blink transition so global state is consistent
		LevelManager.perform_blink_transition(KAPI_TELEPORT_POS, 0.0, Callable())
	else:
		if is_instance_valid(oyuncu):
			oyuncu.global_position = KAPI_TELEPORT_POS
			# reset player's rotation yaw so camera faces forward
			oyuncu.rotation.y = 0.0

	# Fade in
	var duration_in = 0.18
	elapsed = 0.0
	while elapsed < duration_in:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		rect.color = Color(0,0,0, 1.0 - clamp(elapsed / duration_in, 0.0, 1.0))

	# Temizlik
	layer.queue_free()
	_blink_busy = false
