class_name Interactable
extends Area2D

@export var interact_label: Label
@export var is_interactable: bool = true


var interact: Callable = func():
	pass


func _ready() -> void:
	interact_label.z_index = 10
	hide_label()


func show_label() -> void:
	interact_label.show()


func hide_label() -> void:
	interact_label.hide()
