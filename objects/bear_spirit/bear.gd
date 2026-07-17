extends CharacterBody2D

@onready var interactable: Interactable = $Interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interactable.interact = _on_interact

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_interact(player: Player) -> void:
	Dialogic.VAR.set_variable("BearSpirit.introduced", GameManager.bear_introduced)
	Dialogic.start("bear_spirit_timeline")
	player.state_machine.set_physics_process(false)
	player.state_machine._transition_to_next_state(PlayerState.IDLE)
	
	await Dialogic.timeline_ended
	
	player.state_machine.set_physics_process(true)
	
	if not GameManager.bear_introduced:
		GameManager.bear_introduced = true
	
