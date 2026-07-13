extends ProgressBar

var health: int = 0:
	set(new_health):
		var prev_health = health
		health = min(max_value, new_health)
		value = health
		
		if health <= 0:
			queue_free()
		
		if health < prev_health:
			timer.start()
		else:
			damage_bar.value = health

@onready var damage_bar: ProgressBar = $DamageBar
@onready var timer: Timer = $Timer


func init_health(_health: int) -> void:
	max_value = _health
	health = _health
	value = health
	damage_bar.max_value = health
	damage_bar.value = health


func _on_timer_timeout() -> void:
	damage_bar.value = health
