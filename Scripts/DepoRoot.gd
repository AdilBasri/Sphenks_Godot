extends Node3D

# --- REFERANSLAR ---
@onready var dog = $dog
@onready var anubis_talk = $anubis_talk
@onready var paper = $paper
@onready var kapi = $Kapi

# The Note System
var kagitt_okunuyor_mu: bool = false
var kagit_okundu_mu: bool = false # Kagidi 1 kez bile kapatti mi? Kapinin gozukmesi icin!
var paper_orijinal_transform: Transform3D
var paper_label: Label3D
var paper_glow_timer: float = 0.0
var paper_glow_artiyor: bool = true
var paper_tween: Tween # Animasyonlarin cakismemesi icin

# The Choice
var secim_yapildi_mi: bool = false
var ses_oynatici: AudioStreamPlayer3D

func _ready() -> void:
	if kapi:
		kapi.visible = false # Baslangicta kapi yok
		var st = kapi.find_child("StaticBody3D", true, false)
		if st: st.collision_layer = 0 # carpisma kapali
		
	_kopek_kurulumu()
	_kagit_kurulumu()
	_kapi_kurulumu()

func _process(delta: float) -> void:
	if not kagitt_okunuyor_mu and not secim_yapildi_mi and paper:
		if paper_glow_artiyor:
			paper_glow_timer += delta * 1.5
			if paper_glow_timer >= 1.0:
				paper_glow_timer = 1.0
				paper_glow_artiyor = false
		else:
			paper_glow_timer -= delta * 1.5
			if paper_glow_timer <= 0.2:
				paper_glow_timer = 0.2
				paper_glow_artiyor = true
				
		var isik = paper.get_node_or_null("GlowLight")
		if isik:
			isik.light_energy = paper_glow_timer * 2.0

func _kopek_kurulumu():
	if not dog: return
	
	var static_body = StaticBody3D.new()
	static_body.collision_layer = 1
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.5, 2.5, 2.5) 
	col.shape = shape
	col.position = Vector3(0, 1.0, 0)
	static_body.add_child(col)
	dog.add_child(static_body)
	
	var script = GDScript.new()
	script.source_code = """
extends StaticBody3D
func interact(oyuncu):
	get_parent().get_parent()._anubis_beslendi()
func get_etkilesim_yazisi() -> String:
	return DilYoneticisi.metin_al("besle")
"""
	script.reload()
	static_body.set_script(script)

	var anim_player = dog.get_node_or_null("AnimationPlayer")
	if anim_player:
		if anim_player.has_animation("barking"):
			var anim = anim_player.get_animation("barking")
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play("barking")
		else:
			anim_player.play("barking") 
	
	ses_oynatici = AudioStreamPlayer3D.new()
	var stream_audio = load("res://Sesler/dog.mp3")
	if stream_audio is AudioStreamMP3:
		stream_audio.loop = true
	ses_oynatici.stream = stream_audio
	ses_oynatici.unit_size = 5.0
	ses_oynatici.max_distance = 40.0
	ses_oynatici.autoplay = true
	ses_oynatici.bus = "Master"
	dog.add_child(ses_oynatici)

func _kagit_kurulumu():
	if not paper: return
	
	paper_orijinal_transform = paper.global_transform
	
	var isik = OmniLight3D.new()
	isik.name = "GlowLight"
	isik.light_color = Color(1.0, 0.9, 0.7) 
	isik.light_energy = 0.5
	isik.omni_range = 2.0
	isik.position = Vector3(0, 0.7, -0.5) 
	paper.add_child(isik)
	
	var static_body = StaticBody3D.new()
	static_body.collision_layer = 1
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(15.0, 15.0, 15.0)  # Okuma alanini 3 katina cikardik
	col.shape = shape
	static_body.add_child(col)
	paper.add_child(static_body)
	
	var script = GDScript.new()
	script.source_code = """
extends StaticBody3D
func interact(oyuncu):
	get_parent().get_parent()._kagit_etkilesimi()
func get_etkilesim_yazisi() -> String:
	return DilYoneticisi.metin_al("oku")
"""
	script.reload()
	static_body.set_script(script)
	
	paper_label = Label3D.new()
	paper_label.text = DilYoneticisi.metin_al("depo_mektup")
	paper_label.font = load("res://Captain Redemption.ttf")
	paper_label.font_size = 48
	paper_label.modulate = Color(0.1, 0.1, 0.1, 0.0)
	paper_label.outline_size = 0
	paper_label.pixel_size = 0.032 # Yaziyi daha da buyuttuk
	paper_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED 
	paper_label.no_depth_test = true 
	paper.add_child(paper_label)
	paper_label.transform.origin = Vector3(0, 0.5, 0.2) 

