extends Node2D

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interact = _on_interact


func _on_interact() -> void:
	if GameManager.phase == GameManager.PHASE.NIGHT:
		Events.sleep_sequence_started.emit(6)
	else:
		Dialogic.start("sleep_timeline")
