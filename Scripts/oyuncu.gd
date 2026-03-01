extends CharacterBody3D

# --- SİNYALLER ---
signal oyuncu_oldu 

# --- AYARLAR ---
var speed = 3.0
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

# --- SİLAH VE DURUM KONTROLÜ ---
var weapon_input_disabled: bool = false
var state: String = "Normal"

# --- ÖZEL EŞYA ---
var eldeki_ozel_esya: Node3D = null 
var eldeki_kedi: Node3D = null
var ozel_esya_verisi: ItemData = null
var active_tween: Tween = null

# --- REFERANSLAR ---
@export var kamera: Camera3D 
@export var ui_container: HBoxContainer 

# --- GORE UI REFERANSLARI (Inspector'dan sürükle-bırak) ---
@export var gore_vignette: ColorRect  ## CanvasLayer altındaki GoreVignette
@export var mide_ui_container: SubViewportContainer  ## Mide UI container (opsiyonel)

# Kamera Açısı Kontrolü
var x_rotasyonu: float = 0.0

var raycast: RayCast3D = null
var etkilesim_label: Label = null
var tutulan_nesne: RigidBody3D = null 
var tutma_noktasi: Node3D = null 
var mouse_serbest_modu: bool = false 

# --- YEME MEKANİĞİ (Violent Bite System) ---
var is_eating: bool = false
var eating_tween: Tween = null
var bite_timer: Timer = null
var bite_interval: float = 0.6  # Her ısırık arası süre (saniye)
var kan_spreyi_sahne = preload("res://Scenes/KanSpreyi.tscn")

# Kamera Travması
var trauma: float = 0.0            # 0-1 arası, her ısırıkta artar
var trauma_decay: float = 2.5       # Saniyede ne kadar azalır
var max_shake_offset: float = 0.015 # Maksimum piksel kayması
var max_shake_rotation: float = 0.02 # Maks rotasyon (radyan)

# FOV Tünel Vizyonu
var orijinal_fov: float = 75.0
var min_fov: float = 50.0  # En dar tünel vizyonu

# TODO: Ses dosyaları eklenince yorumları kaldır
# var ses_koparma = preload("res://Flesh_Tear.ogg")
# var ses_cignemek = preload("res://Crunch.ogg")
# var ses_yutmak = preload("res://Swallow.ogg")
# var ses_sivi = preload("res://Liquid_Squish.ogg")

var is_sitting: bool = false
var current_stool: Node3D = null
var original_camera_transform: Transform3D
var table_camera_offset: float = 0.0

# --- JOYPAD DEBOUNCE DEGISKENLERI ---
var _rt_basildi = false
var _lt_basildi = false

# --- QTE ANTI-SPAM DEGISKENI ---
var son_sag_tik_zamani: float = 0.0

# --- SES ---
var walking_player: AudioStreamPlayer

func _ready():
	walking_player = AudioStreamPlayer.new()
	var w_stream = load("res://Sesler/walking.mp3")
	if w_stream and "loop" in w_stream: w_stream.loop = true
	walking_player.stream = w_stream
	walking_player.bus = "Master"
	add_child(walking_player)
	
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
	# GoreVignette'yi ayrı bir düşük layer'lı CanvasLayer'a taşı
	# Böylece MideUI'nın (layer=1) altında render edilir — köşeyi kapatmaz
	call_deferred("_gore_vignette_katmana_tasi")
	# GoreVignette: bir frame sonra kalıcı intensity uygula (node'lar hazır olsun)
	call_deferred("_gore_kalici_intensity_uygula")
	
	if gore_vignette:
		gore_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event):
	if not kamera or oldu_mu: return 
	if yere_dustu_mu: return 

	# --- YEME INPUT ---
	if event.is_action_pressed("uzuv_ye"):
		if not is_eating and tutulan_nesne and tutulan_nesne.is_in_group("KopanUzuv"):
			yeme_baslat()
			return
	elif event.is_action_released("uzuv_ye"):
		if is_eating:
			yeme_iptal()
			return
	
	# Yeme sırasında tüm diğer inputları engelle
	if is_eating: return

	if event is InputEventKey and event.pressed and event.keycode == KEY_Z:
		hasar_al(1)

	# SPACE TUŞU İPTAL EDİLDİ - ARTIK TABURE SİSTEMİ VAR
	if event.is_action_pressed("etkilesim"):
		if is_sitting:
			stand_up()
		else:
			etkilesime_gir(false)
			
	if event.is_action_pressed("kosma"):
		speed = 5.25
	elif event.is_action_released("kosma"):
		speed = 3.0
			
	if event.is_action_pressed("sag_tik"):
		if GameManager and GameManager.is_parry_window_open:
			var boss = get_tree().get_first_node_in_group("Dusman")
			if boss and boss.has_method("glitch_yuzu_kapat"):
				boss.glitch_yuzu_kapat()
			GameManager.activate_ghost_move()
			
			if TutorialManager:
				TutorialManager.eylemi_dogrula("parry")
			return
			
	if is_sitting:
		# Analog 'axis' değerleri sürekli tetiklendiğinden, manuel debounce (tek tıklama) uygulayalım
		var lt_deger = Input.get_action_strength("masa_don_sol")
		var rt_deger = Input.get_action_strength("masa_don_sag")
		
		var lt_aktif = lt_deger > 0.5
		var rt_aktif = rt_deger > 0.5
		
		if lt_aktif and not _lt_basildi:
			_lt_basildi = true
			move_table_camera(-1.0)
		elif not lt_aktif:
			_lt_basildi = false
			
		if rt_aktif and not _rt_basildi:
			_rt_basildi = true
			move_table_camera(1.0)
		elif not rt_aktif:
			_rt_basildi = false
			
		return # Otururken diğer inputları (mouse look vs) engelle

	# --- KAMERA ROTASYONU ---
	if not mouse_serbest_modu and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if active_tween and active_tween.is_valid() and active_tween.is_running(): return
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * mouse_sensitivity)
			var dikey_hareket = -event.relative.y * mouse_sensitivity
			x_rotasyonu += dikey_hareket
			x_rotasyonu = clamp(x_rotasyonu, deg_to_rad(-80), deg_to_rad(80))
			kamera.rotation.x = x_rotasyonu
	
	# --- TIKLAMA İŞLEMLERİ ---
	if event.is_action_pressed("sol_tik"):
		# VIRTUAL MOUSE TIKLAMA SIMULASYONU (Sürükle-bırak için OS seviyesinde basılı tutma)
		if mouse_serbest_modu:
			var mouse_event = InputEventMouseButton.new()
			mouse_event.button_index = MOUSE_BUTTON_LEFT
			mouse_event.pressed = true
			var ms_pos = get_viewport().get_mouse_position()
			mouse_event.position = ms_pos
			mouse_event.global_position = ms_pos
			Input.parse_input_event(mouse_event)
			
		if eldeki_kedi:
			kedi_birak()
		elif eldeki_ozel_esya:
			esya_kullan()
		elif tutulan_nesne:
			birak_veya_firlat()
		else:
			etkilesime_gir(true)
			
	elif event.is_action_released("sol_tik") and mouse_serbest_modu:
		# VIRTUAL MOUSE BIRAKMA SIMULASYONU
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.pressed = false
		var ms_pos = get_viewport().get_mouse_position()
		mouse_event.position = ms_pos
		mouse_event.global_position = ms_pos
		Input.parse_input_event(mouse_event)
	
	elif event.is_action_pressed("sag_tik"):
		var anlik_zaman = Time.get_ticks_msec() / 1000.0
		if (anlik_zaman - son_sag_tik_zamani) >= 0.4:
			son_sag_tik_zamani = anlik_zaman
			if eldeki_ozel_esya:
				esya_birak()

