extends PlayerState


func enter(previous_state_path: String, _data := {}) -> void:
	super(previous_state_path)
	player.animation_state.travel("Idle")
	player.animation_tree.set("parameters/Idle/blend_position", player.facing_direction)


func physics_update(_delta: float) -> void:
	var input_direction = Input.get_vector("move_left", "move_right", 
			"move_up", "move_down")
	
	if GameManager.player_weapon:
		if Input.is_action_just_pressed("action"):
			finished.emit(ACTION)
			return
		if Input.is_action_just_pressed("block") and GameManager.player_weapon.target == WeaponItem.Target.ENEMY:
			finished.emit(BLOCKING)
			return
	
	if input_direction != Vector2.ZERO:
		finished.emit(WALKING)
