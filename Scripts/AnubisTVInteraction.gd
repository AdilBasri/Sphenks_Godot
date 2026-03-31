extends StaticBody3D

@export var interaction_text: String = "anubis_video_etkilesim"

@onready var video_player: VideoStreamPlayer = get_parent().get_node("SubViewport/VideoStreamPlayer")
@onready var video_sprite: Sprite3D = get_parent().get_node("Sprite3D")
@onready var unlem: Node3D = get_tree().current_scene.find_child("unlem", true, false)

var is_playing: bool = false
var current_video_path: String = "res://tv/anubis.ogv"
var subtitle_label: RichTextLabel = null
var subtitle_canvas: CanvasLayer = null

func _ready():
	add_to_group("Etkilesim")
	if video_player:
		video_player.autoplay = false
		video_player.loop = false
		video_player.stop()
		video_player.finished.connect(_on_video_finished)
	
	if video_sprite:
		video_sprite.visible = false
		
	# --- ÜNLEM KONTROLÜ ---
	if unlem:
		var hazir = GameManager.is_new_video_available if GameManager else true
		unlem.visible = hazir
		print("📺 TV: Unlem Durumu = ", hazir)
		# Her şeyin üzerinde çizilmesi için material override (No Depth Test)
		_unlem_shader_ayarla(unlem)
	else:
		print("⚠️ TV: 'unlem' objesi bulunamadi!")

func _unlem_shader_ayarla(node: Node):
	if not is_instance_valid(node): return
	if node is MeshInstance3D:
		var mat = node.get_active_material(0)
		if mat and mat is StandardMaterial3D:
			mat.no_depth_test = true
			mat.render_priority = 100
	for child in node.get_children():
		_unlem_shader_ayarla(child)

func get_etkilesim_yazisi() -> String:
	if is_playing:
		return ""
	return DilYoneticisi.metin_al("anubis_video_etkilesim") if DilYoneticisi else "Anubis'i dinle"

func interact(_player = null):
	if is_playing: return
	
	if GameManager:
		# Eğer yeni video varsa, indexi artır ve durumu kaydet
		if GameManager.is_new_video_available:
			# Eğer daha önce hiç izlenmemişse Anubis (0) kalır, yoksa bir sonrakine geçer
			if GameManager.last_video_watched_layer != -1:
				GameManager.current_video_index = clampi(GameManager.current_video_index + 1, 0, 2)
			
			GameManager.last_video_watched_layer = GameManager.suanki_seviye
			GameManager.is_new_video_available = false
			print("📺 TV: Yeni video baslatiliyor. Index: ", GameManager.current_video_index)
	
	# Ünlemi gizle
	if unlem: unlem.visible = false
	
	is_playing = true
	
	# Doğru videoyu yükle
	var v_index = GameManager.current_video_index if GameManager else 0
	var v_name = "anubis.ogv"
	if v_index == 1: v_name = "ktm2.ogv"
	elif v_index == 2: v_name = "ktm3.ogv"
	
	var v_path = "res://tv/" + v_name
	if video_player:
		var stream = load(v_path)
		if stream:
			video_player.stream = stream
			if video_sprite: video_sprite.visible = true
			video_player.play()
			start_subtitles()
		else:
			print("HATA: Video dosyasi bulunamadi: ", v_path)
			is_playing = false

func _on_video_finished():
	is_playing = false
	if video_sprite:
		video_sprite.visible = false
	if is_instance_valid(subtitle_canvas):
		subtitle_canvas.queue_free()

func start_subtitles():
	if is_instance_valid(subtitle_canvas):
		subtitle_canvas.queue_free()
		
	subtitle_canvas = CanvasLayer.new()
	subtitle_canvas.layer = 100
	get_tree().current_scene.add_child(subtitle_canvas)
	
	subtitle_label = RichTextLabel.new()
	subtitle_label.bbcode_enabled = true
	subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_label.offset_top = -120
	subtitle_label.offset_bottom = -20
	subtitle_label.offset_left = 150
	subtitle_label.offset_right = -150
	
	subtitle_label.add_theme_font_size_override("normal_font_size", 19)
	subtitle_label.add_theme_color_override("default_color", Color(0.9, 0.1, 0.1, 1.0))
	subtitle_label.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle_label.add_theme_constant_override("outline_size", 4)
	
	var retro_font = load("res://Assets/Fonts/PressStart2P-Regular.ttf")
	if retro_font:
		subtitle_label.add_theme_font_override("normal_font", retro_font)
	
	subtitle_canvas.add_child(subtitle_label)
	_run_subtitle_sequence()

func _run_subtitle_sequence():
	var v_index = GameManager.current_video_index if GameManager else 0
	
	match v_index:
		0: # anubis.ogv (17s approx)
			show_subtitle("anubis_subtitles_1", 1.8)
			await get_tree().create_timer(1.8).timeout
			if not is_playing: return
			show_subtitle("anubis_subtitles_2", 3.2)
			await get_tree().create_timer(3.2).timeout
			if not is_playing: return
			show_subtitle("anubis_subtitles_3", 3.5)
			await get_tree().create_timer(3.5).timeout
			if not is_playing: return
			show_subtitle("anubis_subtitles_4", 3.5)
			await get_tree().create_timer(3.5).timeout
			if not is_playing: return
			show_subtitle("anubis_subtitles_5", 5.0)
		1: # ktm2.ogv (14s)
			show_subtitle("ktm2_sub_1", 4.0)
			await get_tree().create_timer(4.0).timeout
			if not is_playing: return
			show_subtitle("ktm2_sub_2", 3.0)
			await get_tree().create_timer(3.0).timeout
			if not is_playing: return
			show_subtitle("ktm2_sub_3", 3.0)
			await get_tree().create_timer(3.0).timeout
			if not is_playing: return
			show_subtitle("ktm2_sub_4", 4.0)
		2: # ktm3.ogv (20s)
			show_subtitle("ktm3_sub_1", 4.0)
			await get_tree().create_timer(4.0).timeout
			if not is_playing: return
			show_subtitle("ktm3_sub_2", 4.0)
			await get_tree().create_timer(4.0).timeout
			if not is_playing: return
			show_subtitle("ktm3_sub_3", 4.0)
			await get_tree().create_timer(4.0).timeout
			if not is_playing: return
			show_subtitle("ktm3_sub_4", 8.0)

func show_subtitle(key: String, duration: float):
	if not is_instance_valid(subtitle_label): return
	
	var text = DilYoneticisi.metin_al(key) if DilYoneticisi else key
	subtitle_label.text = "[center][shake rate=20.0 level=5]" + text + "[/shake][/center]"
	subtitle_label.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(duration - 1.0)
	tween.tween_property(subtitle_label, "modulate:a", 0.0, 0.5)