func _physics_process(delta):
	if yere_dustu_mu or oldu_mu: return
	
	# --- YEME SIRASINDA HAREKET KİLİTLE + TRAVMA DECAY ---
	if is_eating:
		velocity = Vector3.ZERO
		move_and_slide()
		_travma_guncelle(delta)
		# Tutma noktası fizik güncellemesi (limb pozisyonu)
		if tutulan_nesne and tutma_noktasi:
			var hedef_pos = tutma_noktasi.global_position
			var nesne_pos = tutulan_nesne.global_position
			var yon = (hedef_pos - nesne_pos) * 15.0
			tutulan_nesne.linear_velocity = yon
			tutulan_nesne.angular_velocity = Vector3.ZERO
		return
	
	if is_sitting: return # Otururken hareket etme

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
	
	if is_on_floor() and direction.length_squared() > 0.01 and not is_sitting:
		if not walking_player.playing:
			walking_player.play()
	else:
		if walking_player.playing:
			walking_player.stop()
	
	# --- JOYPAD KAMERA KONTROLU (Sürekli) ---
	var cam_dir = Input.get_vector("kamera_sol", "kamera_sag", "kamera_yukari", "kamera_asagi")
	if cam_dir.length_squared() > 0.01:
		if not mouse_serbest_modu:
			var joy_sens = 2.5 * delta # Gamepad FPS hassasiyeti (ayarlanabilir)
			rotate_y(-cam_dir.x * joy_sens)
			x_rotasyonu += -cam_dir.y * joy_sens
			x_rotasyonu = clamp(x_rotasyonu, deg_to_rad(-80), deg_to_rad(80))
			if kamera: kamera.rotation.x = x_rotasyonu
		else:
			# VIRTUAL MOUSE (Masa modunda sağ analog imleci kaydırır)
			var cursor_speed = 750.0 * delta # Gamepad imlec hizi
			var viewport = get_viewport()
			var current_mouse = viewport.get_mouse_position()
			var new_mouse = current_mouse + (cam_dir * cursor_speed)
			
			# Imleci ekranda sinirla (Isletim sistemi Taskbar'ina deymesini engellemek icin 20px margin)
			var screen_size = viewport.get_visible_rect().size
			new_mouse.x = clamp(new_mouse.x, 20, screen_size.x - 20)
			new_mouse.y = clamp(new_mouse.y, 20, screen_size.y - 20)
			
			viewport.warp_mouse(new_mouse)
	
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
	var kedi_bulundu = false # <--- YENİ KONTROL
	
	if raycast.is_colliding():
		baktigim_nesne = raycast.get_collider()
		if grid: hedef_hucre = grid.world_to_cell(raycast.get_collision_point())
		
		# --- YENİ: HEM NESNEYE HEM BABASINA BAK ---
		if baktigim_nesne:
			if baktigim_nesne.is_in_group("Kedi"):
				kedi_bulundu = true
			elif baktigim_nesne.get_parent() and baktigim_nesne.get_parent().is_in_group("Kedi"):
				kedi_bulundu = true
		# ------------------------------------------
	
	var basarili = false
	print("Kullanılan Eşya ID: ", id)
	
	match id:
		"dice": 
			if GameManager:
				GameManager.tek_zar_modu = true
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz: arayuz.bilgi_goster("Zar Kırıcı: Düşman Tek Zar Atacak!")
				basarili = true

		"cloak": 
			if GameManager:
				GameManager.pelerin_aktif_et()
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz: arayuz.bilgi_goster("Pelerin Aktif: 3 Tur Koruma!")
				basarili = true

		"kedimamasi":
			# --- GÜNCELLENMİŞ KEDİ KONTROLÜ ---
			if kedi_bulundu:
				if GameManager:
					# Kamp odasında kedi beslenerek kaydedildiğinde aşama geçilmiştir.
					# Bu yüzden oyuncu geri döndüğünde bir sonraki aşamayı oynamalı.
					var aktif_seviye = GameManager.suanki_seviye
					
					if LevelManager:
						GameManager.suanki_seviye = LevelManager.suanki_katman
					
					GameManager.oyunu_kaydet()
					
					# Kayıttan sonra oyun esnasında bug olmaması için eski haline al
					GameManager.suanki_seviye = aktif_seviye
					
					var arayuz = get_tree().get_first_node_in_group("Arayuz")
					if arayuz: arayuz.bilgi_goster("Kedi Beslendi! Oyun Kaydedildi.")
					print("😺 Kedi beslendi ve oyun kaydedildi!")
					basarili = true
			else:
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz: arayuz.bilgi_goster("Bunu sadece Kedi yiyebilir!")
				print("❌ Bu bir kedi değil!")

		"canlan": 
			if suanki_can_bari < max_can_bari:
				suanki_can_bari += 1
				suanki_hp = 10
				GameManager.saglik_guncelle(suanki_can_bari, suanki_hp)
				ui_guncelle()
				basarili = true
		"guc":
			if GameManager:
				GameManager.puan_carpani = 1.3
				
				# --- BURASI DEĞİŞTİ: Daha havalı bilgilendirme ---
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz: 
					# Ekranda 3 saniye kalacak net bir mesaj
					arayuz.bilgi_goster("🧪 GÜÇ İKSİRİ İÇİLDİ! (Puanlar x1.3)", 3.0)
				
				print("💪 Güç İksiri Aktif: Çarpan 1.3 oldu.")
				basarili = true
		"revive":
			if GameManager:
				GameManager.revive_aktif = true
				
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz: 
					arayuz.bilgi_goster("😇 REVIVE AKTİF! (Ölürsen Canlanırsın)", 3.0)
					
				print("😇 Revive İksiri İçildi: Ölümden koruyacak.")
				basarili = true
		"fener":
			if GameManager:
				GameManager.fener_aktif = true
				
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz: 
					arayuz.bilgi_goster("🔦 FENER AÇILDI! (Yarasalar Dondu)", 3.0)
					
				print("🔦 Fener Aktif: Düşmanlar sabitlendi.")
				basarili = true
		"kumsaati":
			if GameManager:
				GameManager.pyro_yavaslatma = true
				
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz: 
					arayuz.bilgi_goster("⏳ ZAMAN YAVAŞLADI! (Düşmanlar %50 Yavaş)", 3.0)
					
				print("⏳ Zaman Bükülmesi Aktif: Düşmanlar yavaşladı.")
				basarili = true
		"asit": if hedef_hucre != null: grid.sutunu_yok_et(hedef_hucre); basarili = true
		"kilic": if hedef_hucre != null: grid.blok_kir(hedef_hucre, false); basarili = true
		"dig": if hedef_hucre != null: grid.blok_kir(hedef_hucre, true); basarili = true
		"paint": if hedef_hucre != null: grid.bloku_boya(hedef_hucre); basarili = true
		"mantar": 
			if grid: 
				grid.mantar_modu_aktif()
				_ekran_bozma_efekti(true)
				basarili = true
				if TutorialManager: TutorialManager.eylemi_dogrula("mantar_yeme")
		"magnet": if grid: grid.miknatis_etkisi(); basarili = true
		"curuk_temel":
			if grid:
				# Tüm kilitli hücreleri temizle
				var kilitli_kopya = grid.kilitli_hucreler.duplicate()
				for hucre in kilitli_kopya.keys():
					grid.kilit_kir(hucre)
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz: arayuz.bilgi_goster("🪧 Çürük Temel: Grid temizlendi!", 3.0)
				print("🪧 Çürük Temel kullanıldı, grid temizlendi.")
				basarili = true
		_: print("Tanımsız Eşya: ", id); basarili = true

	if basarili:
		if grid: grid.hedef_goster(Vector2i.ZERO, false)
		_ozel_animasyon_oynat(anim_tip)

