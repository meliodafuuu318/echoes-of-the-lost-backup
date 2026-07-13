class_name PlayerState
extends State

const IDLE = "Idle"
const WALKING = "Walking"
const ACTION = "Action"
const BLOCKING = "Blocking"
const DEAD = "Dead"

var player: Player


func _ready() -> void:
	await owner.ready
	player = owner as Player
	assert(player != null, 
			"The PlayerState state type must be used only in the player scene. It needs the owner to be a Player node.")


#func enter(_previous_state_path: String, _data := {}) -> void:
	#Events.player_state_changed.emit(self)
