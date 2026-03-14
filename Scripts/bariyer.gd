# bariyer.gd — StaticBody3D'ye bağla
extends StaticBody3D

func _ready():
	# Layer 10 = bariyer (Unique layer)
	collision_layer = 1 << 9 # Layer 10 is 2^9
	# Sadece layer 1 ile çarpış = oyuncu
	collision_mask = 1 << 0
	
	# Mouse tıklamalarını ve raycast'leri görmezden gel
	input_ray_pickable = false
	
	add_to_group("Bariyer")
	
	# Mermi, boss, projectile bu bariyeri görmez
	# Sadece CharacterBody3D olan oyuncu çarpar

func bolum_bitti():
	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)
	print("🛡️ Bariyer açıldı (devre dışı bırakıldı).")
