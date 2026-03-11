extends CharacterBody3D

@export var hiz: float = 4.0
@export var saglik: int = 100

# --- SAHNELER ---
@export var kopan_kol_sahnesi: PackedScene 
@export var kopan_bacak_sahnesi: PackedScene 
@export var kopan_kafa_sahnesi: PackedScene
@export var kan_spreyi_sahnesi: PackedScene 

@onready var anim_player = find_child("AnimationPlayer", true, false)
@onready var iskelet = find_child("Skeleton3D", true, false)
@onready var collision_shape = $CollisionShape3D

var oyuncu = null
var suanki_durum = 0 # 0: Kosu, 1: Saldiri, 99: Olum
var kemik_on_eki = "" 

var sfx_chase: AudioStreamPlayer3D
var sfx_bite: AudioStreamPlayer3D

func _ready():
	add_to_group("Dusman")
	oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if not oyuncu: 
		oyuncu = get_tree().current_scene.find_child("Oyuncu", true, false)
		
	sfx_chase = AudioStreamPlayer3D.new()
	var c_stream = load("res://Assets/Audio/pyro_boss.mp3")
	if c_stream and c_stream is AudioStream:
		if c_stream.has_method("set_loop"): c_stream.set_loop(true)
		elif "loop" in c_stream: c_stream.loop = true
	sfx_chase.stream = c_stream
	sfx_chase.bus = "Master"
	add_child(sfx_chase)
	sfx_chase.play()
	
	sfx_bite = AudioStreamPlayer3D.new()
	sfx_bite.stream = load("res://Assets/Audio/pyro_bite.mp3")
	sfx_bite.bus = "Master"
	add_child(sfx_bite)
	
	if iskelet:
		var ilk_kemik = iskelet.get_bone_name(0)
		if "mixamorig_" in ilk_kemik: kemik_on_eki = "mixamorig_"
		elif "mixamorig:" in ilk_kemik: kemik_on_eki = "mixamorig:"
		_meta_verilerini_yukle()

	if anim_player: 
		anim_player.play("Run")

func _physics_process(delta):
	# --- 1. ÖLÜM KONTROLÜ (AYAKTA GÖMÜLMEYİ ENGELLER) ---
	if suanki_durum == 99:
		velocity = Vector3.ZERO
		if not is_on_floor(): velocity.y -= 9.8 * delta
		move_and_slide()
		return 
		
	if not oyuncu: return

	# Fener Etkisi
	if GameManager and GameManager.fener_aktif:
		if anim_player: anim_player.pause()
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Hedefe Bakış
	var hedef = oyuncu.global_position
	hedef.y = global_position.y
	look_at(hedef, Vector3.UP)
	rotate_y(deg_to_rad(180)) 
	
	var mesafe = global_position.distance_to(oyuncu.global_position)
	
	# --- 2. SALDIRI VE KOŞMA GEÇİŞİ ---
	if mesafe > 2.0:
		suanki_durum = 0
		var anlik_hiz = hiz
		if GameManager and GameManager.pyro_yavaslatma: anlik_hiz *= 0.5
		velocity = global_transform.basis.z * anlik_hiz
		if anim_player and anim_player.current_animation != "Run":
			anim_player.play("Run")
	else:
		# SALDIRI MODUNA GİRİŞ
		velocity = Vector3.ZERO
		if suanki_durum != 1:
			suanki_durum = 1
			_saldiri_animasyonunu_baslat()

	if not is_on_floor(): velocity.y -= 9.8 * delta
	move_and_slide()

# --- 3. HASAR SENKRONİZASYONU (VURMADAN VURMAYI ENGELLER) ---
func _saldiri_animasyonunu_baslat():
	if suanki_durum == 99: return
	
	if anim_player and anim_player.has_animation("Attack"):
		anim_player.play("Attack")
		
		# Animasyonun tam vuruş anına denk gelmesi için kısa bir bekleme (Örn: 0.5 sn)
		# Bu süreyi animasyonundaki vuruş anına göre elinle ayarla!
		await get_tree().create_timer(0.6).timeout
		
		# Vuruş anı geldiğinde hala hayattaysak ve oyuncu yakındaysa hasar ver
		if suanki_durum == 1 and suanki_durum != 99:
			var mesafe = global_position.distance_to(oyuncu.global_position)
			if mesafe <= 2.2:
				if oyuncu.has_method("hasar_al"):
					if sfx_bite and not sfx_bite.playing:
						sfx_bite.play()
					oyuncu.hasar_al(10) # Tam 1 Bar Can Götürür
					print("⚔️ Vuruş gerçekleşti!")
		
		# Animasyonun bitmesini bekle ki tekrar yürümesin veya vurmasın
		await anim_player.animation_finished
		
		# Animasyon bittiğinde hala yakındaysa durumu sıfırla ki tekrar vursun
		if suanki_durum != 99:
			suanki_durum = 0 

