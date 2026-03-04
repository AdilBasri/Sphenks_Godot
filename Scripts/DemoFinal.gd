extends Node3D

# Tum dusme ve canavar model referanslari - _ready() icinde olusturulacak
var dusme_modeli: Node3D = null
var yumruk_modeli: Node3D = null
var dusme_ap: AnimationPlayer = null
var yumruk_ap: AnimationPlayer = null
var skeleton: Skeleton3D = null
var cam_bone: BoneAttachment3D = null
var kamera: Camera3D = null
var zemin_cukur: CSGBox3D = null

# UI referanslari
var altyazi_label: Label = null
var gorsel_tikla_label: Label = null
var vignette: ColorRect = null
var credits: Label = null
var muzik: AudioStreamPlayer = null

# Durum degiskenleri
var asama = 1
var canavar_spine_bone = -1
var canavar_neck_bone = -1
var kamera_rot: Vector2 = Vector2.ZERO
var dusme_temas_etti = false
var vurma_sayisi = 0
var anim_falling = "mixamo_com"
var anim_punching = "mixamo_com"
var canavar_root: Node3D = null

var anubis_satirlar = [
	"Bizler icin yaptigin her hamleden oturu
sana mutesekkiriz benim kucuk kanli muridim!",
	"Ama artik sana ihtiyacimiz yok...",
	"Bundan sonra yok olarak tanrina en buyuk
degeri bahsedebilirsin piyon!",
	"Merak etme, oteki alemde senin icin
cehennemin en guzel yerlerinden birinde
yer ayiracagim...",
	"HAHAHAHA!"
]

var intikam_satirlar = [
	"Asagiliklar! Asagilik Anubis!
Lanet olsun hepinize!",
	"Beni bir silah gibi kullandiniz!
Kirli islerinizi yaptirdiniz!",
	"Bana cehennemde beni yakacak olan
atesin odunlarini toplattiniz!",
	"Sana guvenmemeliydim lanet olasi seytan!",
	"Lanet olsun sana Anubis!
Beni duyuyor musun!",
	"Intikamimi alacagim senden!
Hepinizi tek tek oldurecegim!",
	"HEPINIZ OLECEKSINIZ LANET OLASICALAR!"
]

var _satir_idx = 0
var _satir_list: Array = []

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_sahneyi_kur()
	_ui_kur()
	_asama_1_baslat()

