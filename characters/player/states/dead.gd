extends PlayerState


func enter(previous_state_path: String, _data := {}) -> void:
	super(previous_state_path)
	player.hurtbox_component.set_deferred("monitorable", false)
	player.shadow.hide()
