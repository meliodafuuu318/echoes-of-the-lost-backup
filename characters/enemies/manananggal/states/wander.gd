class_name EnemyWander
extends EnemyState

@export var speed: float = 20.0
@export var follow_range: float = 100

var player: Player

var move_direction: Vector2
var wander_time: float


func randomize_wander() -> void:
	move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	wander_time = randf_range(1, 3)


func enter(previous_state_path: String, data := {}) -> void:
	super(previous_state_path, data)
	
	player = get_tree().get_first_node_in_group("player")
	randomize_wander()


func update(delta: float) -> void:
	if wander_time > 0:
		wander_time -= delta
	else:
		randomize_wander()


func physics_update(_delta: float) -> void:
	enemy.velocity = move_direction * speed
	
	if not player or player.health_component.dead:
		return
	
	var direction = player.global_position - enemy.global_position
	
	if direction.length() < follow_range:
		finished.emit(FOLLOW)
