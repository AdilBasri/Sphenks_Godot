extends Node

@export var kilitli_mi: bool = false
@export var etkilesim_yazisi: String = "[E] Baltayi Al"

func _ready():
	var parent_body = get_parent()
	if parent_body is CollisionObject3D:
		parent_body.collision_layer = 1 # Keep it interactable on default raycast layer

func get_etkilesim_yazisi() -> String:
	return etkilesim_yazisi

func interact(oyuncu: Node):
	if kilitli_mi: return
	
	var manager = get_tree().current_scene.find_child("MezbahaManager", true, false)
	if manager:
		manager.axe_picked_up()
		
	# Hide the physical axe
	var parent_ax = get_parent()
	if parent_ax:
		parent_ax.hide()
		# Optionally queue_free if we don't need it later
		parent_ax.queue_free()