func olum_efekti():
	if suanki_durum == 99: return
	suanki_durum = 99 # Durum anında ölüye çekildi
	
	if sfx_chase and sfx_chase.playing:
		sfx_chase.stop()
	
	# --- YENİ EKLENEN: KANLI ÇİVİ DÜŞME ŞANSI (Ölüm anında) ---
	if GameManager and not GameManager.get("kanli_civi_aktif"):
		if randf() <= 0.05: # 5% ihtimal
			_kanli_civi_perki_dusur()
	
	# 1. Hareketi Durdur ama Yerçekimi Kalsın
	velocity.x = 0
	velocity.z = 0
	
	# 2. Fiziksel Etkileşimi Düzenle
	collision_layer = 0 # Kimse ona çarpamaz
	collision_mask = 1  # O sadece yere çarpar (Dünya katmanı)
	
	# 3. Hitboxları (Area3D) Anında Sil
	for child in iskelet.get_children():
		if child is BoneAttachment3D:
			child.queue_free()

	# 4. Ölüm Animasyonunu Zorla Başlat
	if anim_player:
		anim_player.stop() # Koşma veya Saldırı ne varsa kes
		if anim_player.has_animation("Death"):
			anim_player.play("Death")
			# Animasyonun bitmesini (karakterin yere yatmasını) bekle
			await anim_player.animation_finished
		else:
			# Eğer animasyon yoksa karakteri en azından yana devir (Düz batmasın)
			var fall_tween = create_tween()
			fall_tween.tween_property(self, "rotation:x", deg_to_rad(-90), 0.6)
			await fall_tween.finished

	# 5. KRİTİK: Karakterin Yerçekimiyle Tam Zemine Oturmasını Sağla
	# Animasyon havada bitmiş olabilir, yere değene kadar bekle
	var timeout = 0.0
	while not is_on_floor() and timeout < 1.5:
		velocity.y -= 9.8 * 0.1
		move_and_slide()
		await get_tree().create_timer(0.05).timeout
		timeout += 0.05

	# 6. Yerde Bekleme Süresi (2.5 saniye ceset yerde kalsın)
	await get_tree().create_timer(2.5).timeout
	
	# 7. Gömülme Başlıyor
	# Artık takılmaması için CollisionShape'i tamamen kapatıyoruz
	collision_shape.set_deferred("disabled", true)
	
	var tween_sink = create_tween()
	# Karakterin yattığı yerden aşağı doğru batış
	tween_sink.tween_property(self, "global_position:y", global_position.y - 2.0, 4.0).set_trans(Tween.TRANS_SINE)
	tween_sink.tween_callback(queue_free)

# --- DİĞER FONKSİYONLAR (HASAR VE UZUV) ---
func hasar_al_bolgesel(bolge_adi: String):
	if suanki_durum == 99: return
	_kan_fiskirt(bolge_adi)
	match bolge_adi:
		"Head":
			if _uzuv_orada_mi("Head"):
				uzuv_firlat("Head", kopan_kafa_sahnesi); kemik_gizle("Head"); hasar_ver(100)
		"RightArm", "LeftArm":
			if _uzuv_orada_mi(bolge_adi):
				uzuv_firlat(bolge_adi, kopan_kol_sahnesi); _kol_kopar(bolge_adi); hasar_ver(25)
		"RightLeg", "LeftLeg":
			var kemik = "RightUpLeg" if bolge_adi == "RightLeg" else "LeftUpLeg"
			if _uzuv_orada_mi(kemik):
				uzuv_firlat(bolge_adi, kopan_bacak_sahnesi); _bacak_kopar(bolge_adi); hasar_ver(30)
		_:
			hasar_ver(15)

