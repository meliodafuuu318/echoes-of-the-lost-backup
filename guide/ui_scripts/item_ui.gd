extends Panel

class_name ItemUI

signal selected(item: InvItem)

var item: InvItem

@onready var sprite: AnimatedSprite2D = $NinePatchRect/AnimatedSprite2D
@onready var label: Label = $NinePatchRect/Label


func setup(inv_item: InvItem) -> void:
	item = inv_item
	label.text = item.name
	set_selected(false)


func set_selected(is_selected: bool) -> void:
	sprite.play("selected" if is_selected else "default")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(item)
