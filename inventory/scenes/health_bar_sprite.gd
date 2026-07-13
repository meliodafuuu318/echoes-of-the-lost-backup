class_name HealthBar
extends Sprite2D

const TOTAL_FRAMES = 6


func _ready() -> void:
	Events.player_health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(GameManager.player_health)


func _on_player_health_changed(current_health: float) -> void:
	if GameManager.MAX_PLAYER_HEALTH <= 0:
		return
	
	if current_health == GameManager.MAX_PLAYER_HEALTH:
		frame = 0
		return
	
	if current_health <= 0:
		frame = TOTAL_FRAMES - 1
		return
	
	var health_pct: float = (current_health / GameManager.MAX_PLAYER_HEALTH) * 100.0
	
	if health_pct < 20:
		frame = 4
	elif health_pct < 40:
		frame = 3
	elif health_pct < 60:
		frame = 2
	else:
		frame = 1 
