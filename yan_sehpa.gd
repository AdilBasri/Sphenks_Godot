extends Node3D

@onready var slotlar_node = $Slotlar

func _ready():
	if not GameManager.envanter_guncellendi.is_connected(tazele):
		GameManager.envanter_guncellendi.connect(tazele)
	
	await get_tree().process_frame
	tazele()

func tazele():
	temizle() # Bu fonksiyon aşağıda tanımlı, artık hata vermez.
	if not slotlar_node: return
	
	# --- KRİTİK: Slotlar düğümünü sıfırla ---
	slotlar_node.scale = Vector3.ONE
	
	var slotlar = slotlar_node.get_children()
	var envanter = GameManager.envanter
	
	for i in range(min(envanter.size(), slotlar.size())):
		var veri = envanter[i]
		var hedef_marker = slotlar[i]
		
		# --- KRİTİK: Marker'ı sıfırla ---
		hedef_marker.scale = Vector3.ONE
		
		sprite_nesnesi_yarat(veri, hedef_marker)

func sprite_nesnesi_yarat(veri: ItemData, marker: Marker3D):
	if not veri or not veri.ikon: return

	# 1. Fiziksel Vücut
	var body = RigidBody3D.new()
	marker.add_child(body)
	
	# Konumlandırma (Masanın hafif üstüne)
	body.position = Vector3(0, 0.2, 0)
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE 
	
	body.freeze = true 
	body.collision_layer = 1 
	
	# 2. Resim
	var sprite = Sprite3D.new()
	body.add_child(sprite)
	sprite.texture = veri.ikon
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.0005 
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	
	# 3. Kutu
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.5) 
	col.shape = shape
	body.add_child(col)
	
	# 4. Script
	var script = load("res://Nesne.gd")
	if script:
		body.set_script(script)
		body.set("esya_verisi", veri)
		body.set("market_modu", false)

# --- İŞTE EKSİK OLAN FONKSİYON BURASI ---
func temizle():
	if slotlar_node:
		for marker in slotlar_node.get_children():
			for cocuk in marker.get_children():
				cocuk.queue_free()
