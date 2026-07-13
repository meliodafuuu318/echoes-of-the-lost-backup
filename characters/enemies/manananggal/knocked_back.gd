class_name EnemyKnockedBack
extends EnemyState

@export var friction: float = 300

var knockback_velocity: Vector2 = Vector2.ZERO


func enter(_previous_state_path: String, data := {}) -> void:
	if data.has("velocity"):
		knockback_velocity = data["velocity"]
		enemy.velocity = knockback_velocity
	else:
		finished.emit(WANDER)


func physics_update(delta: float) -> void:
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, friction * delta)
	enemy.velocity = knockback_velocity
	
	if knockback_velocity.length_squared() < 10.0:
		finished.emit(WANDER)
