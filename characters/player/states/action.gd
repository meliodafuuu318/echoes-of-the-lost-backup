extends PlayerState


func enter(previous_state_path: String, _data := {}) -> void:
	super(previous_state_path)
	if not player.animation_tree.animation_finished.is_connected(_on_animation_tree_animation_finished):
		player.animation_tree.animation_finished.connect(_on_animation_tree_animation_finished)

	if GameManager.player_weapon.target == WeaponItem.Target.ENEMY:
		player.animation_state.start("Attack")
		player.animation_tree.set("parameters/Attack/blend_position", player.facing_direction)

	elif GameManager.player_weapon.target == WeaponItem.Target.OBJECT:
		player.animation_state.start("Chop")
		player.animation_tree.set("parameters/Chop/blend_position", player.facing_direction)


func _on_animation_tree_animation_finished(_anim_name: StringName) -> void:
	if player.state_machine.state != self:
		return
	finished.emit(IDLE)


func exit() -> void:
	if player.animation_tree.animation_finished.is_connected(_on_animation_tree_animation_finished):
		player.animation_tree.animation_finished.disconnect(_on_animation_tree_animation_finished)
