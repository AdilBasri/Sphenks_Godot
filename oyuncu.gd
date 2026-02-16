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

var is_sitting: bool = false
var current_stool: Node3D = null
var original_camera_transform: Transform3D
var table_camera_offset: float = 0.0

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

	# SPACE TUŞU İPTAL EDİLDİ - ARTIK TABURE SİSTEMİ VAR
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if is_sitting:
			stand_up()
		else:
			etkilesime_gir()
	
	if is_sitting:
		if event is InputEventKey:
			if event.pressed:
				if event.keycode == KEY_A:
					move_table_camera(-1.0)
				elif event.keycode == KEY_D:
					move_table_camera(1.0)
		return # Otururken diğer inputları (mouse look vs) engelle

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
					GameManager.oyunu_kaydet()
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
		"mantar": if grid: grid.mantar_modu_aktif(); _ekran_bozma_efekti(true); basarili = true
		"magnet": if grid: grid.miknatis_etkisi(); basarili = true
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
		
		# print("Bakılan Nesne: ", nesne.name) # DEBUG
		
		var veri = nesne.get("esya_verisi")
		var market_modu = nesne.get("market_modu")
		
		if veri:
			if market_modu == true:
				etkilesim_label.text = "[SOL TIK] SATIN AL\n" + veri.esya_adi + " (" + str(veri.fiyat) + " Altın)"
			else:
				etkilesim_label.text = "[SOL TIK] AL\n" + veri.esya_adi
		
		elif nesne.has_method("interact"):
			etkilesim_label.text = "[E] Oynamak için Otur"
		
		elif nesne is RigidBody3D and not tutulan_nesne:
			etkilesim_label.text = "[SOL TIK] TUT"

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

	if nesne.has_method("interact"):
		nesne.interact(self)
		return

	if nesne is RigidBody3D:
		nesne_tut(nesne)

var table_angle_index: int = 0 # 0=Front, 1=Right, 2=Back, 3=Left

