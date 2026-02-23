extends Node3D

@onready var chest = $Chest
@onready var oyuncu = $Oyuncu

var sandik_hedef_z = -26.5
var mesafe_kapanacak = false
var kapanis_basladi = false

class ChestInteract extends StaticBody3D:
	var ana_sahne: Node = null
	
	func get_etkilesim_yazisi() -> String:
		if ana_sahne and ana_sahne.mesafe_kapanacak and not ana_sahne.kapanis_basladi:
			return "[E] Sandığı Aç"
		return ""

	func interact(oyuncu_node):
		if ana_sahne and ana_sahne.mesafe_kapanacak and not ana_sahne.kapanis_basladi:
			ana_sahne.sandik_acildi()

func _ready():
	# Çarpışma ve Etkileşim için gövde ekle
	var static_body = ChestInteract.new()
	static_body.ana_sahne = self
	static_body.set_collision_layer(1)
	static_body.set_collision_mask(1)
	chest.add_child(static_body)
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.5, 1.5, 1.5) # Sandık boyutuna uygun
	collision.shape = shape
	collision.position = Vector3(0, 0.75, 0)
	static_body.add_child(collision)
	
	# Initial states for 2nd run
	if has_node("YeniSandık"):
		$YeniSandık.visible = false
	if has_node("KuruKafa"):
		$KuruKafa.visible = false
	if has_node("KapiSistemi"):
		$KapiSistemi.visible = false
		$KapiSistemi.set_process_mode(Node.PROCESS_MODE_DISABLED)
		$KapiSistemi.hedef_tipi = 1 # SONRAKI_LEVEL

func _process(delta):
	if kapanis_basladi: return
	
	var dist = oyuncu.global_position.distance_to(chest.global_position)
	
	if not mesafe_kapanacak:
		if dist < 6.0 and chest.position.z > sandik_hedef_z:
			var speed = 4.5
			if Input.is_action_pressed("kosma"):
				speed = 7.5
				
			chest.position.z -= speed * delta
			if chest.position.z <= sandik_hedef_z:
				chest.position.z = sandik_hedef_z
				mesafe_kapanacak = true
		elif dist <= 3.5 and chest.position.z <= sandik_hedef_z:
			mesafe_kapanacak = true

func sandik_acildi():
	if kapanis_basladi: return
	kapanis_basladi = true
	
	var rüya_sayisi = 0
	if GameManager:
		rüya_sayisi = GameManager.uyku_sahnesi_giris_sayisi
		
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	var cr = ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(cr)
	
	if rüya_sayisi <= 0:
		if GameManager: GameManager.uyku_sahnesi_giris_sayisi += 1
		# İlk Rüya (Eski davranış)
		cr.color = Color(1, 1, 1, 0)
		var t = create_tween()
		t.tween_property(cr, "color", Color(1, 1, 1, 1), 1.0).set_trans(Tween.TRANS_SINE)
		t.tween_callback(self._sahneyi_bitir)
	else:
		if GameManager: GameManager.uyku_sahnesi_giris_sayisi += 1
		# İkinci Rüya (Yeni davranış)
		cr.color = Color(1, 0, 0, 0)
		var t = create_tween()
		
		# 1 saniye boyunca ekran tamamen kırmızıya boyanır
		t.tween_property(cr, "color", Color(1, 0, 0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
		
		# Ekran tamamen kırmızıyken arkada dünya değişir
		t.tween_callback(self._ikinci_ruya_ortami_kur)
		
		# Sonra kırmızı yavaşça dağılır (hafif kırmızımsı kalabilir 0.2 gibi)
		t.tween_property(cr, "color", Color(1, 0, 0, 0.2), 1.0).set_trans(Tween.TRANS_SINE)

func _ikinci_ruya_ortami_kur():
	# Eski sandığı gizle, yenisini ve kafayı göster
	if chest:
		chest.visible = false
		chest.set_process_mode(Node.PROCESS_MODE_DISABLED) # Bu, sandığın etkileşim alanını da kapatır
	
	if has_node("YeniSandık"):
		$YeniSandık.visible = true
	if has_node("KuruKafa"):
		$KuruKafa.visible = true
	
	# Kapıyı göster ve aktif et
	if has_node("KapiSistemi"):
		$KapiSistemi.visible = true
		$KapiSistemi.set_process_mode(Node.PROCESS_MODE_INHERIT)
		$KapiSistemi.kilitli_mi = false
		
	# Bütün ışıkları kırmızı yap
	for light in find_children("*", "Light3D", true, false):
		light.light_color = Color(1.0, 0.3, 0.3)
		light.light_energy *= 1.2
		
	# Rastgele kan efektleri ekle
	var kan_tex = load("res://KAN.png")
	if kan_tex:
		for i in range(24):
			var decal = Decal.new()
			decal.texture_albedo = kan_tex
			
			var s = randf_range(1.5, 2.5)
			decal.size = Vector3(s, 1.5, s)
			
			var wall_choice = randi() % 3
			
			if wall_choice == 0:
				# Sol duvar (Left Wall)
				decal.position = Vector3(-2.15, randf_range(0.5, 3.0), randf_range(0.0, -25.0))
				decal.transform.basis = Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
			elif wall_choice == 1:
				# Sağ duvar (Right Wall)
				decal.position = Vector3(2.15, randf_range(0.5, 3.0), randf_range(0.0, -25.0))
				decal.transform.basis = Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
			else:
				# Arka duvar (Chest olduğu yer)
				decal.position = Vector3(randf_range(-2.0, 2.0), randf_range(0.5, 3.0), -27.8)
				decal.transform.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0))
				
			add_child(decal)

func _sahneyi_bitir():
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.has_method("odaya_don_ve_level_atla"):
		level_manager.odaya_don_ve_level_atla()
	else:
		print("Hata: LevelManager bulunamadı!")
