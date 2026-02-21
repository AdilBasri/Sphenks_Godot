extends Node3D
class_name BaseDream

# --- Dream Base Class ---

func _ready():
	print("☁️ Rüya Başladı: ", name)
	_setup_dream()

func _setup_dream():
	# 1. Oyuncunun kontrollerini kapat
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu:
		oyuncu.set_process_input(false)
		oyuncu.set_physics_process(false)
		
		# Silahı gizle
		if oyuncu.has_method("silah_gizle"):
			oyuncu.silah_gizle()
			
		# Mide UI gizle (opsiyonel)
		var mide_ui = oyuncu.find_child("MideUI", true, false)
		if mide_ui: mide_ui.visible = false
		
	# 2. Dream Shader (UI Overlay)
	_apply_dream_shader()

func _apply_dream_shader():
	# Basit bir ColorRect + Shader overlay ekle (CanvasLayer içinde)
	var canvas = CanvasLayer.new()
	canvas.layer = 100 # En üstte
	add_child(canvas)
	
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.1, 0.0, 0.2, 0.3) # Hafif mor sis
	# İlerde shader atanabilir: overlay.material = load(...)
	canvas.add_child(overlay)

func wake_up(next_scene_path: String):
	print("☀️ Rüya bitti, uyanılıyor -> ", next_scene_path)
	
	# Fade out efekti ile sahne değiştir
	var t = create_tween()
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		var overlay = canvas.get_child(0)
		t.tween_property(overlay, "color", Color.BLACK, 1.5)
	
	await t.finished
	get_tree().change_scene_to_file(next_scene_path)
