extends Node3D

# --- SİNYALLER ---
signal kapi_acildi

# --- AYARLAR ---
# MARKET ve CAMPFIRE sadece kilitleme mantığı için var, ışınlanma için değil.
enum HedefTipi { SADECE_ACIL, SONRAKI_LEVEL, MARKET, CAMPFIRE }
@export var hedef_tipi: HedefTipi = HedefTipi.SADECE_ACIL

@export var kapi_isigi: SpotLight3D 
@export var gecit_efektleri: Node3D 
@export var kilitli_olsun_mu: bool = false 
@export var e_etkilesimi_devre_disi: bool = false # E ile ve yazı ile etkileşimi kapatır

var kilitli_mi: bool = false
var acik_mi: bool = false
var oyuncu_gecti_mi: bool = false

var kapali_rot_y: float = 0.0
var oyuncu_giris_z: Dictionary = {}
var gecis_area: Area3D

func _ready():
	kapali_rot_y = rotation.y
	if kilitli_olsun_mu:
		kilitle()
	
	# ÖZEL: Mezar Odası tespiti (Case-insensitive)
	var parent_name = get_parent().name.to_lower()
	var scene_name = get_tree().current_scene.name.to_lower()
	if "mezarodasi" in parent_name or "mezar_odasi" in scene_name or "mezar" in parent_name:
		e_etkilesimi_devre_disi = true
		print("🔕 Mezar Odası Kapısı: Etkileşim devre dışı bırakıldı.")
		
	if not e_etkilesimi_devre_disi:
		add_to_group("Etkilesim")
	
	# Body Entered sinyalini bağla (varsa)
	_gecisin_sensorunu_bagla()

func _gecisin_sensorunu_bagla():
	# Eğer bu kapı sisteminde Area3D varsa body_entered bağla
	for child in get_children():
		if child is StaticBody3D:
			pass
	# Geciş algılama için kapı önünde Area3D oluştur
	gecis_area = Area3D.new()
	gecis_area.name = "GecisAlgila"
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4.0, 4.0, 3.0)
	col.shape = shape
	col.position = Vector3(0, 1.5, 0)
	gecis_area.add_child(col)
	
	gecis_area.collision_layer = 0
	gecis_area.collision_mask = 1  # Oyuncu layerı
	
	# Kapı dönerken alanın savrulmaması için top_level yapıyoruz
	gecis_area.top_level = true
	add_child(gecis_area)
	gecis_area.global_transform = self.global_transform
	
	gecis_area.body_entered.connect(_oyuncu_girdi)
	gecis_area.body_exited.connect(_oyuncu_cikti)

# --- AKSİYONLAR ---
func interact(_oyuncu):
	etkilesim()

func etkilesim():
	if e_etkilesimi_devre_disi: return
	if _kapi_engellendi_mi(): return
	kapiyi_ac()

func kapiyi_ac():
	# 1. Kilit veya Açıklık Kontrolü
	if kilitli_mi:
		print("!!! BU KAPI KİLİTLENDİ !!!")
		return
	if acik_mi:
		return 

	# 2. Kapıyı Aç
	print(">>> KAPI AÇILIYOR... TİP: ", hedef_tipi)
	
	var sfx_door = AudioStreamPlayer3D.new()
	sfx_door.stream = load("res://Assets/Audio/door.mp3")
	sfx_door.bus = "Master"
	add_child(sfx_door)
	sfx_door.play()
	sfx_door.finished.connect(sfx_door.queue_free)
	
	acik_mi = true
	kapi_acildi.emit() # Odaya haber ver (Diğer kapıyı kilitlesin diye)
	
	if gecit_efektleri:
		gecit_efektleri.visible = true
	
	# 3. Animasyon (Fiziksel Açılma)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation:y", kapali_rot_y + deg_to_rad(95.0), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if kapi_isigi:
		kapi_isigi.visible = true 
		tween.tween_property(kapi_isigi, "light_energy", 12.0, 1.0)
	
	# 4. ÖZEL DURUM: Sadece "SONRAKI LEVEL" kapısıysa sahneyi resetle
	if hedef_tipi == HedefTipi.SONRAKI_LEVEL:
		await get_tree().create_timer(1.0).timeout
		LevelManager.odaya_don_ve_level_atla()
	
	# DİKKAT: Market ve Campfire için hiçbir şey yapmıyoruz. 
	# Kapı açıldı, oyuncu yürüyerek içeri girecek.