func _kapi_kurulumu():
	if not kapi: return
	
	var kapi_body = kapi.find_child("StaticBody3D", true, false)
	if kapi_body:
		var script = GDScript.new()
		script.source_code = """
extends StaticBody3D
func interact(oyuncu):
	get_parent().get_parent().get_parent()._kapi_etkilesimi()
func get_etkilesim_yazisi() -> String:
	return DilYoneticisi.metin_al("kapidan_cik")
"""
		script.reload()
		kapi_body.set_script(script)

func _kagit_etkilesimi():
	if secim_yapildi_mi: return
	
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if not oyuncu: return
	
	var kamera = oyuncu.kamera
	if not kamera: return
	
	kagitt_okunuyor_mu = !kagitt_okunuyor_mu
	
	oyuncu.weapon_input_disabled = kagitt_okunuyor_mu
	oyuncu.mouse_serbest_modu = false 
	oyuncu.set_physics_process(!kagitt_okunuyor_mu) 
	
	if paper_tween:
		paper_tween.kill()
	paper_tween = create_tween()
	paper_tween.set_parallel(true)
	
	if kagitt_okunuyor_mu:
		var hedef_transform = kamera.global_transform
		hedef_transform.origin += hedef_transform.basis.z * -1.8 
		hedef_transform.basis = kamera.global_transform.basis
		hedef_transform.basis = hedef_transform.basis.rotated(hedef_transform.basis.x, deg_to_rad(90))
		
		# kagida cevirirken her zaman orijinal scale'i (0.02) referans alarak buyutuyoruz (Spam hatasini onler)
		var base_scale = paper_orijinal_transform.basis.get_scale()
		var new_scale = base_scale * 6.0 # Okunabilirlik icin 3.5'ten 6.0'a cikarildi
		
		paper_tween.tween_property(paper, "global_transform", hedef_transform, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		paper_tween.tween_property(paper, "scale", new_scale, 0.5)
		paper_tween.tween_property(paper_label, "modulate:a", 1.0, 0.5).set_delay(0.2)
		
		var isik = paper.get_node_or_null("GlowLight")
		if isik: 
			isik.omni_range = 10.0
			# Mektup ile oyuncu arasina (kameraya dogru) cekiyoruz.
			# Mektup rotasyonu nedeniyle Z-ekseni ters dondugu icin negatif degerle oyuncuya yaklastiriyoruz.
			paper_tween.tween_property(isik, "position", Vector3(0, 2.0, -2.5), 0.3) 
			paper_tween.tween_property(isik, "light_energy", 3.0, 0.3) 
	else:
		paper_tween.tween_property(paper, "global_transform", paper_orijinal_transform, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		paper_tween.tween_property(paper, "scale", paper_orijinal_transform.basis.get_scale(), 0.5) 
		paper_tween.tween_property(paper_label, "modulate:a", 0.0, 0.2)
		
		var isik = paper.get_node_or_null("GlowLight")
		if isik: 
			isik.omni_range = 2.0
			paper_tween.tween_property(isik, "position", Vector3(0, 0.5, -0.5), 0.3)
			paper_tween.tween_property(isik, "light_energy", 0.5, 0.3)
		
		if not kagit_okundu_mu:
			kagit_okundu_mu = true
			if kapi:
				kapi.visible = true
				var st = kapi.find_child("StaticBody3D", true, false)
				if st: st.collision_layer = 1
				
				kapi.scale = Vector3(0.01, 1.0, 0.01)
				var kapi_tw = create_tween()
				kapi_tw.tween_property(kapi, "scale", Vector3(1,1,1), 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _siradaki_sahneyi_yukle(alternatif: bool = false):
	var siradaki_katman = 1
	if LevelManager:
		siradaki_katman = LevelManager.suanki_katman
		
	var path_str = "res://KATMAN_" + str(siradaki_katman)
	if alternatif:
		path_str += "_ALTERNATIF.tscn"
	else:
		path_str += ".tscn"
		
	if not ResourceLoader.exists(path_str):
		print("HATA: " + path_str + " BULUNAMADI! LevelManager ile ana menuye ya da Sphenks.tscn'e donuluyor...")
		if LevelManager and LevelManager.has_method("odaya_don_ve_level_atla"):
			LevelManager.odaya_don_ve_level_atla()
		else:
			get_tree().change_scene_to_file("res://Scenes/Sphenks.tscn")
	else:
		get_tree().change_scene_to_file(path_str)


func _golgeleri_kapat_recursive(node: Node):
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_golgeleri_kapat_recursive(c)

func _anubis_beslendi():
	if kagitt_okunuyor_mu or secim_yapildi_mi: return
	
	secim_yapildi_mi = true
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu:
		oyuncu.weapon_input_disabled = true
		oyuncu.set_physics_process(false)
		
		if oyuncu.etkilesim_label:
			oyuncu.etkilesim_label.text = ""
			
		# Sadece elde tutulan nesneyi sil (%100 fener/el kalacak sadece blok silinecek yeme sistemi gibi)
		if "tutulan_nesne" in oyuncu and oyuncu.tutulan_nesne:
			if is_instance_valid(oyuncu.tutulan_nesne):
				oyuncu.tutulan_nesne.queue_free()
		
		# eger el modeline (depo_hand) islenmis statik bir BlokTek objesi varsa onu da gizle/sil:
		var depo_hand = oyuncu.get_node_or_null("Camera3D/Node3D")
		if depo_hand:
			var blok_tek = depo_hand.find_child("BlokTek", true, false)
			if blok_tek:
				blok_tek.visible = false
				blok_tek.queue_free()
		
	if dog:
		_golgeleri_kapat_recursive(dog)
		dog.visible = false
		dog.process_mode = Node.PROCESS_MODE_DISABLED
	
	var white_shader = ColorRect.new()
	white_shader.set_anchors_preset(Control.PRESET_FULL_RECT)
	white_shader.color = Color(1, 1, 1, 0)
	var canvas = CanvasLayer.new()
	canvas.layer = 100 # En ust katmana geri aldik, cunku altyaziyi da buraya ekliyoruz
	canvas.add_child(white_shader)
	
	# Ozel Altyazi Label'i Olustur
	var altyazi_label = Label.new()
	altyazi_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	altyazi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	altyazi_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	altyazi_label.offset_top = -150
	altyazi_label.offset_bottom = -50
	altyazi_label.modulate.a = 0.0 # Baslangicta gorunmez
	var font_ayari = LabelSettings.new()
	font_ayari.font = load("res://Assets/Fonts/PressStart2P-Regular.ttf")
	font_ayari.font_size = 16
	font_ayari.font_color = Color(1.0, 1.0, 0.2) # Parlak Sari
	font_ayari.outline_size = 6
	font_ayari.outline_color = Color.BLACK
	altyazi_label.label_settings = font_ayari
	canvas.add_child(altyazi_label)
	
	add_child(canvas)
	
	var tween = create_tween()
	
	# Pompalanmis parlama (0.2s icinde)
	tween.tween_property(white_shader, "color:a", 1.0, 0.2)
	
	# Ekran bembeyazken Anubis'i goster
	tween.tween_callback(func():
		if anubis_talk:
			anubis_talk.visible = true
			var anim = anubis_talk.get_node_or_null("AnimationPlayer")
			if anim:
				anim.play("talk")
				
		# İlk altyaziyi hazirla ve gorunur yap
		altyazi_label.text = DilYoneticisi.metin_al("depo_anubis_1")
		var yazi_tw = create_tween()
		yazi_tw.tween_property(altyazi_label, "modulate:a", 1.0, 0.5)
	)
	
	# Geriye fading baslarken altyazi yukarida donuyor olacak
	tween.tween_property(white_shader, "color:a", 0.0, 0.8)
	
	# Ilk diyalogu okumasi icin GELISTIRILMIS bekleme suresi: 5 Saniye
	tween.tween_interval(5.0)
	
	# Ikinci diyaloga gec (Onceki yaziyi kisa surede silip digerini getir)
	tween.tween_callback(func():
		var yazi_tw = create_tween()
		yazi_tw.tween_property(altyazi_label, "modulate:a", 0.0, 0.3)
		yazi_tw.tween_callback(func():
			altyazi_label.text = DilYoneticisi.metin_al("depo_anubis_2")
		)
		yazi_tw.tween_property(altyazi_label, "modulate:a", 1.0, 0.3)
	)
	
	# Ikinci diyalogu okumasi icin bekleme suresi: 5 Saniye
	tween.tween_interval(5.0)
	
	# Sonraki sahneye atla (Gecis oncesi ekrani tekrar kapatabiliriz)
	tween.tween_property(white_shader, "color:a", 1.0, 0.5)
	tween.tween_property(altyazi_label, "modulate:a", 0.0, 0.5)
	
	# Gecis
	tween.tween_callback(func():
		_siradaki_sahneyi_yukle(false)
	)


func _kapi_etkilesimi():
	if kagitt_okunuyor_mu or secim_yapildi_mi: return
	
	secim_yapildi_mi = true
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu:
		oyuncu.weapon_input_disabled = true
		oyuncu.set_physics_process(false)
		
		if oyuncu.etkilesim_label:
			oyuncu.etkilesim_label.text = ""
		
	_siradaki_sahneyi_yukle(true)
