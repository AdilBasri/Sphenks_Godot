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

# --- ÖZEL EŞYA ---
var eldeki_ozel_esya: Node3D = null 
var ozel_esya_verisi: ItemData = null
var active_tween: Tween = null

# --- REFERANSLAR ---
@export var kamera: Camera3D 
@export var ui_container: HBoxContainer 

# Kamera Açısı Kontrolü
var x_rotasyonu: float = 0.0

var raycast: RayCast3D = null
var etkilesim_label: Label = null
var tutulan_nesne: RigidBody3D = null 
var tutma_noktasi: Node3D = null 
var mouse_serbest_modu: bool = false 

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not kamera: return
	
	# Raycast Kurulumu
	raycast = kamera.get_node_or_null("RayCast3D")
	if raycast == null:
		var yeni_ray = RayCast3D.new()
		yeni_ray.name = "RayCast3D"
		kamera.add_child(yeni_ray)
		raycast = yeni_ray
	
	raycast.enabled = true
	raycast.target_position = Vector3(0, 0, -6.0) 
	raycast.collision_mask = 0xFFFFFFFF 
	raycast.add_exception(self) 

	# Tutma Noktası
	if kamera.has_node("TutmaNoktasi"):
		tutma_noktasi = kamera.get_node("TutmaNoktasi")
	else:
		var marker = Marker3D.new()
		marker.name = "TutmaNoktasi"
		kamera.add_child(marker)
		marker.position = Vector3(0, 0, -2.5) 
		tutma_noktasi = marker

	if has_node("CanvasLayer/EtkilesimYazisi"):
		etkilesim_label = $CanvasLayer/EtkilesimYazisi
	
	# Can Senkronizasyonu (Ölümden dönünce canın full gelmesi için)
	if GameManager:
		suanki_can_bari = GameManager.oyuncu_kalan_bar
		suanki_hp = GameManager.oyuncu_suanki_hp
		
	ui_guncelle()

func _input(event):
	if not kamera or oldu_mu: return 
	if yere_dustu_mu: return 

	if event is InputEventKey and event.pressed and event.keycode == KEY_Z:
		hasar_al(1)

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		toggle_mouse_mode()

	# --- KAMERA ROTASYONU ---
	if not mouse_serbest_modu and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * mouse_sensitivity)
			var dikey_hareket = -event.relative.y * mouse_sensitivity
			x_rotasyonu += dikey_hareket
			x_rotasyonu = clamp(x_rotasyonu, deg_to_rad(-80), deg_to_rad(80))
			kamera.rotation.x = x_rotasyonu
	
	# --- TIKLAMA İŞLEMLERİ ---
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

func _hedef_gosterge_guncelle():
	var grid = get_tree().current_scene.find_child("GridYoneticisi", true, false)
	if not grid: return

	if not eldeki_ozel_esya or not ozel_esya_verisi:
		grid.hedef_goster(Vector2i.ZERO, false)
		return

	var id = ozel_esya_verisi.etki_id
	
	if id in ["asit", "kilic", "dig", "paint"]:
		if raycast.is_colliding():
			var hit_pos = raycast.get_collision_point()
			var cell = grid.world_to_cell(hit_pos)
			
			if cell != null:
				grid.hedef_goster(cell, true)
			else:
				grid.hedef_goster(Vector2i.ZERO, false)
		else:
			grid.hedef_goster(Vector2i.ZERO, false)
	else:
		grid.hedef_goster(Vector2i.ZERO, false)

