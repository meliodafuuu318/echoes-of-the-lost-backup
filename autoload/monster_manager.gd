extends Node

@export var monsters: Array[Monster] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func get_all_monsters() -> Array[Monster]:
	return monsters


func get_monster_by_id(id: String) -> Monster:
	for monster in monsters:
		if monster.id == id:
			return monster
	return null
