extends PlayerState

const TILE_SIZE: float = 24

var last_position: Vector2


func enter(previous_state_path: String, _data := {}) -> void:
	super(previous_state_path)
	last_position = player.global_position
	
	player.animation_state.travel("Walk")


func physics_update(_delta: float) -> void:
	var input_direction = Input.get_vector("move_left", "move_right", 
			"move_up", "move_down")
	
	if GameManager.player_weapon:
		if Input.is_action_just_pressed("action"):
			finished.emit(ACTION)
			return
		elif Input.is_action_just_pressed("block") and GameManager.player_weapon.target == WeaponItem.Target.ENEMY:
			finished.emit(BLOCKING)
			return
	
	if input_direction == Vector2.ZERO:
		finished.emit(IDLE)
		return
	
	player.facing_direction = input_direction
	player.velocity = input_direction * player.speed
	
	player.animation_tree.set("parameters/Walk/blend_position", player.facing_direction)
	
	player.move_and_slide()
	
	handle_walk_task()


func handle_walk_task() -> void:
	var step = player.global_position.distance_to(last_position)
	player.walk_distance_accum += step
	last_position = player.global_position

	while player.walk_distance_accum >= TILE_SIZE:
		DailyTaskManager.update_task_progress("4", 1)
		player.walk_distance_accum -= TILE_SIZE
