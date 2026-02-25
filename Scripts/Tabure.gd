extends StaticBody3D

@onready var camera_position_marker = $CameraPos
@onready var exit_position_marker = $ExitPos

func interact(player):
	print("Tabure ile etkileşime girildi!")
	if player.has_method("sit_on_stool"):
		player.sit_on_stool(self)
