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
	
	# Kapıyı GÖSTERME (başlangıçta)
	# (Bulmaca sonunda gösterilecek)
		
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

	_bulmacayi_baslat()

var nefes_sesi_player: AudioStreamPlayer
var bulmaca_layer: CanvasLayer

func _bulmacayi_baslat():
	bulmaca_layer = CanvasLayer.new()
	bulmaca_layer.layer = 105
	add_child(bulmaca_layer)
	
	var r_player = AudioStreamPlayer.new()
	r_player.stream = load("res://Sesler/dream_2.wav")
	add_child(r_player)
	
	var sub_label = Label.new()
	sub_label.text = ""
	sub_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 24)
	sub_label.add_theme_color_override("font_color", Color(1, 0, 0))
	sub_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	sub_label.add_theme_constant_override("outline_size", 8)
	var font = load("res://PressStart2P-Regular.ttf")
	if font: sub_label.add_theme_font_override("font", font)
	
	# Margin from bottom
	sub_label.offset_top = -150
	sub_label.offset_bottom = -50
	bulmaca_layer.add_child(sub_label)
	
	r_player.play()
	var d = r_player.stream.get_length() if r_player.stream else 8.0
	_altyazilari_oynat(sub_label, d)
	
	r_player.finished.connect(func():
		if is_instance_valid(sub_label): sub_label.queue_free()
		r_player.queue_free()
		_elleri_goster()
	)

func _altyazilari_oynat(lbl, d):
	lbl.text = "S*ktir, s*ktir, s*ktir!"
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(lbl): return
	lbl.text = "Uyanmam lazım!\nBu gerçek olamaz!"
	await get_tree().create_timer(4.5 - 1.2).timeout
	if not is_instance_valid(lbl): return
	lbl.text = "Evet! Parmaklarım...\nEğer rüyadaysam onları sayamamam gerekir!"

func _elleri_goster():
	if not is_instance_valid(bulmaca_layer): return
	
	# Arka planda siyah bir matlık ekleyelim el daha net görünsün.
	var bg = ColorRect.new()
	bg.color = Color(0,0,0,0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bulmaca_layer.add_child(bg)

	var tex = TextureRect.new()
	tex.texture = load("res://hand_8.png")
	tex.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	
	# Keep aspect ratio so hands don't stretch weirdly
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Make it appear coming from bottom
	tex.offset_left = -350
	tex.offset_right = 350
	
	# Başlangıçta ekranın dışında durmalılar (Aşağıda)
	tex.offset_top = 0
	tex.offset_bottom = 650
	
	bulmaca_layer.add_child(tex)
	
	# Ellerin aşağıdan yukarı çıkma animasyonu
	var tween = create_tween()
	tween.tween_property(tex, "offset_top", -650.0, 2.0).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(tex, "offset_bottom", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
	
	# Animasyon bitene kadar diğerlerini bekletelim
	await tween.finished
	if not is_instance_valid(bulmaca_layer): return
	
	var info_lbl = Label.new()
	info_lbl.text = "Parmaklarını Say..."
	info_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_font_size_override("font_size", 24)
	info_lbl.add_theme_color_override("font_color", Color(1, 0, 0))
	info_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	info_lbl.add_theme_constant_override("outline_size", 8)
	var font = load("res://PressStart2P-Regular.ttf")
	if font: info_lbl.add_theme_font_override("font", font)
	info_lbl.position.y += 50
	bulmaca_layer.add_child(info_lbl)
	
	var input = LineEdit.new()
	input.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Giriş kutusu yazının hemen altına taşındı ve küçültüldü
	input.offset_left = -80
	input.offset_right = 80
	input.offset_top = 100
	input.offset_bottom = 150
	input.placeholder_text = "Cevap?"
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_size_override("font_size", 24)
	
	# Sadece sayı girilmesine izin ver, w,a,s,d karakterleri kutuya yazılmasın.
	input.text_changed.connect(func(new_text):
		var filtered = ""
		for c in new_text:
			if c in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
				filtered += c
		if filtered != new_text:
			input.text = filtered
			input.caret_column = filtered.length()
	)
	# Odağını asla kaybetmemesini sağla
	input.focus_exited.connect(input.grab_focus)
	
	bulmaca_layer.add_child(input)
	
	# Mouse TIKLAMAYI beklemeyeceğiz, oyun akmaya devam edecek
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	input.grab_focus()
	
	input.text_submitted.connect(func(text):
		if text.strip_edges() == "16":
			# BAŞARILI
			if is_instance_valid(bulmaca_layer):
				bulmaca_layer.queue_free()
			if is_instance_valid(nefes_sesi_player):
				nefes_sesi_player.stop()
				nefes_sesi_player.queue_free()
			
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
			if has_node("KapiSistemi"):
				$KapiSistemi.visible = true
				$KapiSistemi.set_process_mode(Node.PROCESS_MODE_INHERIT)
				$KapiSistemi.kilitli_mi = false
				
			# Hemen geçiş
			_sahneyi_bitir()
		else:
			# HATALI
			var err_p = AudioStreamPlayer.new()
			err_p.stream = load("res://Sesler/ErrorSound.mp3")
			add_child(err_p)
			err_p.play()
			err_p.finished.connect(err_p.queue_free)
			
			info_lbl.text = "Yanlış! Tekrar Say..."
			input.text = ""
			input.grab_focus()
	)
	
	# Nefes sesi
	nefes_sesi_player = AudioStreamPlayer.new()
	var s_breathe = load("res://Sesler/breathe.wav")
	nefes_sesi_player.stream = s_breathe
	add_child(nefes_sesi_player)
	
	if s_breathe is AudioStreamWAV:
		s_breathe.loop_mode = AudioStreamWAV.LOOP_FORWARD
		# loop bitimi icin bir sınır belirtmeye genelde gerek kalmaz ama
		# godot otomatik loop_end i datanın sonuna koyar.
	else:
		pass
		
	# loop etmesini garantiye al
	if not nefes_sesi_player.finished.is_connected(nefes_sesi_player.play):
		nefes_sesi_player.finished.connect(nefes_sesi_player.play)
		
	nefes_sesi_player.play()

func _sahneyi_bitir():
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.has_method("odaya_don_ve_level_atla"):
		level_manager.odaya_don_ve_level_atla()
	else:
		print("Hata: LevelManager bulunamadı!")