func hasar_ver(miktar: int):
	saglik -= miktar
	if saglik <= 0: olum_efekti()

func kemik_gizle(saf_kemik_adi: String):
	var idx = iskelet.find_bone(kemik_on_eki + saf_kemik_adi)
	if idx != -1: iskelet.set_bone_pose_scale(idx, Vector3(0.001, 0.001, 0.001))

func uzuv_firlat(kemik_adi: String, sahne: PackedScene):
	if not sahne: return
	var parca = sahne.instantiate()
	get_tree().current_scene.add_child(parca)
	
	parca.global_position = global_position + Vector3(0, 1.2, 0)
	
	if parca is RigidBody3D:
		# Parça karakterin kendi fiziğine takılmasın
		parca.add_collision_exception_with(self) 
		
		# Rastgele ve daha gerçekçi savrulma
		var yon = Vector3(randf_range(-1.0, 1.0), 1.0, randf_range(-1.0, 1.0)).normalized()
		parca.apply_central_impulse(yon * 4.0)
		parca.angular_velocity = Vector3(randf()*5, randf()*5, randf()*5)

func _kan_fiskirt(bolge_adi: String):
	if not kan_spreyi_sahnesi: return
	var kan = kan_spreyi_sahnesi.instantiate()
	get_tree().current_scene.add_child(kan)
	kan.global_position = global_position + Vector3(0, 1.3, 0)
	if kan is GPUParticles3D: kan.emitting = true
	get_tree().create_timer(2.0).timeout.connect(kan.queue_free)

func _uzuv_orada_mi(kemik: String) -> bool:
	var idx = iskelet.find_bone(kemik_on_eki + kemik)
	return iskelet.get_bone_pose_scale(idx).x > 0.1

func _kol_kopar(taraf: String):
	if taraf == "RightArm":
		kemik_gizle("RightArm"); kemik_gizle("RightForeArm"); kemik_gizle("RightHand")
	else:
		kemik_gizle("LeftArm"); kemik_gizle("LeftForeArm"); kemik_gizle("LeftHand")

func _bacak_kopar(taraf: String):
	hiz *= 0.6
	if taraf == "RightLeg":
		kemik_gizle("RightUpLeg"); kemik_gizle("RightLeg")
	else:
		kemik_gizle("LeftUpLeg"); kemik_gizle("LeftLeg")

func _meta_verilerini_yukle():
	var tanimlar = { "KAFA": "Head", "Sag_Kol": "RightArm", "Sol_Kol": "LeftArm", "Sag_Bacak": "RightLeg", "Sol_Bacak": "LeftLeg" }
	for node_adi in tanimlar:
		var bone_node = iskelet.find_child(node_adi, true, false)
		if bone_node:
			var area = bone_node.find_child("Area3D", true, false)
			if area: area.set_meta("Bolge", tanimlar[node_adi])

# --- YENİ EKLENEN: PERK UI ---
func _kanli_civi_perki_dusur():
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(canvas)
	
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.8)
	panel.add_theme_stylebox_override("panel", sb)
	canvas.add_child(panel)
	
	var label = Label.new()
	label.text = DilYoneticisi.metin_al("perk_soru")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.RED)
	panel.add_child(label)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Center horizontally and position closer to center vertical
	hbox.anchor_top = 0.6
	hbox.anchor_bottom = 0.6
	hbox.add_theme_constant_override("separation", 50)
	panel.add_child(hbox)
	
	var btn_evet = Button.new()
	btn_evet.text = DilYoneticisi.metin_al("evet")
	btn_evet.custom_minimum_size = Vector2(150, 50)
	hbox.add_child(btn_evet)
	
	var btn_hayir = Button.new()
	btn_hayir.text = DilYoneticisi.metin_al("hayir")
	btn_hayir.custom_minimum_size = Vector2(150, 50)
	hbox.add_child(btn_hayir)
	
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var cleanup = func():
		canvas.queue_free()
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	btn_evet.pressed.connect(func():
		GameManager.kanli_civi_aktif = true
		if GameManager.has_method("oyunu_kaydet"):
			GameManager.oyunu_kaydet()
		cleanup.call()
	)
	
	btn_hayir.pressed.connect(cleanup)