func sit_on_stool(stool_node):
	if is_sitting: return
	
	is_sitting = true
	current_stool = stool_node
	
	# Mouse'u serbest bırak ki gridle etkileşime girsin
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_serbest_modu = true
	
	# Kamera Pozisyonunu Kaydet
	original_camera_transform = kamera.global_transform
	
	_update_orbit_camera()
	
	# UI GÜNCELLEME: [E] Kalk (Üstte, Küçük)
	if etkilesim_label:
		etkilesim_label.text = "[E] Kalk"
		# Anchor Top-Center
		etkilesim_label.anchor_top = 0.05
		etkilesim_label.anchor_bottom = 0.05
		# Font küçültme (Scale ile hile yapıyoruz veya settings varsa oradan)
		etkilesim_label.scale = Vector2(0.7, 0.7)
	
	# Blok Dağıtıcısını Bul ve Göster
	var spawner = get_tree().current_scene.find_child("BlokDagiticisi", true, false)
	if spawner and spawner.has_method("bloklari_goster"):
		spawner.bloklari_goster()

	print("🪑 Tabureye oturuldu.")

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
	# İlk oturduğumuzdaki mesafeyi baz alabiliriz veya sabit bir değer verebiliriz.
	# Sabit değer daha güvenli: 1.7 birim (mevcut sahneye göre)
	var radius = 1.7
	
	# Açıyı hesapla (her index 90 derece)
	# 0 = Ön (Z ekseni pozitiften negatife bakıyor) -> 0 derece
	var angle_deg = table_angle_index * 90.0
	var angle_rad = deg_to_rad(angle_deg)
	
	# Yeni Pozisyon Hesabı (Çember üzerinde nokta)
	# Sin/Cos ile X ve Z koordinatlarını buluyoruz
	# Index 0 (Ön): x=0, z=r
	# Index 1 (Sağ): x=r, z=0
	# Index 2 (Arka): x=0, z=-r
	# Index 3 (Sol): x=-r, z=0
	
	# Sahnede Masa Z ekseninde uzanıyor olabilir, deneyelim:
	# Sphenks.tscn'de Tabure: (1.7, -0.38, -0.06) -> X ekseninde duruyor aslında!
	# O zaman 0 noktası (Front) X=1.7, Z=0 olmalı.
	
	var target_pos = Vector3.ZERO
	var target_rot = Vector3.ZERO
	
	match table_angle_index:
		0: # Ön (Default) - X Pozitif -> Merkeze (-X) bakmalı
			target_pos = Vector3(radius, -0.38, 0)
			target_rot = Vector3(0, deg_to_rad(90), 0)
		1: # Sağ - Z Pozitif -> Merkeze (-Z) bakmalı
			target_pos = Vector3(0, -0.38, radius)
			target_rot = Vector3(0, deg_to_rad(0), 0) # DÜZELTİLDİ: 0 derece (Eskisi 180 idi)
		2: # Arka - X Negatif -> Merkeze (+X) bakmalı
			target_pos = Vector3(-radius, -0.38, 0)
			target_rot = Vector3(0, deg_to_rad(-90), 0)
		3: # Sol - Z Negatif -> Merkeze (+Z) bakmalı
			target_pos = Vector3(0, -0.38, -radius)
			target_rot = Vector3(0, deg_to_rad(180), 0) # DÜZELTİLDİ: 180 derece (Eskisi 0 idi)

	# 1. TABUREYİ TAŞI
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(current_stool, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(current_stool, "global_rotation", target_rot, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 2. KAMERAYI TABURENİN YENİ KONUMUNA TAŞI (Tabureye bağlıymış gibi)
	# Tabure hareket ederken kamera da onun 'CameraPos' marker'ına gitmeli
	# Ancak Tween sırasında marker da hareket edeceği için, kamerayı sürekli marker'a eşitlemek lazım.
	# Bunu _process içinde yapabiliriz AMA basit olması için:
	# Tweener ile kamerayı da hedef transform'a götürelim.
	# Hedef transform: Tabure hedef noktaya vardığında CameraPos nerede olacak?
	
	# Basit çözüm: Kamerayı Tabure'ye "reparent" yapalım geçici olarak? Hayır karmaşık olur.
	# Manuel hesaplama:
	# Tabure hedef rotasyondayken, CameraPos'un local offsetini ekleyelim.
	
	var cam_pos_local = current_stool.camera_position_marker.position
	# Marker'ın local rotasyonunu (varsa) da hesaba katmak lazım ama şimdilik sadece offset
	# En temizi: Kameranın global transformunu, Tabure'nin hedef transformuna göre hesaplamak.
	
	# Hileli Yöntem: Tween callback ile her frame güncellemek yerine
	# Kamerayı Tabure'nin CameraMarker'ına 'RemoteTransform3D' ile bağlasak? 
	# Veya daha basiti: Kamera zaten Tween ile gidiyor, ama hedef nokta değişiyor.
	# Şimdilik kamerayı "takip etme" moduna alalım veya tween bitince senkronize edelim.
	
	# EN İYİSİ: Hareket bitene kadar kamerayı tweenleme, process'te takip ettir.
	# Ama şu anlık basit tween deneyelim, eğer kayma olursa düzeltiriz.
	
	# Hedef Tabure Transformunu oluştur
	var dest_trans = Transform3D(Basis.from_euler(target_rot), target_pos)
	# Marker'ın local transformu
	var marker_local = current_stool.camera_position_marker.transform
	# Hedef Kamera Global Transformu
	var final_cam_global = dest_trans * marker_local
	
	tween.tween_property(kamera, "global_transform", final_cam_global, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 3. BLOK DAĞITICISINI DÖNDÜR (EŞYALAR SAĞDA KALSIN)
	var spawner = get_tree().current_scene.find_child("BlokDagiticisi", true, false)
	if spawner:
		# Taburenin baktığı yön (target_rot.y)
		# Blokların "Sağda" olması için Tabure açısından -90 derece (veya +270) olması lazım.
		# Deneme: Tabure (0, 90, 0) bakarken Spawner (0, 0, 0) olursa -> Spawner Taburenin sağında kalır (X+ vs Z+)
		# Basit mantık: Tabure dönüşü + Offset
		
		# Tabure rotasyonu: 
		# 0 (Ön): 90 deg
		# 1 (Sağ): 0 deg (Bu düzeltilmisti) -> Yanlış, hatırlayalım:
		# Ön (Index 0): +X'de duruyor, Merkeze (-X) bakıyor -> Rot Y = 90
		# Sağ (Index 1): +Z'de duruyor, Merkeze (-Z) bakıyor -> Rot Y = 0 (Godot'ta -Z forward ise 0 derecedir)
		
		# Spawner masanın ortasında (0,0,0) duruyor. Blok spawn noktaları onun çocukları.
		# Eğer Spawner'ı taburenin açısına çevirirsek, spawn noktaları da döner.
		# Kullanıcı "Sağ tarafında belirsin" dedi.
		# Yani Tabure 90'a bakarken, Spawner 0'a bakmalı (90 - 90 = 0).
		
		var spawner_target_rot_y = target_rot.y - deg_to_rad(90)
		
		tween.tween_property(spawner, "rotation:y", spawner_target_rot_y, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func stand_up():
	if not is_sitting: return
	
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
	if current_stool and current_stool.exit_position_marker:
		global_position = current_stool.exit_position_marker.global_position
		# Kameranın local transformunu resetle (kafa hizası)
		kamera.position = Vector3(0, 0.6, 0)
		kamera.rotation = Vector3.ZERO
		x_rotasyonu = 0.0
	else:
		var tween = create_tween()
		tween.tween_property(kamera, "global_transform", original_camera_transform, 1.0)
	
	current_stool = null
	print("🚶 Tabureden kalkıldı.")

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
