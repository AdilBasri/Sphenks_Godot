extends Node

func _ready():
	var area = Area3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(10, 8, 10) # increase trigger
	coll.shape = shape
	area.add_child(coll)
	get_parent().call_deferred("add_child", area)
	
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	if body.is_in_group("Oyuncu") or body.name == "El_arabasi" or (body.get_parent() and body.get_parent().name == "El_arabasi"):
		var m = get_tree().current_scene.find_child("MezbahaManager", true, false)
		if m:
			m.show_mixer_prompt()