func _sahneyi_kur():
	# --- ODA (CSG) ---
	var oda = Node3D.new()
	oda.name = "Oda"
	add_child(oda)
	
	var ana_kutu = CSGBox3D.new()
	ana_kutu.name = "AnaKutu"
	ana_kutu.size = Vector3(20, 10, 20)
	ana_kutu.use_collision = true
	oda.add_child(ana_kutu)
	
	var ic_bosluk = CSGBox3D.new()
	ic_bosluk.operation = CSGShape3D.OPERATION_SUBTRACTION
	ic_bosluk.size = Vector3(19, 9, 19)
	ana_kutu.add_child(ic_bosluk)
	
	# Demo tiles kaplama - meshten material al
	var demo_tile_mat: Material = null
	var tile_scene = load("res://demo_tiles/scene.gltf") as PackedScene
	if tile_scene:
		var tile_inst = tile_scene.instantiate()
		var tile_mesh = tile_inst.find_child("MeshInstance3D", true, false) as MeshInstance3D
		if not tile_mesh:
			for c in tile_inst.get_children():
				if c is MeshInstance3D:
					tile_mesh = c
					break
		if tile_mesh and tile_mesh.mesh and tile_mesh.mesh.get_surface_count() > 0:
			demo_tile_mat = tile_mesh.mesh.surface_get_material(0)
		tile_inst.queue_free()
	
	if demo_tile_mat:
		ana_kutu.material = demo_tile_mat
	else:
		# Fallback: duvar_tiles
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.92, 0.92)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(3, 3, 3)
		var tex = load("res://Assets/Images/duvar_tiles.png") as Texture2D
		if tex: mat.albedo_texture = tex
		ana_kutu.material = mat
	
	# Cukur
	zemin_cukur = CSGBox3D.new()
	zemin_cukur.name = "ZeminCukur"
	zemin_cukur.operation = CSGShape3D.OPERATION_SUBTRACTION
	zemin_cukur.size = Vector3(10, 20, 10)
	zemin_cukur.position = Vector3(0, -14, 0)
	oda.add_child(zemin_cukur)
	
	# Isik
	var omni = OmniLight3D.new()
	omni.position = Vector3(0, 3, 0)
	omni.omni_range = 30.0
	omni.light_energy = 1.0
	add_child(omni)
	
	# --- CANAVAR ---
	canavar_root = Node3D.new()
	canavar_root.name = "Canavar"
	add_child(canavar_root)
	
	var falling_packed = load("res://Falling.fbx") as PackedScene
	if falling_packed:
		dusme_modeli = falling_packed.instantiate()
		dusme_modeli.name = "DusmeModeli"
		canavar_root.add_child(dusme_modeli)
		dusme_ap = dusme_modeli.find_child("AnimationPlayer", true, false) as AnimationPlayer
		skeleton = dusme_modeli.find_child("Skeleton3D", true, false) as Skeleton3D
		if dusme_ap and dusme_ap.get_animation_list().size() > 0:
			anim_falling = dusme_ap.get_animation_list()[0]
		print("Dusme animasyonu: ", anim_falling)
	
	var yumruk_packed = load("res://Zombie Punching.fbx") as PackedScene
	if yumruk_packed:
		yumruk_modeli = yumruk_packed.instantiate()
		yumruk_modeli.name = "YumrukModeli"
		yumruk_modeli.visible = false
		canavar_root.add_child(yumruk_modeli)
		yumruk_ap = yumruk_modeli.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if yumruk_ap and yumruk_ap.get_animation_list().size() > 0:
			anim_punching = yumruk_ap.get_animation_list()[0]
		print("Yumruk animasyonu: ", anim_punching)
	
	# Kamera
	cam_bone = BoneAttachment3D.new()
	cam_bone.name = "CameraBone"
	if skeleton:
		cam_bone.use_external_skeleton = true
		for b in ["mixamorig_Head", "Head", "head", "mixamorig:Head"]:
			if skeleton.find_bone(b) != -1:
				cam_bone.bone_name = b
				break
	canavar_root.add_child(cam_bone)
	if skeleton:
		cam_bone.external_skeleton = cam_bone.get_path_to(skeleton)
	
	var cam_node = Camera3D.new()
	cam_node.position = Vector3(0, 0.05, 0.0)
	cam_node.rotation.y = PI  # 180 derece cevirme (kafa kemiginin yoni)
	cam_node.current = true
	cam_bone.add_child(cam_node)
	kamera = cam_node
	
	# Omurga kemikleri (bakis yonu icin)
	if skeleton:
		canavar_spine_bone = skeleton.find_bone("Spine")
		canavar_neck_bone = skeleton.find_bone("Neck")
		if canavar_spine_bone == -1: canavar_spine_bone = skeleton.find_bone("mixamorig_Spine")
		if canavar_neck_bone == -1: canavar_neck_bone = skeleton.find_bone("mixamorig_Neck")

func _ui_kur():
	var cvs = CanvasLayer.new()
	add_child(cvs)
	
	var font = load("res://Assets/Fonts/PressStart2P-Regular.ttf") as Font
	
	altyazi_label = Label.new()
	altyazi_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	altyazi_label.offset_top = -160
	altyazi_label.offset_bottom = -50
	altyazi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	altyazi_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	altyazi_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	altyazi_label.modulate.a = 0.0
	var l_set = LabelSettings.new()
	if font: l_set.font = font
	l_set.font_size = 16
	l_set.font_color = Color(1.0, 1.0, 0.2)
	l_set.outline_size = 4
	l_set.outline_color = Color.BLACK
	altyazi_label.label_settings = l_set
	cvs.add_child(altyazi_label)
	
	gorsel_tikla_label = Label.new()
	gorsel_tikla_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gorsel_tikla_label.offset_bottom = 80
	gorsel_tikla_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gorsel_tikla_label.text = "VURMAK ICIN TIKLA!"
	gorsel_tikla_label.visible = false
	var lt_set = LabelSettings.new()
	if font: lt_set.font = font
	lt_set.font_size = 20
	lt_set.font_color = Color(1, 0, 0)
	lt_set.outline_size = 3
	lt_set.outline_color = Color.BLACK
	gorsel_tikla_label.label_settings = lt_set
	cvs.add_child(gorsel_tikla_label)
	
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0, 0, 0, 1)
	vignette.modulate.a = 0.0
	cvs.add_child(vignette)
	
	credits = Label.new()
	credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credits.text = "DEMO SONU\n\nTAM SURUMDE DEVAM EDECEK\n\n\nBir SPHENKS Macerasi..."
	credits.visible = false
	var lc_set = LabelSettings.new()
	if font: lc_set.font = font
	lc_set.font_size = 30
	lc_set.font_color = Color.WHITE
	credits.label_settings = lc_set
	cvs.add_child(credits)
	
	muzik = AudioStreamPlayer.new()
	add_child(muzik)

func _input(event):
	if event is InputEventMouseMotion:
		kamera_rot.y -= event.relative.x * 0.002
		kamera_rot.x -= event.relative.y * 0.002
		kamera_rot.x = clamp(kamera_rot.x, -1.0, 1.0)
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if asama == 3:
			_yumruk_at()

