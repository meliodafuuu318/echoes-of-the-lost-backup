class_name EnemyState
extends State

const WANDER = "Wander"
const FOLLOW = "Follow"
const KNOCKED_BACK = "KnockedBack"

var enemy: Enemy


func _ready() -> void:
	await owner.ready
	enemy = owner as Enemy
	assert(enemy != null, 
			"The EnemyState state type must be used only in the enemy scene. It needs the owner to be a Enemy node.")


func enter(_previous_state_path: String, _data := {}) -> void:
	enemy.health_component.health_changed.connect(_on_health_changed)


func exit() -> void:
	if enemy.health_component.health_changed.is_connected(_on_health_changed):
		enemy.health_component.health_changed.disconnect(_on_health_changed)


func _on_health_changed(_current_health: float, attack: Attack) -> void:
	var knockback = (enemy.global_position - attack.attack_position).normalized() * attack.knockback_force
	finished.emit(KNOCKED_BACK, { "velocity": knockback })
