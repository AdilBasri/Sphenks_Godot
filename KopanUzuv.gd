extends RigidBody3D

var kan_havuzu_sahnesi = preload("res://KanHavuzu.tscn")
var yere_degdi = false

func _ready():
	contact_monitor = true
	max_contacts_reported = 2
	add_to_group("KopanUzuv")
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if yere_degdi: return
	
	if body is StaticBody3D or body is CSGShape3D:
		yere_degdi = true
		freeze = true
		
		if kan_havuzu_sahnesi:
			var kan = kan_havuzu_sahnesi.instantiate()
			get_tree().current_scene.add_child(kan)
			kan.global_position = global_position
			kan.position.y += 0.05
			kan.rotation.y = randf() * PI 


# --- TUTMA SİSTEMİ ---
func tutuldu():
	"""Oyuncu tarafından tutulduğunda çağrılır."""
	freeze = false
	yere_degdi = false
	gravity_scale = 0.0

func birakildi():
	"""Oyuncu tarafından bırakıldığında/fırlatıldığında çağrılır."""
	yere_degdi = false
	gravity_scale = 1.0
