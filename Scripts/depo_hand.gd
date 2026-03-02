extends Node3D

@onready var isik = $SpotLight3D

var time = 0.0
var walk_speed = 12.0
var walk_amount = 0.015
var base_pos: Vector3

var player: CharacterBody3D

func _ready():
	base_pos = position
	# Oyuncu/Camera3D/Node3D şeklinde bir hiyerarşimiz var
	var p = get_parent()
	if p and p.get_parent() is CharacterBody3D:
		player = p.get_parent()

func _process(delta):
	# Prosedürel Yürüme Animasyonu (Headbob/Sway)
	if player:
		var flat_vel = Vector3(player.velocity.x, 0, player.velocity.z)
		var speed = flat_vel.length()
		
		# Oyuncu yerdeyse ve hareket ediyorsa
		if speed > 0.5 and player.is_on_floor():
			time += delta * walk_speed * (speed / 3.0)
			
			var bob_y = sin(time) * walk_amount
			var bob_x = cos(time * 0.5) * walk_amount * 1.2
			var target_pos = base_pos + Vector3(bob_x, bob_y, 0)
			
			position = position.lerp(target_pos, delta * 8.0)
			
			# Doğal el sallanması (Rotation)
			var rot_z = sin(time * 0.5) * 0.02
			rotation.z = lerp(rotation.z, rot_z, delta * 8.0)
			rotation.x = lerp(rotation.x, bob_y * 0.5, delta * 8.0)
			
			# İleri geri mouse sway eklentisi (oyuncu döndüğünde fener gecikmeli gelir)
		else:
			# Dururken yumuşakça merkeze dön
			position = position.lerp(base_pos, delta * 4.0)
			rotation.z = lerp(rotation.z, 0.0, delta * 4.0)
			rotation.x = lerp(rotation.x, 0.0, delta * 4.0)
			time = 0.0
