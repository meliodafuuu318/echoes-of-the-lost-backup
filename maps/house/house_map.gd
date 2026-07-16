extends Node2D


func _ready() -> void:
	# Only ever play once per save. GameManager.cabin_entered is restored by
	# SaveManager before this scene is entered, so this also correctly stays
	# skipped after a load, not just within a single play session.
	if GameManager.cabin_entered:
		return

	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_warning("HouseMap: no player found in 'player' group, skipping cabin_entered_timeline.")
		return

	_play_cabin_entered_timeline(player)


func _play_cabin_entered_timeline(player: Player) -> void:
	player.velocity = Vector2.ZERO
	player.state_machine.set_physics_process(false)
	player.state_machine._transition_to_next_state(PlayerState.IDLE)

	Dialogic.start("cabin_entered_timeline")
	await Dialogic.timeline_ended

	player.state_machine.set_physics_process(true)

	GameManager.cabin_entered = true
