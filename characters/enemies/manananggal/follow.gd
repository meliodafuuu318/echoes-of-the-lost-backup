class_name EnemyFollow
extends EnemyState

@export var max_range: float = 120
@export var speed: float = 40.0

var player: Player


func enter(previous_state_path: String, data := {}) -> void:
	super(previous_state_path, data)
	player = get_tree().get_first_node_in_group("player")


func physics_update(_delta: float) -> void:
	if not player or player.health_component.dead:
		finished.emit(WANDER)
		return
	
	var direction = player.global_position - enemy.global_position
	
	if direction.length() > 10:
		enemy.velocity = direction.normalized() * speed
	else:
		enemy.velocity = Vector2.ZERO
	
	if direction.length() > max_range:
		finished.emit(WANDER)
