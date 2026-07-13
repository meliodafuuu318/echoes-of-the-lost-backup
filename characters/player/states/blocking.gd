extends PlayerState


func enter(previous_state_path: String, _data := {}) -> void:
	super(previous_state_path)
	player.health_component.is_blocking = true
	player.animation_state.travel("Block")
	player.animation_tree.set("parameters/Block/blend_position", player.facing_direction)


func physics_update(_delta: float) -> void:
	if not Input.is_action_pressed("block"):
		finished.emit(IDLE)


func exit() -> void:
	player.health_component.is_blocking = false