func _process(delta):
	if skeleton and canavar_spine_bone != -1 and asama >= 1:
		var q_y = Quaternion(Vector3.UP, kamera_rot.y)
		var q_x = Quaternion(Vector3.RIGHT, kamera_rot.x)
		var final_q = q_y * q_x
		var rest = skeleton.get_bone_rest(canavar_spine_bone)
		skeleton.set_bone_pose_position(canavar_spine_bone, rest.origin)
		skeleton.set_bone_pose_rotation(canavar_spine_bone, rest.basis.get_rotation_quaternion() * final_q)
		
	# WASD hareket (canavar_root'u kamera bakis yonune gore hareket ettir)
	var mv_hiz = 5.0 * delta
	var hareket = Vector3.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		hareket -= Vector3(sin(kamera_rot.y), 0, cos(kamera_rot.y)) * mv_hiz
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		hareket += Vector3(sin(kamera_rot.y), 0, cos(kamera_rot.y)) * mv_hiz
	if Input.is_key_pressed(KEY_A):
		hareket -= Vector3(cos(kamera_rot.y), 0, -sin(kamera_rot.y)) * mv_hiz
	if Input.is_key_pressed(KEY_D):
		hareket += Vector3(cos(kamera_rot.y), 0, -sin(kamera_rot.y)) * mv_hiz
	if canavar_root:
		canavar_root.position += hareket
	
	if asama == 2 and dusme_ap and not dusme_temas_etti:
		if dusme_ap.current_animation == anim_falling and dusme_ap.current_animation_position > 1.0:
			dusme_ap.seek(0.1, true)

func _asama_1_baslat():
	asama = 1
	_yazi_sira_baslat(anubis_satirlar, false)
	get_tree().create_timer(12.0).timeout.connect(_duvarlari_kir)

func _yazi_sira_baslat(satirlar: Array, dongu: bool):
	_satir_list = satirlar
	_satir_idx = 0
	_yazi_satir_goster(dongu)

func _yazi_satir_goster(dongu: bool):
	if _satir_idx >= _satir_list.size():
		if dongu:
			_satir_idx = 0
			_yazi_satir_goster(dongu)
		return
	altyazi_label.text = _satir_list[_satir_idx]
	var tw = create_tween()
	tw.tween_property(altyazi_label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.5)
	tw.tween_property(altyazi_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		_satir_idx += 1
		_yazi_satir_goster(dongu)
	)

func _duvarlari_kir():
	asama = 2
	if dusme_ap:
		dusme_ap.play(anim_falling)
	var dusme_tw = create_tween()
	dusme_tw.tween_property(canavar_root, "position:y", canavar_root.position.y - 20.0, 3.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	dusme_tw.tween_callback(_yere_carpilma)

func _yere_carpilma():
	dusme_temas_etti = true
	if dusme_ap and dusme_ap.current_animation == anim_falling:
		dusme_ap.seek(1.1, true)
		dusme_ap.speed_scale = 1.0
	get_tree().create_timer(3.0).timeout.connect(_asama_3_baslat)

func _asama_3_baslat():
	asama = 3
	if dusme_modeli: dusme_modeli.visible = false
	if yumruk_modeli: yumruk_modeli.visible = true
	gorsel_tikla_label.visible = true
	# Intikam satirlari sira sira goster
	_yazi_sira_baslat(intikam_satirlar, true)

func _yumruk_at():
	if yumruk_ap and yumruk_ap.is_playing() and yumruk_ap.current_animation_position < 0.5:
		return
	if yumruk_ap:
		yumruk_ap.speed_scale = 1.5
		yumruk_ap.play(anim_punching)
	if kamera:
		kamera.h_offset = randf_range(-0.1, 0.1)
		kamera.v_offset = randf_range(-0.1, 0.1)
		var s_tw = create_tween()
		s_tw.tween_property(kamera, "h_offset", 0.0, 0.2)
		s_tw.parallel().tween_property(kamera, "v_offset", 0.0, 0.2)
	vurma_sayisi += 1
	if vurma_sayisi > 8:
		_asama_4_baslat()

func _asama_4_baslat():
	if asama == 4: return
	asama = 4
	gorsel_tikla_label.visible = false
	altyazi_label.visible = false
	var tw = create_tween()
	tw.tween_property(vignette, "modulate:a", 1.0, 2.0)
	if muzik:
		muzik.play()
		tw.parallel().tween_property(muzik, "volume_db", 0.0, 3.0)
	tw.tween_interval(2.0)
	tw.tween_callback(func():
		credits.visible = true
		var c_tw = create_tween()
		c_tw.tween_property(credits, "position:y", -300, 10.0)
	)
	get_tree().create_timer(15.0).timeout.connect(func():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file("res://Scenes/Sphenks.tscn")
	)
