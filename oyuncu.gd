extends CharacterBody3D

# --- SİNYALLER ---
signal oyuncu_oldu 

# --- AYARLAR ---
var speed = 5.0
var mouse_sensitivity = 0.003
var gravity = 9.8
var firlatma_gucu = 8.0 

# --- CAN SİSTEMİ ---
var max_can_bari = 4        
var suanki_can_bari = 4     
var bar_hp = 10             
var suanki_hp = 10          

var yere_dustu_mu: bool = false 
var oldu_mu: bool = false       

# --- ÖZEL EŞYA DEĞİŞKENLERİ ---
var eldeki_ozel_esya: Node3D = null 
var ozel_esya_verisi: ItemData = null

# --- REFERANSLAR ---
@export var kamera: Camera3D 
@export var ui_container: HBoxContainer 

var raycast: RayCast3D = null
var etkilesim_label: Label = null
var tutulan_nesne: RigidBody3D = null 
var tutma_noktasi: Node3D = null 
var mouse_serbest_modu: bool = false 

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if not kamera:
		print("🔴 HATA: Kamera atanmamış!")
		return
	
	# Raycast Kurulumu
	raycast = kamera.get_node_or_null("RayCast3D")
	if raycast == null:
		var yeni_ray = RayCast3D.new()
		yeni_ray.name = "RayCast3D"
		kamera.add_child(yeni_ray)
		raycast = yeni_ray
	raycast.enabled = true
	raycast.target_position = Vector3(0, 0, -4.0)
	raycast.collision_mask = 0xFFFFFFFF 
	raycast.add_exception(self)

	# Tutma Noktası
	if kamera.has_node("TutmaNoktasi"):
		tutma_noktasi = kamera.get_node("TutmaNoktasi")
	else:
		var marker = Marker3D.new()
		marker.name = "TutmaNoktasi"
		marker.position = Vector3(0, 0, -2.5) 
		kamera.add_child(marker)
		tutma_noktasi = marker

	# UI Label
	if has_node("CanvasLayer/EtkilesimYazisi"):
		etkilesim_label = $CanvasLayer/EtkilesimYazisi
		
	ui_guncelle()

func _input(event):
	if not kamera or oldu_mu: return 
	if yere_dustu_mu: return 

	if event is InputEventKey and event.pressed and event.keycode == KEY_Z:
		hasar_al(1)

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		toggle_mouse_mode()

	if not mouse_serbest_modu:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)
			if not yere_dustu_mu:
				kamera.rotate_x(-event.relative.y * mouse_sensitivity)
				kamera.rotation.x = clamp(kamera.rotation.x, -1.2, 1.2)
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if eldeki_ozel_esya:
				esya_kullan()
			elif tutulan_nesne:
				birak_veya_firlat()
			else:
				etkilesime_gir()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if eldeki_ozel_esya:
				esya_birak()

func _physics_process(delta):
	if yere_dustu_mu or oldu_mu: return

	if not is_on_floor(): velocity.y -= gravity * delta

	var input_dir = Input.get_vector("sol", "sag", "ileri", "geri")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	if tutulan_nesne and tutma_noktasi:
		var hedef_pos = tutma_noktasi.global_position
		var nesne_pos = tutulan_nesne.global_position
		var yon = (hedef_pos - nesne_pos) * 15.0 
		tutulan_nesne.linear_velocity = yon
		tutulan_nesne.angular_velocity = Vector3.ZERO 

	_hedef_gosterge_guncelle()
	check_ui_text()

# --- ÖZEL EŞYA SİSTEMİ ---

func satin_al(urun_node):
	var market = get_tree().current_scene.find_child("Market", true, false)
	if market and market.has_method("satin_almaya_calis"):
		var basarili = market.satin_almaya_calis(urun_node.esya_verisi.fiyat, urun_node.esya_verisi)
		if basarili:
			esyayi_ele_al(urun_node)

