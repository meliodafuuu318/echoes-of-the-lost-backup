extends Node
 
class_name ItemDB
 
const ITEMS_PATH = "res://inventory/resources/inventory_items/"
var items: Dictionary = {}
 
func _ready() -> void:
	_load_all_items()
 
func _load_all_items() -> void:
	"""Load all item resources at startup"""
	var dir = DirAccess.open(ITEMS_PATH)
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var item: InvItem = load(ITEMS_PATH + file)
				if item:
					items[item.id] = item
			file = dir.get_next()
 
func get_item(item_id: String) -> InvItem:
	"""Get item resource by ID"""
	return items.get(item_id)
 
func get_item_names() -> Array[String]:
	"""Get all item IDs"""
	return items.keys()
