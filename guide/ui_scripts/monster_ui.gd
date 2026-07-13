extends Panel

class_name MonsterUI

signal selected(monster: Monster)

var monster: Monster

@onready var sprite: AnimatedSprite2D = $NinePatchRect/AnimatedSprite2D
@onready var label: Label = $NinePatchRect/Label


func setup(monster_item: Monster) -> void:
	monster = monster_item
	label.text = monster.name
	set_selected(false)


func set_selected(is_selected: bool) -> void:
	sprite.play("selected" if is_selected else "default")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(monster)
