extends Node

class_name PlayerStats

@export var max_bars: int = 4
@export var bar_hp: int = 10

var current_bars: int = 4
var current_hp: int = 10
var is_dead: bool = false
var is_down: bool = false

signal health_changed(bars, hp)
signal player_died
signal player_downed

func setup(bars: int, hp: int):
	current_bars = bars
	current_hp = hp

func take_damage(amount: int):
	if is_dead: return
	
	current_hp -= amount
	if current_hp <= 0:
		current_bars -= 1
		if current_bars <= 0:
			die()
		else:
			current_hp = bar_hp
			# Optional: trigger "downed" or "injured" state
	
	health_changed.emit(current_bars, current_hp)

func die():
	is_dead = true
	player_died.emit()