func satin_al(urun_node):
	var market = get_tree().current_scene.find_child("Market", true, false)
	if market and market.has_method("satin_almaya_calis"):
		var veri = urun_node.get("esya_verisi")
		if not veri: return
		
		var basarili = market.satin_almaya_calis(veri.fiyat, veri)
		if basarili:
			var sfx = AudioStreamPlayer.new()
			sfx.stream = load("res://Sesler/buy.mp3")
			sfx.bus = "Master"
			get_tree().current_scene.add_child(sfx)
			sfx.play()
			sfx.finished.connect(sfx.queue_free)
			
			var tween = create_tween()
			tween.tween_property(urun_node, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
			tween.tween_callback(urun_node.queue_free)

func esyayi_ele_al(urun_node):
	if active_tween: active_tween.kill()
	if eldeki_ozel_esya: esya_birak()
	if tutulan_nesne: birak_veya_firlat()
	
	eldeki_ozel_esya = urun_node
	ozel_esya_verisi = urun_node.get("esya_verisi")
	
	var h_sfx = AudioStreamPlayer.new()
	h_sfx.stream = load("res://Sesler/handing_item.mp3")
	h_sfx.bus = "Master"
	get_tree().current_scene.add_child(h_sfx)
	h_sfx.play()
	h_sfx.finished.connect(h_sfx.queue_free)
	
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
			GameManager.envanter.erase(ozel_esya_verisi)
			GameManager.envanter_guncellendi.emit()

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
	
	# Yere Düşme Animasyonu
	var tween = create_tween()
	tween.parallel().tween_property(kamera, "rotation:z", deg_to_rad(80.0), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(kamera, "position:y", -0.5, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Yerde biraz bekle (Dramatik an)
	tween.tween_interval(2.0)
	
	# --- KRİTİK REVIVE KONTROLÜ ---
	if suanki_can_bari <= 1:
		# Son can barı kırıldı, normalde ölürüz. AMA:
		if GameManager and GameManager.revive_aktif:
			# Revive varsa ölümü iptal et ve kaldır
			tween.tween_callback(_revive_ile_kalkis)
		else:
			# Revive yoksa oyun biter
			tween.tween_callback(game_over)
	else:
		# Daha can barımız varsa normal kalkış
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
	if GameManager: GameManager.saglik_guncelle(suanki_can_bari, suanki_hp)
	ui_guncelle()

func game_over():
	oldu_mu = true 
	yere_dustu_mu = true 
	set_physics_process(false)
	# Clear held items so they don't float during scene transition
	if tutulan_nesne: birak_veya_firlat()
	if eldeki_ozel_esya: esya_birak()
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
	# Donmuş nesneyi çöz (KopanUzuv yere düşünce freeze oluyor)
	if nesne.freeze:
		nesne.freeze = false
	
	# Özel tutuldu metodu varsa çağır (KopanUzuv vb.)
	if nesne.has_method("tutuldu"):
		nesne.tutuldu()
	else:
		nesne.gravity_scale = 0.0
	
	tutulan_nesne = nesne

func birak_veya_firlat():
	if tutulan_nesne:
		# Özel bırakıldı metodu varsa çağır
		if tutulan_nesne.has_method("birakildi"):
			tutulan_nesne.birakildi()
		else:
			tutulan_nesne.gravity_scale = 1.0
		
		tutulan_nesne.apply_central_impulse(-kamera.global_transform.basis.z * firlatma_gucu)
		tutulan_nesne = null

func hide_weapon():
	weapon_input_disabled = true
	var silah = get_tree().get_first_node_in_group("SilahKatmani")
	if not silah:
		silah = get_tree().current_scene.find_child("SilahKatmani", true, false)
	if silah: 
		silah.visible = false
		silah.process_mode = Node.PROCESS_MODE_DISABLED
	
	var revolver = get_tree().get_first_node_in_group("Arayuz")
	if revolver:
		if revolver.has_method("_silahi_kaldir"):
			revolver._silahi_kaldir()
		# Forcing the Revolver Canvas layer to explicitly hide its nested elements
		var nisangah = revolver.get_node_or_null("Nisangah")
		if nisangah: nisangah.hide()

func unequip_weapons():
	hide_weapon()

# --- OYUNCU.GD GÜNCEL ETKİLEŞİM SİSTEMİ (DÜZELTİLMİŞ) ---
func check_ui_text():
	if not etkilesim_label: return
	etkilesim_label.text = ""
	
	if eldeki_kedi:
		etkilesim_label.text = "[SOL TIK] Kediyi Bırak"
		return
	
	if raycast and raycast.is_colliding():
		var nesne = raycast.get_collider()
		if not nesne: return 
		
		# 1. MARKET EŞYASI KONTROLÜ
		var veri = nesne.get("esya_verisi")
		var market_modu = nesne.get("market_modu")
		
		if veri:
			if market_modu == true:
				etkilesim_label.text = DilYoneticisi.metin_al("satin_al") % [veri.esya_adi, veri.fiyat]
			else:
				etkilesim_label.text = DilYoneticisi.metin_al("al") % [veri.esya_adi]
			return

		# 2. KEDİ KONTROLÜ
		if nesne.is_in_group("Kedi") or (nesne.get_parent() and nesne.get_parent().is_in_group("Kedi")):
			var dist = kamera.global_position.distance_to(raycast.get_collision_point())
			if dist <= 2.5:
				etkilesim_label.text = "[SOL TIK] Kediyi Eline Al"
			return

		# 3. INTERACT METODU KONTROLÜ (Gelişmiş Arama)
		var bulunan_etkilesim = _bul_etkilesim_nesnesi(nesne)
		
		if bulunan_etkilesim:
			# KAPI İSE FARKLI YAZI
			if "Kapi" in bulunan_etkilesim.name or "Door" in bulunan_etkilesim.name or bulunan_etkilesim.has_method("kapiyi_ac"):
				# KAPI KİLİTLİYSE VEYA KARTLAR SEÇİLMEDİYSE ETKİLEŞİM YAZMA
				if bulunan_etkilesim.get("kilitli_mi") == true:
					return
				if bulunan_etkilesim.get("hedef_tipi") == 1: # SONRAKI_LEVEL
					var cf = null
					if "Campfire" in get_tree().current_scene.name:
						cf = get_tree().current_scene
					else:
						cf = get_tree().current_scene.find_child("*Campfire*", true, false)
					
					if cf and "cards_resolved" in cf and not cf.cards_resolved:
						return
				
				etkilesim_label.text = DilYoneticisi.metin_al("kapiyi_ac")
			# TABURE VEYA DİĞERLERİ
			else:
				if bulunan_etkilesim.has_method("get_etkilesim_yazisi"):
					etkilesim_label.text = bulunan_etkilesim.get_etkilesim_yazisi()
				else:
					etkilesim_label.text = DilYoneticisi.metin_al("oynamak_icin_otur")
			return
		
		# SANDIK ODASI: E ETKİLEŞİM KONTROLU
		if nesne.is_in_group("SandikGrubu"):
			var sandik_yoneticisi = get_tree().current_scene.get_node_or_null("Sandik_Odasi")
			if not sandik_yoneticisi:
				sandik_yoneticisi = get_tree().current_scene
			if sandik_yoneticisi and "acilan_sandiklar" in sandik_yoneticisi:
				var sandik = sandik_yoneticisi._sandik_bul(nesne) if sandik_yoneticisi.has_method("_sandik_bul") else null
				if sandik and sandik.name not in sandik_yoneticisi.acilan_sandiklar:
					etkilesim_label.text = "(E) Etkilesim"
					return
		
		# 3. KART SEÇİMİ VEYA FİZİKSEL NESNE TUTMA
		if nesne.is_in_group("CampfireKart"):
			var ad = nesne.get_parent().name
			if "Gold" in ad:
				etkilesim_label.text = "[E] Altın Kart"
			else:
				etkilesim_label.text = "[E] Uyku Kartı"
			return
			
		if nesne is RigidBody3D and not tutulan_nesne:
			etkilesim_label.text = DilYoneticisi.metin_al("tut")

# --- ETKİLEŞİME GİR ---
func etkilesime_gir(is_mouse_click: bool = false):
	if not raycast or not raycast.is_colliding(): return
	var nesne = raycast.get_collider()
	if not nesne: return

	var veri = nesne.get("esya_verisi")
	var market_modu = nesne.get("market_modu")
	
	if veri:
		if market_modu == true:
			satin_al(nesne)
		else:
			esyayi_ele_al(nesne)
		return

	if nesne.is_in_group("CampfireKart"):
		var campfire = nesne.get_parent().get_parent()
		if campfire and campfire.has_method("_kart_secildi"):
			campfire._kart_secildi(nesne.get_parent())
			return
			
	if nesne.is_in_group("Kedi") or (nesne.get_parent() and nesne.get_parent().is_in_group("Kedi")):
		if is_mouse_click:
			var dist = kamera.global_position.distance_to(raycast.get_collision_point())
			if dist <= 2.5:
				var asil_kedi = nesne if nesne.is_in_group("Kedi") else nesne.get_parent()
				kedi_al(asil_kedi)
		return
			
	# Gelişmiş Arama ile Bul
	var bulunan_etkilesim = _bul_etkilesim_nesnesi(nesne)
	
	if bulunan_etkilesim:
		if bulunan_etkilesim.get("kilitli_mi") == true:
			return
		if bulunan_etkilesim.has_method("kapiyi_ac") and bulunan_etkilesim.get("hedef_tipi") == 1:
			var cf = null
			if "Campfire" in get_tree().current_scene.name:
				cf = get_tree().current_scene
			else:
				cf = get_tree().current_scene.find_child("*Campfire*", true, false)
			
			if cf and "cards_resolved" in cf and not cf.cards_resolved:
				return
		bulunan_etkilesim.interact(self)
		return

	# SANDIK ODASI: E tuşu ile sandık aç
	if nesne.is_in_group("SandikGrubu"):
		var sandik_yoneticisi = get_tree().current_scene.get_node_or_null("Sandik_Odasi")
		if sandik_yoneticisi and sandik_yoneticisi.has_method("sandik_ac"):
			var sandik = sandik_yoneticisi._sandik_bul(nesne) if sandik_yoneticisi.has_method("_sandik_bul") else null
			if sandik:
				sandik_yoneticisi.sandik_ac(sandik)
		return

	if nesne is RigidBody3D:
		nesne_tut(nesne)


func kedi_al(kedi: Node3D):
	eldeki_kedi = kedi
	if kedi.has_method("yakala"):
		kedi.yakala()

func kedi_birak():
	if not eldeki_kedi: return
	
	var max_mesafe = 2.5
	var yon = -kamera.global_transform.basis.z
	var hedef = kamera.global_position + yon * max_mesafe
	
	if raycast and raycast.is_colliding():
		var hit_pos = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()
		var dist = kamera.global_position.distance_to(hit_pos)
		
		if dist <= max_mesafe:
			# Duvarın veya eşyanın içine girmemesi için normal yönünde daha fazla geri çek
			hedef = hit_pos + (normal * 0.45)
	
	if eldeki_kedi.has_method("birak"):
		eldeki_kedi.birak(hedef)
	
	eldeki_kedi = null

# --- YARDIMCI: ETKİLEŞİME GİRİLECEK NESNEYİ BUL ---
# Raycast collider'ı bazen child (StaticBody) olabilir.
# Script ise parent (KapiSistemi) üzerinde olabilir.
# Bu fonksiyon yukarı doğru 3 basamak arar.
func _bul_etkilesim_nesnesi(baslangic_node):
	var suanki = baslangic_node
	for i in range(4): # Kendisi + 3 üst ebeveyn
		if not suanki: break
		if suanki.has_method("interact"):
			return suanki
		suanki = suanki.get_parent()
	return null

var table_angle_index: int = 0 # 0=Front, 1=Right, 2=Back, 3=Left

func sit_on_stool(stool_node):
	if is_sitting: return
	
	is_sitting = true
	current_stool = stool_node
	
	# BAŞLANGIÇ AÇISINI BUL (Kullanıcı tabureyi çevirmiş olabilir)
	# Taburenin merkeze (0,0,0) göre nerede olduğuna bakalım.
	var stool_pos = current_stool.global_position
	# En büyük bileşene göre kaba yön tayini (X+, X-, Z+, Z-)
	if abs(stool_pos.x) > abs(stool_pos.z):
		# X ekseninde dominant
		if stool_pos.x > 0: table_angle_index = 0 # X+ (Ön)
		else: table_angle_index = 2 # X- (Arka)
	else:
		# Z ekseninde dominant
		if stool_pos.z > 0: table_angle_index = 1 # Z+ (Sağ)
		else: table_angle_index = 3 # Z- (Sol)
	
	print("🪑 Başlangıç Indexi Bulundu: ", table_angle_index)
	
	# Mouse'u serbest bırak ki gridle etkileşime girsin
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_serbest_modu = true
	
	# Kamera Pozisyonunu Kaydet
	original_camera_transform = kamera.global_transform
	
	# Orbit Kamerasını Başlat (Anında geçiş yapsın, tweensiz de olabilir ama tween güzel)
	_update_orbit_camera()
	
	# UI GÜNCELLEME: [E] Kalk (Üstte, Küçük)
	# UI GÜNCELLEME: [E] Kalk (Üstte, Ortada)
	if etkilesim_label:
		etkilesim_label.text = DilYoneticisi.metin_al("kalk")
		# Anchor Top-Center
		etkilesim_label.anchor_top = 0.05
		etkilesim_label.anchor_bottom = 0.05
		etkilesim_label.anchor_left = 0.5
		etkilesim_label.anchor_right = 0.5
		etkilesim_label.horizontal_alignment = 1 # CENTER
		
		# Font küçültme (Scale ile hile yapıyoruz veya settings varsa oradan)
		etkilesim_label.scale = Vector2(0.7, 0.7)
		# Scale kullandığımız için pivotu da ortalamamız gerekebilir ama Label center align ise genelde sorun olmaz.
		# Garanti olması için offsetleri sıfırlayalım ki anchor center'dan taşmasın.
		etkilesim_label.offset_left = -50 # Tahmini genişlik yarısı
		etkilesim_label.offset_right = 50
	
	# Blok Dağıtıcısını Başlat (Eğer başlamadıysa)
	var spawner = get_tree().current_scene.find_child("BlokDagiticisi", true, false)
	if spawner:
		if spawner.has_method("baslat_spawn_dongusu"):
			spawner.baslat_spawn_dongusu()
		elif spawner.has_method("bloklari_goster"):
			spawner.bloklari_goster()
	else:
		# Fallback: Eğer obje direkt name ile bulunamazsa (veya grup varsa)
		get_tree().call_group("Spawner", "baslat_spawn_dongusu")
		get_tree().call_group("Spawner", "bloklari_goster")

	print("🪑 Tabureye oturuldu.")
	
	if TutorialManager:
		TutorialManager.eylemi_dogrula("oturma")

func move_table_camera(direction: float):
	if not is_sitting or not current_stool: return
	
	# Yön -1 ise Sola (index artar), 1 ise Sağa (index azalır) 
	# Veya tam tersi, kullanıcı A'ya basınca (Sola) kamera sola gitsin
	# A -> direction -1 -> Sola gitmek için index azalmalı (veya artmalı, bakış açısına göre değişir)
	# Deneme: D (+1) -> Sağa dön -> Index artar
	
	if direction > 0:
		table_angle_index -= 1 # D tuşu: Sağa dön (Saat yönünün tersi gibi)
	else:
		table_angle_index += 1 # A tuşu: Sola dön
		
	# 0-3 arası wrap
	table_angle_index = wrapi(table_angle_index, 0, 4)
	
	_update_orbit_camera()

func _update_orbit_camera():
	if not current_stool: return
	
	# Masa Merkezi (Grid'in olduğu yer)
	var pivot = Vector3(0, 0, 0)
	
	# Taburenin masaya olan uzaklığı (Radius)
	var radius = 1.7
	
	# Açıyı hesapla (her index 90 derece)
	var target_pos = Vector3.ZERO
	var target_rot = Vector3.ZERO
	
	match table_angle_index:
		0: # Ön (Default) - X Pozitif -> Merkeze (-X) bakmalı
			target_pos = Vector3(radius, -0.38, 0)
			target_rot = Vector3(0, deg_to_rad(90), 0)
		1: # Sağ - Z Pozitif -> Merkeze (-Z) bakmalı
			target_pos = Vector3(0, -0.38, radius)
			target_rot = Vector3(0, deg_to_rad(0), 0) 
		2: # Arka - X Negatif -> Merkeze (+X) bakmalı
			target_pos = Vector3(-radius, -0.38, 0)
			target_rot = Vector3(0, deg_to_rad(-90), 0)
		3: # Sol - Z Negatif -> Merkeze (+Z) bakmalı
			target_pos = Vector3(0, -0.38, -radius)
			target_rot = Vector3(0, deg_to_rad(180), 0) 

	# 1. TABUREYİ ve OYUNCUYU TAŞI (EN KISA YOLDAN DÖN)
	var current_stool_rot_y = current_stool.global_rotation.y
	var diff_stool = wrapf(target_rot.y - current_stool_rot_y, -PI, PI)
	var final_stool_rot_y = current_stool_rot_y + diff_stool
	var final_stool_rot = Vector3(0, final_stool_rot_y, 0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Tabure Tween
	tween.tween_property(current_stool, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(current_stool, "global_rotation", final_stool_rot, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# OYUNCUYU DA TAŞI (BOSS İÇİN)
	# Oyuncuyu Taburenin tam içine veya biraz üstüne taşıyalım. 
	# Collision çakışması olabilir, bu yüzden collision'ı kapatmak iyi olabilir ama Boss raycast atıyorsa CollisionShape yerinde durmalı.
	# Oyuncunun global pozisyonunu Tabureye eşitleyelim (Yükseklik ayarı ile).
	var player_target_pos = target_pos
	player_target_pos.y += 0.5 # Biraz yukarıda otursun
	tween.tween_property(self, "global_position", player_target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Tween referansını sakla (Kalkarken durdurmak için)
	active_tween = tween
	
	# 2. KAMERAYI MANTIKSAL OLARAK HESAPLA
	# Tabure'nin varacağı son transform (düzeltilmiş rotasyon ile)
	var dest_trans = Transform3D(Basis.from_euler(final_stool_rot), target_pos)
	var marker_local = current_stool.camera_position_marker.transform
	var final_cam_global = dest_trans * marker_local
	
	tween.tween_property(kamera, "global_transform", final_cam_global, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 3. BLOK DAĞITICISINI DÖNDÜR (EN KISA YOL + SİMETRİ HİZALAMA)
	var spawner = get_tree().current_scene.find_child("BlokDagiticisi", true, false)
	if spawner:
		# Hedef: Taburenin baktığı yönün 90 derece sağı (veya duruma göre)
		# Tabure Merkeze bakıyor. 
		# Kullanıcı blokları "Bakış açışına göre dursun" istedi.
		# Eğer biz masanın etrafında dönüyorsak, bloklar da (eğer world space'de sabitlerse) bizle dönmüyor demektir.
		# Ama "BlokDağıtıcısı" bizim elimiz (Hand) gibi davranıyor.
		# Biz döndükçe, elimiz de bizimle dönmeli VE bize bakmalı.
		
		# Tabure Y ekseninde `final_stool_rot_y` açısında olacak.
		# Bu açı "Taburenin baktığı yön".
		# BlokDağıtıcısı 0 rotasyonundayken +Z'ye (veya +X'e) hizalıdır.
		# Deneme-Yanılma ile önceden "-90" yapmıştık ve "Sağda" durmuştu.
		# Kullanıcı "Benim baktığım açıya göre dursun" dedi. 
		# Bu, "Kamera nereye bakıyorsa, bloklar da oraya baksın (Billboard)" demek olabilir.
		
		# Eğer Tabure'nin rotasyonunu (final_stool_rot_y) aynen verirsek:
		# Spawner da Tabure ile aynı yöne bakar.
		# Daha önce -90 vermiştik.
		# Şimdilik "En kısa yol" sorununu çözelim, hizalamayı aynı koruyalım (-90).
		
		var target_spawner_rot_y = final_stool_rot_y - deg_to_rad(90)
		var spawner_saga_gecsin_mi = false
		
		var boss = get_tree().get_first_node_in_group("Dusman")
		if boss:
			# Boss'un bana göre hangi tarafta olduğunu bul (Kamera / Tabure açısına göre)
			var to_boss = (boss.global_position - target_pos).normalized()
			var right_vec = Vector3.RIGHT.rotated(Vector3.UP, final_stool_rot_y)
			var dot_val = to_boss.dot(right_vec)
			
			# Sadece boss BARIz bir şekilde kameranın solundaysa (dot_val çok düşükse)
			if dot_val < -0.35:
				# Boss kameranın solunda kalıyor, Blokları sağa al!
				target_spawner_rot_y = final_stool_rot_y + deg_to_rad(90)
				spawner_saga_gecsin_mi = true
				
		if "sag_tarafta_mi" in spawner:
			spawner.sag_tarafta_mi = spawner_saga_gecsin_mi
		
		# Spawner için de shortest path hesabı
		var current_spawner_rot_y = spawner.rotation.y
		var diff_spawner = wrapf(target_spawner_rot_y - current_spawner_rot_y, -PI, PI)
		var final_spawner_rot_y = current_spawner_rot_y + diff_spawner
		
		tween.tween_property(spawner, "rotation:y", final_spawner_rot_y, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func stand_up():
	if not is_sitting: return
	
	# Eğer oyuncu üzerinde aktif bir tween varsa (Tabure ile hareket ediyorsa) durduralım.
	# Yoksa tween devam edip oyuncuyu tekrar tabureye çekebilir.
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	# Kalkma işlemi
	
	# UI GÜNCELLEME: Varsayılan (Altta)
	if etkilesim_label:
		etkilesim_label.text = ""
		# Anchor Bottom-Center (Sphenks.tscn'deki default değerlere dönüyoruz)
		etkilesim_label.anchor_top = 0.85
		etkilesim_label.anchor_bottom = 0.85
		etkilesim_label.scale = Vector2(1, 1)

	# Blokları Gizle
	var spawner = get_tree().current_scene.find_child("BlokDagiticisi", true, false)
	if spawner and spawner.has_method("bloklari_gizle"):
		spawner.bloklari_gizle()
	
	is_sitting = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_serbest_modu = false
	
	# Kamerayı eski yerine (veya çıkış noktasına) taşı
	if current_stool and is_instance_valid(current_stool) and current_stool.exit_position_marker:
		var exit_pos = current_stool.exit_position_marker.global_position
		velocity = Vector3.ZERO
		global_position = exit_pos
		
		# TABURENİN ARKASINDAN GRİDE (MERKEZE) BAK
		var look_target = Vector3(0, global_position.y, 0)
		look_at(look_target, Vector3.UP)
		
		kamera.position = Vector3(0, 0.6, 0)
		kamera.rotation = Vector3.ZERO
		x_rotasyonu = 0.0
	else:
		# Fallback if table already deleted (game over)
		var tween = create_tween()
		active_tween = tween
		tween.tween_property(kamera, "global_transform", original_camera_transform, 1.0)
		tween.tween_callback(func(): x_rotasyonu = kamera.rotation.x)
	
	current_stool = null
	print("🚶 Tabureden kalkıldı.")
	
	if TutorialManager:
		TutorialManager.eylemi_dogrula("kalkma")

func toggle_mouse_mode():
	if oldu_mu: return
	mouse_serbest_modu = !mouse_serbest_modu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mouse_serbest_modu else Input.MOUSE_MODE_CAPTURED
func _revive_ile_kalkis():
	print("😇 REVIVE DEVREYE GİRDİ! Oyuncu kurtarıldı.")
	
	# 1. Hakkı Tüket
	GameManager.revive_aktif = false
	
	# 2. Mesaj Ver
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz: arayuz.bilgi_goster("😇 ÖLÜMDEN DÖNDÜN! (Revive Kullanıldı)", 3.0)
	
	# 3. ÖZEL KALKIŞ ANİMASYONU (Standart kalkis_baslat'ı kullanmıyoruz!)
	# Çünkü o fonksiyon otomatik olarak 1 can daha düşürüyor. Biz elle yapacağız.
	var tween = create_tween()
	tween.parallel().tween_property(kamera, "rotation:z", 0.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(kamera, "position:y", 0.6, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(kamera, "rotation:x", 0.0, 1.0) 
	
	# 4. Animasyon bitince değerleri ZORLA eşitle
	tween.tween_callback(func():
		yere_dustu_mu = false
		
		# --- BURASI DÜZELTİLDİ ---
		# Normalde can düşüyordu, burada direkt 1'e sabitliyoruz.
		suanki_can_bari = 1  
		suanki_hp = 10       
		# -------------------------
		
		GameManager.saglik_guncelle(suanki_can_bari, suanki_hp)
		ui_guncelle()
		print("✅ Revive tamamlandı. Can: 1 Bar (10 HP)")
	)

# ============================================================
# --- UZUV YEME MEKANİĞİ (Violent Bite System) ---
# ============================================================

func yeme_baslat():
	"""R tuşuna basılınca ve KopanUzuv tutuluyorsa çağrılır.
	Timer-driven ısırık döngüsünü başlatır."""
	if is_eating: return
	if not tutulan_nesne or not tutulan_nesne.is_in_group("KopanUzuv"): return
	
	# --- KAPASİTE KONTROLÜ (Level-Based) ---
	if GameManager:
		var kapasite = GameManager.get_stomach_capacity()
		var yenen = GameManager.limbs_eaten_this_round
		
		# Eğer bu tur yenen sayı kapasiteye eşit veya fazlaysa -> YEME!
		if yenen >= kapasite:
			print("⛔ MİDE DOLU! (%d/%d) — Yeme reddedildi." % [yenen, kapasite])
			
			# 1. Sesli Tepki (Error Sound / Nefes)
			# "ErrorSound.mp3" olmadığı için basit bir pitch-down nefes veya UI hatası çalınabilir
			# Şimdilik debug print + ekran sallantısı (MideUI)
			
			# 2. Görsel Tepki (Mide UI Refusal)
			var mide_ui = find_child("MideUI", true, false) # Recursive ara
			if mide_ui and mide_ui.has_method("notify_refusal"):
				mide_ui.notify_refusal()
			else:
				# Oyuncu/CanvasLayer içindeki MideUI için manuel arama (eğer yukarıdaki bulamazsa)
				if mide_ui_container: # Export edilmiş path
					var mide = mide_ui_container if mide_ui_container.has_method("notify_refusal") else null
					if not mide and mide_ui_container.get_child_count() > 0:
						mide = mide_ui_container.get_child(0)
					if mide and mide.has_method("notify_refusal"):
						mide.notify_refusal()

			# 3. Yazılı Mesaj (Toast)
			# EtkilesimYazisi'ni geçici olarak kullan veya yeni bir Label
			var etkilesim_label = $CanvasLayer/EtkilesimYazisi
			if etkilesim_label:
				var eski_text = etkilesim_label.text
				etkilesim_label.text = DilYoneticisi.metin_al("daha_fazla_yemek")
				etkilesim_label.modulate = Color(1, 0, 0) # Kırmızı
				
				# 2 saniye sonra eski haline döndür
				var t = create_tween()
				t.tween_interval(2.0)
				t.tween_callback(func(): 
					etkilesim_label.text = "" # Boşalt veya eski haline
					etkilesim_label.modulate = Color(1, 1, 1)
				)
			
			return # YEMEYİ BAŞLATMA!
	
	# ---------------------------------------
	
	print("🩸 UZUV YEME BAŞLADI — Violent Bite System")
	is_eating = true
	if GameManager: GameManager.yeme_aktif_mi = true
	trauma = 0.0
	velocity = Vector3.ZERO
	
	# Orijinal FOV kaydet
	if kamera:
		orijinal_fov = kamera.fov
	
	# Uzvu hazırla
	if tutulan_nesne.has_method("yenmeye_basla"):
		tutulan_nesne.yenmeye_basla(0.0)  # Sadece orijinal değerleri kaydetsin
	
	# Vignette Shader Aç (başlangıç intensity)
	_gore_vignette_ayarla(true, 0.0)
	
	# --- ISIRIK TIMER BAŞLAT ---
	if bite_timer:
		bite_timer.queue_free()
	
	bite_timer = Timer.new()
	bite_timer.wait_time = bite_interval
	bite_timer.one_shot = false
	add_child(bite_timer)
	bite_timer.timeout.connect(_on_bite_timer)
	bite_timer.start()
	
	# İlk ısırığı hemen yap (beklemesin)
	_take_bite()
	
	# UI bilgi
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("bilgi_goster"):
		arayuz.bilgi_goster("🩸 YİYOR... [R bırak = İptal]", 5.0)

func _on_bite_timer():
	"""Timer her tetiklendiğinde bir ısırık at."""
	if not is_eating: return
	_take_bite()

func _take_bite():
	"""TEK BİR ISIRIK — Tüm efektler burada senkronize tetiklenir.
	Bu fonksiyon 'the moment of violence'."""
	if not is_eating: return
	if not tutulan_nesne or not is_instance_valid(tutulan_nesne): 
		yeme_tamamlandi()
		return
	
	# === 1. UZUV ISIRMA (Mesh küçültme + jolt) ===
	var bitti = false
	if tutulan_nesne.has_method("isir"):
		bitti = tutulan_nesne.isir()
	
	# === 2. İLERLEME HESAPLA (Frenzy) ===
	var frenzy = 0.0
	if tutulan_nesne.has_method("yenme_ilerlemesi"):
		frenzy = tutulan_nesne.yenme_ilerlemesi()
	
	# === 3. KAMERA TRAVMASI (Per-bite punch) ===
	# Her ısırıkta sert bir travma ekle — frenzy ile artar
	var bite_trauma = 0.4 + frenzy * 0.5
	kamera_travma(bite_trauma)
	
	# === 4. KAN SPREYİ (Her ısırıkta yeni patlama) ===
	_kan_patlamasi()
	
	# === 5. VİGNETTE + FOV GÜNCELLE ===
	_gore_vignette_ayarla(true, frenzy)
	_fov_guncelle(frenzy)
	
	# === 6. SES SYNC NOKTASI ===
	# TODO: Ses dosyaları eklenince aktif et
	# _isirma_sesi_cal(frenzy)
	
	print("🦷 BITE! Frenzy: %.2f" % frenzy)
	
	# === 7. BİTTİ Mİ? ===
	if bitti:
		yeme_tamamlandi()

func yeme_iptal():
	"""R tuşu bırakıldığında çağrılır.
	Her şeyi temiz şekilde eski haline döndürür."""
	if not is_eating: return
	
	print("❌ Yeme iptal edildi!")
	is_eating = false
	if GameManager: GameManager.yeme_aktif_mi = false
	
	# Timer durdur
	if bite_timer:
		bite_timer.stop()
		bite_timer.queue_free()
		bite_timer = null
	
	# Vignette kapat
	_gore_vignette_ayarla(false, 0.0)
	
	# FOV geri yükle
	if kamera:
		var fov_tween = create_tween()
		fov_tween.tween_property(kamera, "fov", orijinal_fov, 0.3)
	
	# Kamera travma sıfırla
	trauma = 0.0
	if kamera:
		kamera.h_offset = 0.0
		kamera.v_offset = 0.0
	
	# Uzuv skalasını geri al
	if tutulan_nesne and is_instance_valid(tutulan_nesne) and tutulan_nesne.has_method("yenme_iptal"):
		tutulan_nesne.yenme_iptal()

func yeme_tamamlandi():
	"""Tüm ısırıklar tamamlandığında çağrılır.
	Uzuv yok edilir, büyük şiddetli final efekti, oyuncu iyileşir."""
	if not is_eating: return
	
	print("✅ UZUV YENDİ! Final travması uygulanıyor...")
	is_eating = false
	if GameManager: GameManager.yeme_aktif_mi = false
	
	# Timer durdur
	if bite_timer:
		bite_timer.stop()
		bite_timer.queue_free()
		bite_timer = null
	
	# FINAL TRAVMASI — Son yutkunma şoku
	kamera_travma(1.0)
	
	# Vignette yavaşça kapat
	_gore_vignette_ayarla(false, 0.0)
	
	# FOV geri yükle (yavaş — dramatik)
	if kamera:
		var fov_tween = create_tween()
		fov_tween.tween_property(kamera, "fov", orijinal_fov, 0.8).set_trans(Tween.TRANS_CUBIC)
	
	# --- İYİLEŞME ---
	if suanki_hp < 10:
		suanki_hp = 10
	elif suanki_can_bari < max_can_bari:
		suanki_can_bari += 1
		suanki_hp = 10
	
	if GameManager:
		GameManager.saglik_guncelle(suanki_can_bari, suanki_hp)
	ui_guncelle()
	
	# Uzvu yok et
	if tutulan_nesne and is_instance_valid(tutulan_nesne):
		tutulan_nesne.queue_free()
	tutulan_nesne = null
	
	# UI mesajı
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("bilgi_goster"):
		arayuz.bilgi_goster("🩸 İYİLEŞTİN! Uzuv tüketildi.", 2.0)
	
	# Mide sistemini güncelle
	if GameManager and GameManager.has_method("uzuv_yendi"):
		GameManager.uzuv_yendi()
		# Kalcı gore intensity'yi vignette'ye uygula
		_gore_kalici_intensity_uygula()
	
	print("💚 Can güncellendi: Bar=%d HP=%d" % [suanki_can_bari, suanki_hp])

# --- KAMERA TRAVMASI ---

func kamera_travma(miktar: float):
	"""Anlık kamera travması ekle. Decay _physics_process'te yapılır."""
	trauma = clamp(trauma + miktar, 0.0, 1.0)

func _travma_guncelle(delta):
	"""Her frame travma shake uygula ve decay et.
	_physics_process'ten çağrılır."""
	if not kamera: return
	
	if trauma > 0.0:
		# Shake intensity = trauma^2 (quadratic — daha doğal hissettir)
		var shake = trauma * trauma
		
		# Perlin-benzeri rastgele offset (her frame farklı seed)
		var zaman = Time.get_ticks_msec() / 1000.0
		kamera.h_offset = max_shake_offset * shake * sin(zaman * 37.0 + randf() * 2.0)
		kamera.v_offset = max_shake_offset * shake * cos(zaman * 53.0 + randf() * 2.0)
		
		# Hafif rotasyon sarsması da ekle (daha visceral)
		kamera.rotation.z = max_shake_rotation * shake * sin(zaman * 41.0)
		
		# Decay — hızlı söner (exponential)
		trauma = max(trauma - trauma_decay * delta, 0.0)
	else:
		# Temiz sıfırlama
		kamera.h_offset = 0.0
		kamera.v_offset = 0.0
		# rotation.z'yi sıfırla ama sadece yeme bittiyse
		if not is_eating:
			kamera.rotation.z = 0.0

# --- KAN PATLAMASİ ---

func _kan_patlamasi():
	"""Her ısırıkta kameranın önünde taze kan burst'ü."""
	if not kan_spreyi_sahne or not kamera: return
	
	var kan = kan_spreyi_sahne.instantiate()
	kamera.add_child(kan)
	# Kameranın önünde, hafif rastgele offset
	kan.position = Vector3(
		randf_range(-0.15, 0.15),
		randf_range(-0.2, 0.0),
		randf_range(-0.6, -0.3)
	)
	kan.emitting = true
	
	# Otomatik temizle
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(kan):
		kan.queue_free()

# --- VIGNETTE SHADER KONTROL ---

func _gore_vignette_ayarla(aktif: bool, frenzy: float):
	"""GoreVignette shader'ını intensity + frenzy ile kontrol et.
	@export gore_vignette referansı kullanır (Inspector'dan atanmış)."""
	if not gore_vignette:
		# Export atanmamışsa — hata bas ama crash yapma
		if aktif: 
			push_warning("⚠️ gore_vignette atanmamış! Inspector'dan GoreVignette ColorRect'i sürükle.")
		return
	
	# Material yoksa hiç dokunma — shader olmadan görünür yapmak ekranı boyar
	if not gore_vignette.material:
		push_warning("⚠️ gore_vignette'nin material'ı yok! ShaderMaterial atanmamış.")
		return
	
	if eating_tween and eating_tween.is_valid():
		eating_tween.kill()
	
	if aktif:
		gore_vignette.visible = true
		# Frenzy'yi 0.5'e sınırla — tam ekran kaplamasın, sadece kenar efekti
		var clamped_frenzy = clamp(frenzy * 0.5, 0.0, 0.5)
		gore_vignette.material.set_shader_parameter("frenzy", clamped_frenzy)
			
		var current_intensity = gore_vignette.material.get_shader_parameter("intensity")
		if current_intensity == null: current_intensity = 0.0
		# Max intensity 0.65 — ekranı tamamen kapatmaz
		var hedef_intensity = clamp(current_intensity + 0.15, 0.0, 0.65)
		eating_tween = create_tween()
		eating_tween.tween_method(func(val):
			if is_instance_valid(gore_vignette) and gore_vignette.material:
				gore_vignette.material.set_shader_parameter("intensity", val)
		, current_intensity, hedef_intensity, 0.2)
	else:
		# Yeme bitti — HEMEN gizle (Kalıcı olmayacak)
		# Fade out efekti
		eating_tween = create_tween()
		eating_tween.tween_method(func(val):
			if is_instance_valid(gore_vignette) and gore_vignette.material:
				gore_vignette.material.set_shader_parameter("intensity", val)
				gore_vignette.material.set_shader_parameter("frenzy", val * 0.0)
		, 1.0, 0.0, 0.4) # 0.4 saniyede sıfırla
		
		eating_tween.tween_callback(func():
			if is_instance_valid(gore_vignette):
				gore_vignette.visible = false
				# Material parametrelerini de sıfırla
				if gore_vignette.material:
					gore_vignette.material.set_shader_parameter("intensity", 0.0)
		)


# --- GORE VIGNETTE KATMAN YONETIMI ---

func _gore_vignette_katmana_tasi():
	"""GoreVignette'yi düşük layer'lı bir CanvasLayer'a taşır.
	OyunArayuzu (layer=1) altında render edilir — MideUI'yı kapatmaz."""
	if not gore_vignette: 
		print("⚠️ GoreVignette yok!")
		return
	
	var mevcut_parent = gore_vignette.get_parent()
	if not mevcut_parent: 
		print("⚠️ GoreVignette parent yok!")
		return
	
	print("🎨 GoreVignette Layer Check: Parent=%s Layer=%s" % [mevcut_parent.name, str(mevcut_parent.layer) if "layer" in mevcut_parent else "N/A"])

	print("🎨 GoreVignette Layer Check: Parent=%s Layer=%s" % [mevcut_parent.name, str(mevcut_parent.layer) if "layer" in mevcut_parent else "N/A"])

	# Zaten ayrı bir GoreKatman'daysa tekrar taşıma
	if mevcut_parent.name == "GoreKatman": return
	
	# Yeni CanvasLayer oluştur (layer=-1 — OyunArayuzu'nun kesin altında)
	var gore_katman = CanvasLayer.new()
	gore_katman.name = "GoreKatman"
	gore_katman.layer = -1
	
	# Aynı sahne köküne ekle
	var sahne_koku = get_tree().current_scene
	sahne_koku.add_child(gore_katman)
	
	# GoreVignette'yi yeni layer'a taşı
	# Transform/Anchor korumak için gerekirse ayar yapılabilir ama full-screen rect olduğu için sorun olmaz
	mevcut_parent.remove_child(gore_vignette)
	gore_katman.add_child(gore_vignette)
	
	# Tam ekran olduğundan emin ol (reparent sonrası bozulabilir)
	gore_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	print("🎨 GoreVignette YENİ GoreKatman'a (layer=-1) taşındı")

# --- KALICI GORE INTENSITY ---

func _gore_kalici_intensity_uygula():
	"""GameManager.gore_intensity'yi ARTIK UYGULAMA (Kullanıcı isteği: Sadece yeme sırasında).
	Bu fonksiyon sadece başlangıçta gizli olduğundan emin olur."""
	
	if not gore_vignette: return
	
	# Başlangıçta görünür olmasın
	gore_vignette.visible = false
	if gore_vignette.material:
		gore_vignette.material.set_shader_parameter("intensity", 0.0)
	
	print("🩸 GORE: Kalıcı efekt iptal edildi (visible=false)")

# --- FOV TÜNEL VİZYONU ---

func _fov_guncelle(frenzy: float):
	"""Frenzy arttıkça FOV daralır (tünel vizyonu)."""
	if not kamera: return
	var hedef_fov = lerp(orijinal_fov, min_fov, frenzy)
	# Anlık snap (tween kullanmıyoruz — ısırıkla senkron olsun)
	kamera.fov = hedef_fov

# --- SES SYNC (TODO: Dosyalar eklenince aktif et) ---

#func _isirma_sesi_cal(frenzy: float):
#	"""Her ısırıkta senkronize ses çal.
#	Frenzy ilerledikçe farklı sesler seçilir."""
#	var ses = AudioStreamPlayer.new()
#	ses.bus = "SFX"  # Varsa
#	add_child(ses)
#	
#	# Frenzy'ye göre ses seç
#	if frenzy < 0.3:
#		ses.stream = ses_koparma   # İlk ısırıklar: et koparma
#	elif frenzy < 0.7:
#		ses.stream = ses_cignemek   # Ortası: çiğneme
#	else:
#		ses.stream = ses_yutmak     # Son ısırıklar: yutkunma
#	
#	# Pitch variation (tekrarlayan ses monoton olmasın)
#	ses.pitch_scale = randf_range(0.85, 1.15)
#	ses.volume_db = 2.0 + frenzy * 4.0  # Giderek daha yüksek
#	ses.play()
#	
#	# Otomatik temizle
#	ses.finished.connect(ses.queue_free)
