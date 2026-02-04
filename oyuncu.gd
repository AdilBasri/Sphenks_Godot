extends CharacterBody3D

# --- AYARLAR ---
var speed = 5.0
var mouse_sensitivity = 0.003
var gravity = 9.8
var firlatma_gucu = 8.0 

# --- CAN SİSTEMİ AYARLARI ---
var max_can_bari = 4        # Toplam ana bar sayısı
var suanki_can_bari = 4     # Şu an kaç barımız var?
var bar_hp = 10             # Her barın içindeki parça sayısı
var suanki_hp = 10          # Şu anki barın doluluk oranı

var yere_dustu_mu: bool = false # Hareket kilidi için

# --- REFERANSLAR ---
# Inspector'dan atanacaklar:
@export var kamera: Camera3D 
# AnimPlayer artık GEREKSİZ, kodla yapıyoruz.
@export var ui_container: HBoxContainer  # UI'daki Barların Kutusu

# Kodun içinde doldurulacaklar:
var raycast: RayCast3D = null
var etkilesim_label: Label = null
var tutulan_nesne: RigidBody3D = null 
var tutma_noktasi: Node3D = null 
var mouse_serbest_modu: bool = false 

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# --- HATA KONTROLLERİ ---
	if not kamera:
		print("🔴 HATA: Lütfen Inspector'dan 'Kamera'yı ata!")
		return
	if not ui_container:
		print("🔴 UYARI: Inspector'dan 'UI Container' atanmamış!")

	# --- 1. RAYCAST KURULUMU ---
	raycast = kamera.get_node_or_null("RayCast3D")
	if raycast == null:
		var yeni_ray = RayCast3D.new()
		yeni_ray.name = "RayCast3D"
		kamera.add_child(yeni_ray)
		raycast = yeni_ray

	raycast.enabled = true
	raycast.target_position = Vector3(0, 0, -4.0)
	raycast.collision_mask = 0xFFFFFFFF 
	
	# 🔥 FPS DROP ÇÖZÜMÜ 1: RayCast'in oyuncunun kendisine çarpmasını engelle
	raycast.add_exception(self)

	# --- 2. TUTMA NOKTASI KURULUMU ---
	if kamera.has_node("TutmaNoktasi"):
		tutma_noktasi = kamera.get_node("TutmaNoktasi")
	else:
		var marker = Marker3D.new()
		marker.name = "TutmaNoktasi"
		marker.position = Vector3(0, 0, -2.5) 
		kamera.add_child(marker)
		tutma_noktasi = marker

	# --- 3. UI LABEL BULMA ---
	if has_node("CanvasLayer/EtkilesimYazisi"):
		etkilesim_label = $CanvasLayer/EtkilesimYazisi
		
	# --- 4. BAŞLANGIÇ GÜNCELLEMELERİ ---
	ui_guncelle()

func _input(event):
	if not kamera: return 
	if yere_dustu_mu: return # Düşersek mouse ve hareket kilitlenir

	# --- TEST TUŞU: Z (Hasar Alma) ---
	if event is InputEventKey and event.pressed and event.keycode == KEY_Z:
		hasar_al(1) # Test için 1 hasar ver

	# --- SPACE TUŞU ---
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		toggle_mouse_mode()

	# --- MOUSE HAREKETİ ---
	if not mouse_serbest_modu:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)
			# Kamerayı döndürürken yere_dustu_mu kontrolü yapılmalı
			# Eğer düşüyorsak kamera kontrolünü tween'e bırakıyoruz
			if not yere_dustu_mu:
				kamera.rotate_x(-event.relative.y * mouse_sensitivity)
				kamera.rotation.x = clamp(kamera.rotation.x, -1.2, 1.2)
	
	# --- TIKLAMA ---
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if tutulan_nesne:
			birak_veya_firlat()
		else:
			etkilesime_gir()

func _physics_process(delta):
	# Eğer düştüysek fiziksel hareket durur
	if yere_dustu_mu: return

	if not is_on_floor():
		velocity.y -= gravity * delta

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

	check_ui_text()

# --- CAN VE HASAR SİSTEMİ ---

func hasar_al(miktar: int):
	if yere_dustu_mu: return 
	
	suanki_hp -= miktar
	print("Hasar alındı! Şu anki Barda Kalan HP: " + str(suanki_hp))
	
	if suanki_hp <= 0:
		suanki_hp = 0 
		bar_kirildi() 
	
	ui_guncelle()

func bar_kirildi():
	yere_dustu_mu = true
	tutulan_nesne = null 
	
	print("BAR KIRILDI! Tween ile düşülüyor...")
	
	# --- KODLA DÜŞME ANİMASYONU (TWEEN) ---
	# AnimationPlayer yerine bunu kullanıyoruz.
	var tween = create_tween()
	
	# 1. Yere Çakılma (Z ekseninde yan yat + Y ekseninde yere in)
	tween.parallel().tween_property(kamera, "rotation:z", deg_to_rad(80.0), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(kamera, "position:y", -0.5, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# 2. Yerde 2 saniye baygın kal
	tween.tween_interval(2.0)
	
	# 3. Kalkışı başlat
	tween.tween_callback(kalkis_baslat)

func kalkis_baslat():
	print("Ayılıyor...")
	var tween = create_tween()
	
	# Kamerayı eski haline getir (Sıfırla)
	# Başlangıç Y pozisyonu genelde 0.6 veya 0.0'dır (Sahne ayarına göre değişir, 0 yapıyoruz)
	tween.parallel().tween_property(kamera, "rotation:z", 0.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(kamera, "position:y", 0.6, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(kamera, "rotation:x", 0.0, 1.0) # Kafayı da düzelt
	
	# İşlem bitince sistemi resetle
	tween.tween_callback(_on_kalkis_tamamlandi)

func _on_kalkis_tamamlandi():
	print("Kalktık ama o bar artık çöp!")
	
	yere_dustu_mu = false
	suanki_can_bari -= 1 
	suanki_hp = 10 
	
	if suanki_can_bari <= 0:
		game_over()
	
	ui_guncelle()

func ui_guncelle():
	if not ui_container: return
	
	var barlar = ui_container.get_children()
	
	for i in range(max_can_bari):
		if i >= barlar.size(): break
		
		var bar = barlar[i] 
		var carpi_resmi = bar.get_node_or_null("Carpi") 
		
		if i < suanki_can_bari - 1:
			bar.value = 10
			if carpi_resmi: carpi_resmi.visible = false
			
		elif i == suanki_can_bari - 1:
			bar.value = suanki_hp
			if carpi_resmi: carpi_resmi.visible = false
			
		else:
			bar.value = 0
			if carpi_resmi: carpi_resmi.visible = true 

func game_over():
	print("OYUN BİTTİ - ÖLDÜN!")
	set_physics_process(false) 

# --- DİĞER FONKSİYONLAR ---
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

func satin_al(urun):
	var market_node = get_tree().current_scene.find_child("Market", true, false)
	if market_node and market_node.has_method("satin_almaya_calis"):
		var basarili = market_node.satin_almaya_calis(urun.esya_verisi.fiyat, urun.esya_verisi)
		if basarili:
			var tween = create_tween()
			# 🔥 FPS DROP ÇÖZÜMÜ 2: 
			# Sıfıra (Vector3.ZERO) değil, çok küçüğe (0.01) düşürüyoruz.
			tween.tween_property(urun, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
			tween.tween_callback(urun.queue_free)

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
	mouse_serbest_modu = !mouse_serbest_modu
	if mouse_serbest_modu:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