func _oyuncu_girdi(body):
	if not body.is_in_group("Oyuncu"): return
	var yerel_pos = gecis_area.to_local(body.global_position)
	oyuncu_giris_z[body.get_instance_id()] = sign(yerel_pos.z)

func _oyuncu_cikti(body):
	if oyuncu_gecti_mi: return
	if not body.is_in_group("Oyuncu"): return
	if not acik_mi: return
	
	var yerel_pos = gecis_area.to_local(body.global_position)
	var giris_isareti = oyuncu_giris_z.get(body.get_instance_id(), sign(yerel_pos.z))
	
	if giris_isareti != 0 and sign(yerel_pos.z) != 0 and giris_isareti != sign(yerel_pos.z):
		# Oyuncu gerçekten kapıdan diğer tarafa geçti!
		oyuncu_gecti_mi = true
		_kapiyi_kapat()

func _kapiyi_kapat():
	# Kapıyı geri kapat (orijinal rotasyonuna dön)
	var tween = create_tween()
	tween.tween_property(self, "rotation:y", kapali_rot_y, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Kapanınca da mantar efektini kapat (son ihtimal için)
	var _arayuz2 = get_tree().get_first_node_in_group("Arayuz")
	if _arayuz2 and _arayuz2.has_method("mantar_efekti_yonet"):
		_arayuz2.mantar_efekti_yonet(false)
	if GameManager:
		GameManager.mantar_modu = false
	if kapi_isigi:
		tween.tween_property(kapi_isigi, "light_energy", 0.0, 0.5)
		tween.tween_callback(func(): kapi_isigi.visible = false)
	tween.tween_callback(func():
		acik_mi = false
		kilitli_mi = true  # Artık açılamaz
		print("🔐 Kapı geçiş sonra kilitlendi.")
	)

func kilitle():
	if acik_mi: return 
	kilitli_mi = true
	if kapi_isigi:
		kapi_isigi.visible = false
		kapi_isigi.light_energy = 0

func _on_static_body_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if e_etkilesimi_devre_disi: return
		
		# ÖZEL: Tüm hiyerarşide mezar kontrolü (Input event için)
		var is_mezar = false
		var test_node = self
		while test_node:
			if "mezar" in test_node.name.to_lower():
				is_mezar = true
				break
			test_node = test_node.get_parent()
		if is_mezar: return

		if _kapi_engellendi_mi(): return
		
		if kilitli_mi:
			# Sandık odasındaysak falan uyar, ama KAPIYI AÇMA
			print("KAPI KİLİTLİ, TIKLAYARAK AÇILMAZ.")
			var arayuz = get_tree().get_first_node_in_group("Arayuz")
			if arayuz and get_tree().current_scene.name == "Sandik_Odasi":
				arayuz.bilgi_goster(DilYoneticisi.metin_al("anahtar_yok"), 2.0)
		
		kapiyi_ac()

func _kapi_engellendi_mi() -> bool:
	if e_etkilesimi_devre_disi: return false
	
	# Boss kaçtıysa veya öldüyse kapı her zaman açılabilir (Masa animasyonu bitmemiş olsa bile)
	if GameManager and GameManager.boss_kacti:
		return false
	
	# Blok masası olan sahnelerde, masa aşağı inip kaybolana kadar kapı TIKLANAMAZ!
	var blok_d = get_tree().current_scene.find_child("BlokDagiticisi", true, false)
	if blok_d and blok_d.get("masa_objesi") != null:
		if is_instance_valid(blok_d.masa_objesi) and not blok_d.masa_objesi.is_queued_for_deletion():
			# Eğer boss_oldu_mu true ise izin ver
			if blok_d.get("boss_oldu_mu") == true:
				return false
				
			# Sadece mezar odası DEĞİLSE yazdır
			var is_mezar = "mezar" in get_tree().current_scene.name.to_lower()
			if not is_mezar:
				print("门 Masa hala sahnede olduğu için kapıya tıklanılamaz!")
			return true
	return false
