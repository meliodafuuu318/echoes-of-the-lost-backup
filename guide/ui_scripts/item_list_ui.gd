extends Control

class_name ItemListUI

signal item_selected(item: InvItem)

const ITEM_UI_SCENE: PackedScene = preload("res://guide/scenes/item_ui.tscn")

@onready var grid: GridContainer = $GridContainer

var current_selected: ItemUI = null


func populate() -> void:
	deselect_all()

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	for item in ItemManager.get_all_items():
		print(item)
		var item_node: ItemUI = ITEM_UI_SCENE.instantiate()
		grid.add_child(item_node)
		item_node.setup(item)
		item_node.selected.connect(_on_item_ui_selected.bindv([item_node]))


func deselect_all() -> void:
	for child in grid.get_children():
		if child is ItemUI:
			child.set_selected(false)
	current_selected = null


func _on_item_ui_selected(item: InvItem, item_node: ItemUI) -> void:
	if current_selected:
		current_selected.set_selected(false)
	item_node.set_selected(true)
	current_selected = item_node
	item_selected.emit(item)