# --- ESYA KULLANIMI (DÜZELTİLMİŞ) ---
func esya_kullan():
	if not eldeki_ozel_esya: return
	if active_tween and active_tween.is_running(): return

	var id = ozel_esya_verisi.etki_id
	var anim_tip = ozel_esya_verisi.animasyon_tipi
	var grid = get_tree().current_scene.find_child("GridYoneticisi", true, false)
	
	var hedef_hucre = null
	var baktigim_nesne = null
	
	if raycast.is_colliding():
		baktigim_nesne = raycast.get_collider()
		if grid:
			hedef_hucre = grid.world_to_cell(raycast.get_collision_point())
	
	var basarili = false
	
	# Debug mesajı
	print("Kullanılan Eşya ID: ", id)
	
	match id:
		"canlan": 
			if suanki_can_bari < max_can_bari:
				suanki_can_bari += 1
				suanki_hp = 10
				GameManager.saglik_guncelle(suanki_can_bari, suanki_hp)
				ui_guncelle()
				print("Can İksiri içildi!")
				basarili = true
			else:
				print("Canın zaten dolu!")
				
		"guc":
			GameManager.puan_carpani = 1.3
			print("Güç İksiri! Puanlar x1.3")
			basarili = true
			
		"revive":
			GameManager.revive_aktif = true
			print("Revive aktif!")
			basarili = true
			
		"kedimamasi":
			# Kedi Grubu Kontrolü (Güvenli)
			if baktigim_nesne and baktigim_nesne.is_in_group("kedi"):
				print("Kedi beslendi!")
				basarili = true
			else:
				print("Bu bir kedi değil!")

		"cloak": 
			if GameManager:
				GameManager.pelerin_aktif_et()
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz: arayuz.bilgi_goster("Pelerin Aktif: 3 Tur Koruma!")
				basarili = true
		"dice":
			if GameManager:
				GameManager.tek_zar_modu = true
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz: arayuz.bilgi_goster("Zar Kırıcı: Düşman Tek Zar Atacak!")
				basarili = true

		# Grid İşlemleri
		"asit": if hedef_hucre != null: grid.sutunu_yok_et(hedef_hucre); basarili = true
		"kilic": if hedef_hucre != null: grid.blok_kir(hedef_hucre, false); basarili = true
		"dig": if hedef_hucre != null: grid.blok_kir(hedef_hucre, true); basarili = true
		"paint": if hedef_hucre != null: grid.bloku_boya(hedef_hucre); basarili = true
		"mantar": if grid: grid.mantar_modu_aktif(); _ekran_bozma_efekti(true); basarili = true
		"magnet": if grid: grid.miknatis_etkisi(); basarili = true
		_: 
			print("İşlemsiz Eşya Tüketildi: ", id)
			basarili = true

	if basarili:
		if grid: grid.hedef_goster(Vector2i.ZERO, false)
		_ozel_animasyon_oynat(anim_tip)
	else:
		print("Geçersiz işlem.")

# --- DİĞER FONKSİYONLAR ---

func satin_al(urun_node):
	var market = get_tree().current_scene.find_child("Market", true, false)
	if market and market.has_method("satin_almaya_calis"):
		var veri = urun_node.get("esya_verisi")
		if not veri: return
		
		var basarili = market.satin_almaya_calis(veri.fiyat, veri)
		if basarili:
			var tween = create_tween()
			tween.tween_property(urun_node, "scale", Vector3.ZERO, 0.2)
			tween.tween_callback(urun_node.queue_free)

