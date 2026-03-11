extends Node

class_name PlayerActions

@export var player: CharacterBody3D
@export var interactor: PlayerInteractor
@export var stats: PlayerStats

# Eating system
var is_eating: bool = false
var bite_timer: Timer
var bite_interval: float = 0.6
var sfx_eat: AudioStreamPlayer

# signals
signal action_started(action_name)
signal action_finished(action_name)

func _ready():
	sfx_eat = AudioStreamPlayer.new()
	sfx_eat.bus = "Master"
	add_child(sfx_eat)
	var eat_stream = load("res://Assets/Audio/eat.mp3")
	if eat_stream is AudioStreamMP3:
		eat_stream.loop = true
	sfx_eat.stream = eat_stream

func start_eating(held_object: RigidBody3D):
	if is_eating: return
	if not held_object or not held_object.is_in_group("KopanUzuv"): return
	
	# Capacity check (delegated to GameManager usually)
	if GameManager and GameManager.limbs_eaten_this_round >= GameManager.get_stomach_capacity():
		# Notify rejection
		return

	is_eating = true
	sfx_eat.play()
	action_started.emit("eating")
	
	# Setup timer logic
	if bite_timer: bite_timer.queue_free()
	bite_timer = Timer.new()
	bite_timer.wait_time = bite_interval
	add_child(bite_timer)
	bite_timer.timeout.connect(_take_bite)
	bite_timer.start()
	_take_bite()

func _take_bite():
	if not is_eating: return
	# Delegate the actual bite logic to the held object and trigger effects
	# This will be handled by signals back to player or direct access

func stop_eating():
	if not is_eating: return
	is_eating = false
	sfx_eat.stop()
	if bite_timer: bite_timer.stop()
	action_finished.emit("eating")

# Item usage logic
func use_item(item_node, item_data):
	if not item_node: return
	# Big match statement logic goes here...
	pass