func esyayi_ele_al(urun_node):
	if eldeki_ozel_esya: esya_birak()
	if tutulan_nesne: birak_veya_firlat()
	
	eldeki_ozel_esya = urun_node
	ozel_esya_verisi = urun_node.esya_verisi
	
	if eldeki_ozel_esya is RigidBody3D:
		eldeki_ozel_esya.freeze = true
		eldeki_ozel_esya.collision_layer = 0
	
	var tween = create_tween()
	eldeki_ozel_esya.reparent(tutma_noktasi)
	tween.tween_property(eldeki_ozel_esya, "position", Vector3(0.5, -0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(eldeki_ozel_esya, "rotation", Vector3(0, 0, 0), 0.3)

func esya_birak():
	if not eldeki_ozel_esya: return
	
	if eldeki_ozel_esya is RigidBody3D:
		eldeki_ozel_esya.freeze = false
		eldeki_ozel_esya.collision_layer = 1
	
	eldeki_ozel_esya.reparent(get_tree().current_scene)
	eldeki_ozel_esya.apply_impulse(Vector3(0, 2, 0), Vector3.ZERO)
	
	eldeki_ozel_esya = null
	ozel_esya_verisi = null
	
	var grid = get_tree().current_scene.find_child("GridMasa", true, false)
	if grid: grid.hedef_goster(Vector2i.ZERO, false)

func esya_kullan():
	if not eldeki_ozel_esya: return
	
	var id = ozel_esya_verisi.etki_id
	var anim_tip = ozel_esya_verisi.animasyon_tipi
	var grid = get_tree().current_scene.find_child("GridMasa", true, false)
	
	var hedef_hucre = null
	if raycast.is_colliding() and grid:
		hedef_hucre = grid.world_to_cell(raycast.get_collision_point())
	
	var basarili = false
	
	match id:
		"mantar":
			var spawner = get_tree().current_scene.find_child("BlokDagitici", true, false)
			if spawner and spawner.get("suanki_blok"):
				var blok = spawner.suanki_blok
				blok.set_meta("boyali_renk", Color.PURPLE)
				for c in blok.get_children():
					if c is MeshInstance3D:
						var mat = StandardMaterial3D.new()
						mat.albedo_color = Color.PURPLE
						c.material_override = mat
			_ekran_bozma_efekti(true)
			basarili = true

		"kilic":
			if hedef_hucre != null:
				grid.blok_dusur(hedef_hucre)
				basarili = true
		
		"firca":
			if hedef_hucre != null:
				grid.bloku_boya(hedef_hucre, Color.PURPLE) 
				basarili = true
		
		"asit":
			if hedef_hucre != null:
				grid.sutunu_yok_et(hedef_hucre)
				basarili = true
				
		"mama":
			if raycast.is_colliding():
				var collider = raycast.get_collider()
				if collider.is_in_group("Kedi"):
					print("Oyun Kaydedildi!")
					basarili = true
		
		"canlan":
			suanki_can_bari = min(suanki_can_bari + 1, max_can_bari)
			ui_guncelle()
			basarili = true

		"kumsaati":
			basarili = true
			
		_: 
			basarili = true

	if basarili:
		if grid: grid.hedef_goster(Vector2i.ZERO, false)
		_ozel_animasyon_oynat(anim_tip)
	else:
		print("Geçersiz Hedef!")

func _ozel_animasyon_oynat(tip: String):
	mouse_serbest_modu = true 
	var tween = create_tween()
	var esya = eldeki_ozel_esya
	
	# HATA ÇÖZÜMÜ: Vector3.ZERO yerine çok küçük bir değer kullanıyoruz.
	# Bu 'det == 0' hatasını engeller.
	var minik_scale = Vector3(0.01, 0.01, 0.01)

	match tip:
		"icme":
			tween.tween_property(esya, "position", Vector3(0, -0.1, 0.4), 0.3)
			tween.tween_property(esya, "rotation:x", deg_to_rad(60), 0.4).set_trans(Tween.TRANS_BACK)
			tween.tween_callback(func(): print("Lık lık..."))
			tween.tween_property(esya, "scale", minik_scale, 0.2)
			
		"yeme":
			tween.tween_property(esya, "position:z", 0.2, 0.3)
			for i in range(3):
				tween.tween_property(esya, "scale", esya.scale * 0.7, 0.1)
				tween.tween_property(esya, "rotation:z", deg_to_rad(randf_range(-20, 20)), 0.1)
			tween.tween_property(esya, "scale", minik_scale, 0.1)
			
		"kirma": 
			tween.tween_property(esya, "position:z", -1.0, 0.1).set_trans(Tween.TRANS_EXPO)
			tween.parallel().tween_property(esya, "scale:x", 0.1, 0.2)
			tween.parallel().tween_property(esya, "scale:y", 2.0, 0.2)
			tween.tween_property(esya, "modulate:a", 0.0, 0.1)
			
		"buyume": 
			tween.tween_property(esya, "scale", Vector3(2, 2, 2), 0.5).set_trans(Tween.TRANS_ELASTIC)
			tween.tween_property(esya, "rotation:y", deg_to_rad(720), 0.5)
			tween.tween_property(esya, "scale", minik_scale, 0.3)
			
		"cokme": 
			esya.reparent(get_tree().current_scene)
			tween.tween_property(esya, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE)
			tween.tween_property(esya, "scale", Vector3(1.5, 0.1, 1.5), 0.2)
			tween.tween_property(esya, "scale", minik_scale, 0.2)

	tween.tween_callback(func():
		esya.queue_free()
		eldeki_ozel_esya = null
		ozel_esya_verisi = null
		mouse_serbest_modu = false
		_ekran_bozma_efekti(false)
	)

func _hedef_gosterge_guncelle():
	if not eldeki_ozel_esya: return
	var id = ozel_esya_verisi.etki_id
	
	if id == "kilic" or id == "firca" or id == "asit":
		var grid = get_tree().current_scene.find_child("GridMasa", true, false)
		if grid and raycast.is_colliding():
			var hit = raycast.get_collision_point()
			var cell = grid.world_to_cell(hit)
			if cell != null:
				grid.hedef_goster(cell, true)
			else:
				grid.hedef_goster(Vector2i.ZERO, false)

func _ekran_bozma_efekti(aktif: bool):
	if has_node("CanvasLayer/MantarEfekti"):
		$CanvasLayer/MantarEfekti.visible = aktif

func hasar_al(miktar: int):
	if yere_dustu_mu or oldu_mu: return 
	suanki_hp -= miktar
	if suanki_hp <= 0:
		suanki_hp = 0 
		bar_kirildi() 
	ui_guncelle()

func bar_kirildi():
	yere_dustu_mu = true
	tutulan_nesne = null 
	var tween = create_tween()
	tween.parallel().tween_property(kamera, "rotation:z", deg_to_rad(80.0), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(kamera, "position:y", -0.5, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.0)
	if suanki_can_bari <= 1:
		tween.tween_callback(game_over)
	else:
		tween.tween_callback(kalkis_baslat)

func kalkis_baslat():
	var tween = create_tween()
	tween.parallel().tween_property(kamera, "rotation:z", 0.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(kamera, "position:y", 0.6, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(kamera, "rotation:x", 0.0, 1.0) 
	tween.tween_callback(_on_kalkis_tamamlandi)

func _on_kalkis_tamamlandi():
	yere_dustu_mu = false
	suanki_can_bari -= 1 
	suanki_hp = 10 
	ui_guncelle()

func game_over():
	oldu_mu = true 
	yere_dustu_mu = true 
	set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 
	oyuncu_oldu.emit() 

func ui_guncelle():
	if not ui_container: return
	var barlar = ui_container.get_children()
	for i in range(max_can_bari):
		if i >= barlar.size(): break
		var bar = barlar[i] 
		var carpi = bar.get_node_or_null("Carpi") 
		if i < suanki_can_bari - 1:
			bar.value = 10
			if carpi: carpi.visible = false
		elif i == suanki_can_bari - 1:
			bar.value = suanki_hp
			if carpi: carpi.visible = false
		else:
			bar.value = 0
			if carpi: carpi.visible = true 

func etkilesime_gir():
	if not raycast or not raycast.is_colliding(): return
	var nesne = raycast.get_collider()
	if "esya_verisi" in nesne:
		satin_al(nesne)
		return
	if nesne is RigidBody3D:
		nesne_tut(nesne)

func nesne_tut(nesne: RigidBody3D):
	tutulan_nesne = nesne
	tutulan_nesne.gravity_scale = 0.0 

func birak_veya_firlat():
	if tutulan_nesne:
		tutulan_nesne.gravity_scale = 1.0 
		tutulan_nesne.apply_central_impulse(-kamera.global_transform.basis.z * firlatma_gucu)
		tutulan_nesne = null

func check_ui_text():
	if not etkilesim_label: return
	if raycast and raycast.is_colliding():
		var nesne = raycast.get_collider()
		if nesne and "esya_verisi" in nesne:
			etkilesim_label.text = "[SOL TIK] SATIN AL\n" + nesne.esya_verisi.esya_adi + " (" + str(nesne.esya_verisi.fiyat) + ")"
		elif nesne is RigidBody3D and not tutulan_nesne:
			etkilesim_label.text = "TUT"
		else:
			etkilesim_label.text = ""
	else:
		etkilesim_label.text = ""

func toggle_mouse_mode():
	if oldu_mu: return
	mouse_serbest_modu = !mouse_serbest_modu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mouse_serbest_modu else Input.MOUSE_MODE_CAPTURED
