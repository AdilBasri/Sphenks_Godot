@tool
extends EditorScript

# Bu script Godot Editor uzerinden Script panelinde 
# Dosya -> Calistir (File -> Run) denilerek calistirilir.
func _run():
	print("Demo Final Sahnesi Kuruluyor...")
	
	var root = Node3D.new()
	root.name = "DemoFinal"
	
	# Ana Scripti Ekle
	var main_script = load("res://Scripts/DemoFinal.gd")
	if main_script:
		root.set_script(main_script)
		
	# --- ODA ---
	var oda = Node3D.new()
	oda.name = "Oda"
	root.add_child(oda)
	oda.owner = root
	
	var ana_kutu = CSGBox3D.new()
	ana_kutu.name = "AnaKutu"
	ana_kutu.size = Vector3(20, 10, 20)
	ana_kutu.use_collision = true
	oda.add_child(ana_kutu)
	ana_kutu.owner = root
	
	var ic_bosluk = CSGBox3D.new()
	ic_bosluk.name = "IcBosluk"
	ic_bosluk.operation = CSGShape3D.OPERATION_SUBTRACTION
	ic_bosluk.size = Vector3(19, 9, 19)
	ana_kutu.add_child(ic_bosluk)
	ic_bosluk.owner = root
	
	# Kaplama - white_tiles.tscn icindeki material'ı veya dogrudan dokuyu kullaniyoruz
	var tiles_mat = StandardMaterial3D.new()
	# White tiles texture bulmaya calisalim. Bulamazsak renkle veya mevcutsa UV ile kaplayalim.
	# white_tiles.tscn bir mesh. Oraya triplanar bir grid atayacagiz.
	tiles_mat.albedo_color = Color(0.8, 0.8, 0.8)
	tiles_mat.uv1_scale = Vector3(2, 2, 2)
	tiles_mat.uv1_triplanar = true
	
	var res_duvar = load("res://Assets/Images/duvar_tiles.png")
	if res_duvar:
		tiles_mat.albedo_texture = res_duvar
	ana_kutu.material = tiles_mat
	
	# --- ÇUKUR ---
	var Cukur = CSGBox3D.new()
	Cukur.name = "ZeminCukur"
	Cukur.operation = CSGShape3D.OPERATION_SUBTRACTION
	Cukur.size = Vector3(18, 25, 18) # Derin bir cukur
	Cukur.position = Vector3(0, -17.5, 0) # Zeminin altina alistik
	oda.add_child(Cukur)
	Cukur.owner = root
	
	var CukurMat = StandardMaterial3D.new()
	CukurMat.uv1_scale = Vector3(4, 10, 4)
	CukurMat.uv1_triplanar = true
	if res_duvar:
		CukurMat.albedo_texture = res_duvar
	CukurMat.albedo_color = Color(0.2, 0.2, 0.2) # Karanlik
	Cukur.material = CukurMat
	
	# Cukurun dibinde Skeletons
	var dibi = Node3D.new()
	dibi.name = "DibiSkeletons"
	dibi.position = Vector3(0, -29, 0)
	oda.add_child(dibi)
	dibi.owner = root
	
	# --- ISIK (ODANIN ICINDE) ---
	var o_light = OmniLight3D.new()
	o_light.name = "OdaIsigi"
	o_light.position = Vector3(0, 3, 0) # Odanin tavanina yakin
	o_light.omni_range = 35.0
	o_light.light_energy = 1.0
	o_light.shadow_enabled = true # Icerideki cisimler golge yapsin
	root.add_child(o_light)
	o_light.owner = root

	# --- CANAVAR ---
	var canavar_root = Node3D.new()
	canavar_root.name = "Canavar"
	root.add_child(canavar_root)
	canavar_root.owner = root
	
	var falling_scene = load("res://Falling.fbx")
	if falling_scene:
		var f_inst = falling_scene.instantiate()
		f_inst.name = "DusmeModeli"
		canavar_root.add_child(f_inst)
		f_inst.owner = root
	
	var yumruk_scene = load("res://Zombie Punching.fbx")
	if yumruk_scene:
		var y_inst = yumruk_scene.instantiate()
		y_inst.name = "YumrukModeli"
		y_inst.visible = false # Baslangicta gizli
		canavar_root.add_child(y_inst)
		y_inst.owner = root

	# Kamera Baglantisi - Falling modelin iskeletine bagla
	var cam_bone = BoneAttachment3D.new()
	cam_bone.name = "CameraBone"
	cam_bone.bone_name = "mixamorig_Head"
	
	var dusme_modeli = canavar_root.get_node_or_null("DusmeModeli")
	var skeleton = null
	if dusme_modeli:
		skeleton = dusme_modeli.find_child("Skeleton3D", true, false)
	
	if skeleton:
		cam_bone.use_external_skeleton = true
	
	canavar_root.add_child(cam_bone)
	cam_bone.owner = root
	
	if skeleton:
		cam_bone.external_skeleton = cam_bone.get_path_to(skeleton)
	
	var cam_offset = Node3D.new()
	cam_offset.name = "KameraTasiyici"
	cam_offset.position = Vector3(0, 0.2, 0.2)
	cam_bone.add_child(cam_offset)
	cam_offset.owner = root
	
	var cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam_offset.add_child(cam)
	cam.owner = root
	
	# --- UI & CANVAS ---
	var cvs = CanvasLayer.new()
	cvs.name = "CanvasLayer"
	root.add_child(cvs)
	cvs.owner = root
	
	var altyazi = Label.new()
	altyazi.name = "Altyazi"
	altyazi.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	altyazi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	altyazi.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	altyazi.offset_bottom = -100
	altyazi.text = ""
	var l_set = LabelSettings.new()
	l_set.font = load("res://Assets/Fonts/PressStart2P-Regular.ttf")
	l_set.font_size = 18
	l_set.outline_size = 4
	l_set.outline_color = Color.BLACK
	altyazi.label_settings = l_set
	cvs.add_child(altyazi)
	altyazi.owner = root
	
	var tikla = Label.new()
	tikla.name = "TiklaYazisi"
	tikla.set_anchors_preset(Control.PRESET_CENTER)
	tikla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tikla.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tikla.text = "VURMAK ICIN TIKLA!"
	tikla.visible = false
	var lt_set = LabelSettings.new()
	lt_set.font = load("res://Assets/Fonts/PressStart2P-Regular.ttf")
	lt_set.font_size = 24
	lt_set.font_color = Color(1,0,0)
	lt_set.outline_size = 3
	lt_set.outline_color = Color(0,0,0)
	tikla.label_settings = lt_set
	cvs.add_child(tikla)
	tikla.owner = root
	
	var vignette = ColorRect.new()
	vignette.name = "VignetteRect"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0,0,0,1)
	vignette.modulate.a = 0.0
	cvs.add_child(vignette)
	vignette.owner = root
	
	var crd = Label.new()
	crd.name = "CreditsLabel"
	crd.set_anchors_preset(Control.PRESET_FULL_RECT)
	crd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crd.offset_top = 800 # Ekrani asagidan baslat
	crd.text = "DEMO SONU\n\nTAM SÜRÜMDE DEVAM EDECEK\n\n\n\nBir SPHENKS Macerasi..."
	crd.visible = false
	var lc_set = LabelSettings.new()
	lc_set.font = load("res://Assets/Fonts/PressStart2P-Regular.ttf")
	lc_set.font_size = 36
	crd.label_settings = lc_set
	cvs.add_child(crd)
	crd.owner = root
	
	# SESLER
	var audio = AudioStreamPlayer3D.new()
	audio.name = "AnubisSes"
	# Eger ozel bir ilahi sesi varsa eklenecek, asagidaki ses yoksa da bostur
	root.add_child(audio)
	audio.owner = root
	
	var muz = AudioStreamPlayer.new()
	muz.name = "Muzik"
	root.add_child(muz)
	muz.owner = root
	
	var pack = PackedScene.new()
	pack.pack(root)
	var err = ResourceSaver.save(pack, "res://Scenes/demo_final.tscn")
	if err == OK:
		print("Sahne Basariyla Kaydedildi: res://Scenes/demo_final.tscn")
	else:
		print("Hata: Sahne kaydedilemedi! Kod: ", err)
