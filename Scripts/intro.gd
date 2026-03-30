extends Node

@onready var warning_label = $CanvasLayer/Warning
@onready var warning_text = $CanvasLayer/WarningText
@onready var logo_video = $CanvasLayer/LogoVideo

func _ready():
	print("INTRO BAŞLADI")
	# Splash ekranları sırasında fare imlecini gizle
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	print("Warning pozisyon: ", warning_label.global_position)
	print("Warning boyut: ", warning_label.size)
	warning_label.modulate.a = 0.0
	warning_text.modulate.a = 0.0
	logo_video.visible = false
	logo_video.modulate.a = 0.0
	_start_sequence()

func _start_sequence():
	await get_tree().create_timer(2.0).timeout
	
	# Warning göster
	var tween1 = create_tween()
	tween1.tween_property(warning_label, "modulate:a", 1.0, 1.0)
	await tween1.finished
	
	var tween2 = create_tween()
	tween2.tween_property(warning_text, "modulate:a", 1.0, 1.0)
	await tween2.finished
	
	await get_tree().create_timer(5.0).timeout
	
	var tween3 = create_tween()
	tween3.tween_property(warning_label, "modulate:a", 0.0, 0.8)
	await tween3.finished
	
	var tween4 = create_tween()
	tween4.tween_property(warning_text, "modulate:a", 0.0, 0.8)
	await tween4.finished
	
	await get_tree().create_timer(0.5).timeout
	
	# Video göster
	logo_video.visible = true
	var tween5 = create_tween()
	tween5.tween_property(logo_video, "modulate:a", 1.0, 1.0)
	logo_video.play()
	await tween5.finished
	
	await get_tree().create_timer(5.0).timeout
	
	var tween6 = create_tween()
	tween6.tween_property(logo_video, "modulate:a", 0.0, 1.0)
	await tween6.finished
	
	await get_tree().create_timer(10.0).timeout
	
	get_tree().change_scene_to_file("res://UI/ana_menu.tscn")
