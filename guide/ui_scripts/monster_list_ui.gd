extends Control

class_name MonsterListUI

signal monster_selected(monster: Monster)

const MONSTER_UI_SCENE: PackedScene = preload("res://guide/scenes/monster_ui.tscn")

@onready var grid: GridContainer = $GridContainer

var current_selected: MonsterUI = null


func populate() -> void:
	deselect_all()

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	for monster in MonsterManager.get_all_monsters():
		print(monster)
		var monster_node: MonsterUI = MONSTER_UI_SCENE.instantiate()
		grid.add_child(monster_node)
		monster_node.setup(monster)
		monster_node.selected.connect(_on_monster_ui_selected.bindv([monster_node]))


func deselect_all() -> void:
	for child in grid.get_children():
		if child is MonsterUI:
			child.set_selected(false)
	current_selected = null


func _on_monster_ui_selected(monster: Monster, monster_node: MonsterUI) -> void:
	if current_selected:
		current_selected.set_selected(false)
	monster_node.set_selected(true)
	current_selected = monster_node
	monster_selected.emit(monster)
