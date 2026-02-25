extends MeshInstance3D

var hiz = 0.5 # Dönme hızı

func _process(delta):
	rotate_y(hiz * delta) # Silindiri sürekli çevir