func esyayi_ele_al(urun_node):
	if active_tween: active_tween.kill()
	if eldeki_ozel_esya: esya_birak()
	if tutulan_nesne: birak_veya_firlat()
	
	eldeki_ozel_esya = urun_node
	ozel_esya_verisi = urun_node.get("esya_verisi")
	
	if eldeki_ozel_esya is RigidBody3D:
		eldeki_ozel_esya.freeze = true
		eldeki_ozel_esya.collision_layer = 0 
	
	eldeki_ozel_esya.reparent(tutma_noktasi)
	eldeki_ozel_esya.scale = Vector3.ONE 
	
	active_tween = create_tween()
	active_tween.tween_property(eldeki_ozel_esya, "position", Vector3(0.5, -0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK)
	active_tween.tween_property(eldeki_ozel_esya, "rotation", Vector3(0, 0, 0), 0.3)

func esya_birak():
	if active_tween: active_tween.kill()
	if not eldeki_ozel_esya: return
	
	eldeki_ozel_esya.scale = Vector3.ONE 
	if eldeki_ozel_esya is RigidBody3D:
		eldeki_ozel_esya.freeze = false
		eldeki_ozel_esya.collision_layer = 1
	
	eldeki_ozel_esya.reparent(get_tree().current_scene)
	eldeki_ozel_esya.apply_impulse(Vector3(0, 2, 0), Vector3.ZERO)
	
	eldeki_ozel_esya = null
	ozel_esya_verisi = null
	
	var grid = get_tree().current_scene.find_child("GridYoneticisi", true, false)
	if grid: grid.hedef_goster(Vector2i.ZERO, false)

func _ozel_animasyon_oynat(tip: String):
	if active_tween: active_tween.kill()
	active_tween = create_tween() 
	var esya = eldeki_ozel_esya
	var minik_scale = Vector3(0.01, 0.01, 0.01)

	var gorsel_nesne = null
	if esya:
		for child in esya.get_children():
			if child is Sprite3D:
				gorsel_nesne = child
				break

	match tip:
		"icme":
			active_tween.tween_property(esya, "position", Vector3(0, -0.1, 0.4), 0.3)
			active_tween.tween_property(esya, "rotation:x", deg_to_rad(60), 0.4).set_trans(Tween.TRANS_BACK)
			active_tween.tween_property(esya, "scale", minik_scale, 0.2)
		"kirma": 
			active_tween.tween_property(esya, "position:z", -1.0, 0.1).set_trans(Tween.TRANS_EXPO)
			if gorsel_nesne:
				active_tween.tween_property(gorsel_nesne, "modulate:a", 0.0, 0.1)
			else:
				active_tween.tween_property(esya, "scale", minik_scale, 0.1)
		_: 
			active_tween.tween_property(esya, "scale", minik_scale, 0.2)

	active_tween.tween_callback(func():
		if GameManager and ozel_esya_verisi:
			GameManager.esya_sil(ozel_esya_verisi)

		if is_instance_valid(esya): esya.queue_free()
		
		eldeki_ozel_esya = null
		ozel_esya_verisi = null
		
		# NOT: Buradaki _ekran_bozma_efekti(false) satırı bilerek kaldırıldı.
		# Mantar etkisi kalıcı olmalı, LevelManager bölüm bitince kapatacak.
	)

func _ekran_bozma_efekti(aktif: bool):
	# Arayüz grubundaki ilk elemanı bul (OyunArayuzu)
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	
	if arayuz and arayuz.has_method("mantar_efekti_yonet"):
		arayuz.mantar_efekti_yonet(aktif)
	else:
		# Bu mesaj sadece debug için, oyun içinde görünmez.
		# print("HATA: Arayüz bulunamadı veya mantar fonksiyonu yok!")
		pass

func hasar_al(miktar: int):
	if yere_dustu_mu or oldu_mu: return 
	suanki_hp -= miktar
	if suanki_hp <= 0:
		suanki_hp = 0 
		bar_kirildi() 
	if GameManager: GameManager.saglik_guncelle(suanki_can_bari, suanki_hp)
	ui_guncelle()

func bar_kirildi():
	yere_dustu_mu = true
	tutulan_nesne = null 
	var tween = create_tween()
	tween.parallel().tween_property(kamera, "rotation:z", deg_to_rad(80.0), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(kamera, "position:y", -0.5, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.0)
	if suanki_can_bari <= 1: tween.tween_callback(game_over)
	else: tween.tween_callback(kalkis_baslat)

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
	if GameManager: GameManager.saglik_guncelle(suanki_can_bari, suanki_hp)
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

func nesne_tut(nesne: RigidBody3D):
	tutulan_nesne = nesne
	tutulan_nesne.gravity_scale = 0.0 

func birak_veya_firlat():
	if tutulan_nesne:
		tutulan_nesne.gravity_scale = 1.0 
		tutulan_nesne.apply_central_impulse(-kamera.global_transform.basis.z * firlatma_gucu)
		tutulan_nesne = null

# --- HATANIN KAYNAĞI BURADAYDI VE DÜZELTİLDİ ---
func check_ui_text():
	if not etkilesim_label: return
	etkilesim_label.text = ""
	
	if raycast and raycast.is_colliding():
		var nesne = raycast.get_collider()
		
		# --- GÜVENLİK KONTROLÜ EKLENDİ ---
		if not nesne: return 
		
		var veri = nesne.get("esya_verisi")
		var market_modu = nesne.get("market_modu")
		
		if veri:
			if market_modu == true:
				etkilesim_label.text = "[SOL TIK] SATIN AL\n" + veri.esya_adi + " (" + str(veri.fiyat) + " Altın)"
			else:
				etkilesim_label.text = "[SOL TIK] AL\n" + veri.esya_adi
		
		elif nesne is RigidBody3D and not tutulan_nesne:
			etkilesim_label.text = "TUT"

# --- ETKİLEŞİME GİR (GÜVENLİ HALE GETİRİLDİ) ---
func etkilesime_gir():
	if not raycast or not raycast.is_colliding(): return
	var nesne = raycast.get_collider()
	
	if not nesne: return # Güvenlik

	var veri = nesne.get("esya_verisi")
	var market_modu = nesne.get("market_modu")
	
	if veri:
		if market_modu == true:
			satin_al(nesne)
		else:
			esyayi_ele_al(nesne)
		return

	if nesne is RigidBody3D:
		nesne_tut(nesne)

func toggle_mouse_mode():
	if oldu_mu: return
	mouse_serbest_modu = !mouse_serbest_modu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mouse_serbest_modu else Input.MOUSE_MODE_CAPTURED
