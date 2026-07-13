extends Node

const PICKUP_SCENES: Dictionary = {
	"1": preload("res://inventory/scenes/pickup_items/apple.tscn"),
	"4": preload("res://inventory/scenes/pickup_items/axe.tscn"),
	"5": preload("res://inventory/scenes/pickup_items/log.tscn"),
	"6": preload("res://inventory/scenes/pickup_items/sword.tscn"),
	"7": preload("res://inventory/scenes/pickup_items/stone.tscn"),
	"8": preload("res://inventory/scenes/pickup_items/hammer.tscn")
}

func get_scene(item: InvItem) -> PackedScene:
	return PICKUP_SCENES.get(item.id, null)
