extends Node3D

@export var satilacak_esya_listesi: Array[ItemData]

func _ready():
	await get_tree().process_frame
	esyalari_diz()

func esyalari_diz():
	if satilacak_esya_listesi.is_empty(): return
	
	# Marker3D olan çocukları bul
	var noktalar = []
	for cocuk in get_children():
		if cocuk is Marker3D: noktalar.append(cocuk)
	
	# Eşyaları oluştur
	for nokta in noktalar:
		for eski in nokta.get_children(): eski.queue_free()
		var rastgele_veri = satilacak_esya_listesi.pick_random()
		sprite_nesnesi_yarat(rastgele_veri, nokta)

func sprite_nesnesi_yarat(veri: ItemData, nokta: Marker3D):
	if not veri or not veri.ikon: return

	# 1. Fiziksel Vücut
	var body = RigidBody3D.new()
	nokta.add_child(body)
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.freeze = true 
	body.collision_layer = 1 
	
	# 2. Resim (Sprite3D)
	var sprite = Sprite3D.new()
	body.add_child(sprite)
	sprite.texture = veri.ikon
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED 
	sprite.pixel_size = 0.0005 
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	
	# 3. Kutu (Collision)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.4, 0.4, 0.4) 
	col.shape = shape
	body.add_child(col)
	
	# 4. SCRIPT YÜKLEME (YENİ YOL: res://Nesne.gd)
	var script = load("res://Nesne.gd") 
	if script:
		body.set_script(script)
		body.set("esya_verisi", veri)
		body.set("market_modu", true)
	else:
		print("🔴 HATA: 'res://Nesne.gd' bulunamadı!")
