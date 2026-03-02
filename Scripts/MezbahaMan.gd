extends Node

@export var kilitli_mi: bool = true

func _ready():
	add_to_group("MezbahaMan")

# No explicit interact, only hit by raycast
func get_etkilesim_yazisi() -> String:
	return ""

func interact(oyuncu: Node):
	pass
