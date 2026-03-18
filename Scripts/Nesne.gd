extends RigidBody3D

var esya_verisi: ItemData:
	set(v):
		esya_verisi = v
		if esya_verisi:
			print("📦 Nesne Verisi Atandı: ", esya_verisi.etki_id)
			if esya_verisi.etki_id == "shotgun_mermi":
				print("🎯 Mermi Kutusu Tespit Edildi, Billboard yaratılıyor...")
				add_to_group("MermiKutusu")
				_mermi_bilgisi_yarat()

var market_modu: bool = false 

func _ready():
	pass

func _mermi_bilgisi_yarat():
	# Renk Tanımı
	var sari = Color(1, 1, 0)
	
	# 1. Revolver Bilgisi (Sol)
	var revolver_info = Node3D.new()
	revolver_info.name = "RevolverInfo"
	revolver_info.position = Vector3(-0.25, 0.9, 0) # Daha yukarı
	add_child(revolver_info)
	
	var rev_icon = Sprite3D.new()
	rev_icon.texture = load("res://Assets/bullet_1.png")
	rev_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rev_icon.pixel_size = 0.0006 # Daha küçük
	rev_icon.modulate = sari
	revolver_info.add_child(rev_icon)
	
	var rev_label = Label3D.new()
	rev_label.name = "Label3D"
	rev_label.text = "x0"
	rev_label.font_size = 28 # Daha küçük
	rev_label.outline_size = 12
	rev_label.modulate = sari
	rev_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rev_label.position = Vector3(0.15, 0, 0) # İkonun yanında
	revolver_info.add_child(rev_label)
	
	# 2. Shotgun Bilgisi (Sağ)
	var shotgun_info = Node3D.new()
	shotgun_info.name = "ShotgunInfo"
	shotgun_info.position = Vector3(0.25, 0.9, 0) # Daha yukarı
	add_child(shotgun_info)
	
	# Çapraz Shotgun İkonu (2 adet mermi)
	var shot_icon1 = Sprite3D.new()
	shot_icon1.texture = load("res://shotgun_shell.png")
	shot_icon1.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shot_icon1.pixel_size = 0.0006
	shot_icon1.modulate = sari
	shot_icon1.rotation.z = deg_to_rad(45)
	shotgun_info.add_child(shot_icon1)
	
	var shot_icon2 = Sprite3D.new()
	shot_icon2.texture = shot_icon1.texture
	shot_icon2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shot_icon2.pixel_size = 0.0006
	shot_icon2.modulate = sari
	shot_icon2.rotation.z = deg_to_rad(-45)
	shotgun_info.add_child(shot_icon2)
	
	var shot_label = Label3D.new()
	shot_label.name = "Label3D"
	shot_label.text = "x0"
	shot_label.font_size = 28
	shot_label.outline_size = 12
	shot_label.modulate = sari
	shot_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shot_label.position = Vector3(0.15, 0, 0)
	shotgun_info.add_child(shot_label)
	
	# Başlangıçta gizle
	revolver_info.visible = false
	shotgun_info.visible = false

func etkilesime_gir():
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if not oyuncu: return
	
	if market_modu:
		if oyuncu.has_method("satin_al"):
			oyuncu.satin_al(self)
	else:
		if oyuncu.has_method("esyayi_ele_al"):
			oyuncu.esyayi_ele_al(self)
