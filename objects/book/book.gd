extends StaticBody2D

@onready var interactable: Interactable = $Interactable
@onready var book: Node2D = $"."


func _ready() -> void:
	if GameManager.book_found:
		book.queue_free()
	interactable.interact = _on_interact
	
	
func _on_interact(_player: Player) -> void:
	if GameManager.book_found:
		return
	
	Dialogic.start("book_found_timeline")
	
	GameManager.book_found = true
	Events.book_found.emit()
	book.queue_free()
