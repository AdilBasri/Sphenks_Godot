extends OmniLight3D
var zaman = 0.0
func _process(delta):
	zaman += delta * 10
	light_energy = 1.0 + (sin(zaman) * 0.5) + randf_range(-0.2, 0.2)
	# Korku filmi gibi sürekli gidip gelen ışık
