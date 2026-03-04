extends Node

func _ready():
	pass

func _process(_delta):
	var m = get_tree().current_scene.find_child("MezbahaManager", true, false)
	if not m or m.is_mixing or m.wheelbarrow_pieces < 4:
		return
		
	var arabasi = get_tree().current_scene.find_child("El_arabasi", true, false)
	var mixer = self
	if not mixer is Node3D:
		mixer = get_parent()
		if not mixer is Node3D:
			mixer = get_tree().current_scene.find_child("*Mixer*", true, false)
			
	if arabasi and mixer and mixer is Node3D and arabasi is Node3D:
		var dist = arabasi.global_position.distance_to(mixer.global_position)
		if dist <= 4.0:
			if not m.loading_zone_active:
				m.loading_zone_active = true
				m.show_mixer_prompt()
		else:
			if m.loading_zone_active:
				m.loading_zone_active = false
				m.label_main.text = "El arabasını et\nparçalayıcısına sürükle"
