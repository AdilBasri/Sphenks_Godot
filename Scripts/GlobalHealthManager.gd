extends Node

## Sahne-bağımsız (persistent) sağlık yönetimi.
## Autoload olarak çalışır, sahne değişimlerinde canı korur.

signal health_changed(new_health: float)

var max_health: float = 40.0
var current_health: float = 40.0
var is_dead: bool = false

func _ready():
	# GameManager'ın mevcut sağlık sinyalini dinle ve senkronize ol
	if GameManager:
		GameManager.saglik_guncellendi.connect(_on_game_manager_health)
		# Başlangıç senkronizasyonu
		_sync_from_game_manager()

func _sync_from_game_manager():
	if not GameManager:
		return
	var max_bars := float(GameManager.oyuncu_max_bar)
	var current_hp: float = max(0.0, (float(GameManager.oyuncu_kalan_bar) - 1.0) * 10.0 + float(GameManager.oyuncu_suanki_hp))
	max_health = max_bars * 10.0
	current_health = clamp(current_hp, 0.0, max_health)
	is_dead = current_health <= 0.0

func _on_game_manager_health(bar: int, hp: int):
	var max_bars := 4.0
	if GameManager and "oyuncu_max_bar" in GameManager:
		max_bars = float(GameManager.oyuncu_max_bar)
	max_health = max_bars * 10.0
	var new_hp: float = max(0.0, (float(bar) - 1.0) * 10.0 + float(hp))
	current_health = clamp(new_hp, 0.0, max_health)
	is_dead = current_health <= 0.0
	health_changed.emit(current_health)

func take_damage(amount: float) -> void:
	current_health = float(max(0.0, current_health - amount))
	is_dead = current_health <= 0.0
	health_changed.emit(current_health)
	# GameManager'ı da güncelle
	_sync_to_game_manager()

func heal(amount: float) -> void:
	current_health = float(min(max_health, current_health + amount))
	is_dead = false
	health_changed.emit(current_health)
	_sync_to_game_manager()

func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 1.0
	return float(clamp(current_health / max_health, 0.0, 1.0))

func _sync_to_game_manager():
	if not GameManager:
		return
	var total_hp := int(current_health)
	var bars := int(total_hp / 10) + 1
	var remaining_hp := total_hp % 10
	if remaining_hp == 0 and total_hp > 0:
		bars = int(total_hp / 10)
		remaining_hp = 10
	elif total_hp <= 0:
		bars = 1
		remaining_hp = 0
	GameManager.oyuncu_kalan_bar = clamp(bars, 1, GameManager.oyuncu_max_bar)
	GameManager.oyuncu_suanki_hp = remaining_hp
