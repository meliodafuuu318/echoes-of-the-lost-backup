extends Node2D

## Attached to the "Trees" node in outside.tscn, which already holds every
## pre-placed tree. Planted saplings become children of this same node so
## they behave identically to a pre-placed tree in every other respect
## (chop-for-logs, save/load via tree.gd's own get_path()-keyed persistence,
## etc.) -- the only things that make a planted tree different are that it
## starts at growth_stage 0 with a planted_day set, both of which tree.gd
## already knows how to grow from and persist on its own.
##
## Since planted trees are created at runtime, they don't exist in the
## static scene file the way Tree5/Tree14 do -- so unlike those, they need
## to be re-instantiated here on every map load before tree.gd's own
## _ready() can restore their saved state. REGISTRY_KEY tracks which planted
## trees currently exist, purely so this script knows which node names to
## recreate; it does not duplicate any of the actual tree state (position,
## growth stage, health, ...), which stays owned by tree.gd's own save data.

const TREE_SCENE: PackedScene = preload("res://objects/tree/tree.tscn")
const REGISTRY_KEY := "planted_trees"


func _ready() -> void:
	_restore_planted_trees()


func _restore_planted_trees() -> void:
	var ids: Array = GameManager.get_data_value(REGISTRY_KEY, "ids")
	if ids == null:
		return

	for id in ids:
		if has_node(id):
			continue
		var tree := TREE_SCENE.instantiate()
		tree.name = id
		call_deferred("add_child", tree)
		# tree.gd's own _ready() (which fires once it's added) restores
		# this tree's actual position/growth_stage/hp from GameManager
		# using its own get_path(), same as any other tree.


## Plants a fresh sapling at `position`. Called by Player.try_plant_sapling()
## only after it's confirmed the spot is clear.
func plant_tree(planting_position: Vector2) -> void:
	var ids: Array = GameManager.get_data_value(REGISTRY_KEY, "ids")
	if ids == null:
		ids = []

	var new_id := "PlantedTree_%d" % ids.size()
	ids.append(new_id)
	GameManager.store_data_value(REGISTRY_KEY, "ids", ids)

	var tree := TREE_SCENE.instantiate()
	tree.name = new_id
	tree.growth_stage = 0
	tree.planted_day = GameManager.day
	tree.global_position = planting_position
	call_deferred("add_child", tree)
