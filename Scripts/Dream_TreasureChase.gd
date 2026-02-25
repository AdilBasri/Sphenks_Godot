extends BaseDream

# --- Dream_TreasureChase ---
# Oyuncu sandığa yaklaştıkça sandık uzaklaşır (Tantalus efekti)

@export var treasure_chest: Node3D
@export var min_distance: float = 3.0
@export var retreat_speed: float = 2.0
@export var limit_distance: float = 50.0 # Belli bir yerden sonra sonlanır

var player: Node3D

func _ready():
	super._ready() # BaseDream setup
	player = get_tree().get_first_node_in_group("Oyuncu")
	
	# Oyuncunun yürümesine izin ver (BaseDream kapatmıştı, tekrar aç)
	if player:
		player.set_physics_process(true)
		player.set_process_input(true)
		# Ama silahı kapalı kalsın
		if player.has_method("silah_gizle"):
			player.silah_gizle()

func _process(delta):
	if not player or not treasure_chest: return
	
	var disp = treasure_chest.global_position - player.global_position
	var dist = disp.length()
	
	# Eğer oyuncu çok yaklaştıysa sandık kaçsın
	if dist < min_distance:
		var dir = disp.normalized()
		# Y eksenini koru (yerde kalsın)
		dir.y = 0
		treasure_chest.global_position += dir * retreat_speed * delta
		
		# Sandık hareket ederken hafif zıplasın/sallansın
		treasure_chest.rotation.z = sin(Time.get_ticks_msec() * 0.01) * 0.1

	# Belli bir mesafe gittikten sonra rüya biter (Uyanış)
	if treasure_chest.global_position.length() > limit_distance:
		wake_up("res://Scenes/PyroKoridoru.tscn") # 2. Level'a uyanış
