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
const HONEY_TREE_COUNT := 2
## Direct child name to skip when picking honey-tree candidates -- these
## trees exist for visual/map-filler purposes but aren't reachable by the
## player, so a honey tree should never end up stuck out there.
const OFF_ISLAND_GROUP_NAME := "Off-Island Trees"


func _ready() -> void:
	_restore_planted_trees()
	Events.honey_tree_died.connect(_on_honey_tree_died)
	# Deferred so it runs after _restore_planted_trees()'s call_deferred
	# add_child calls have actually landed, and after any is_honey_tree
	# overrides already baked into the pre-placed Tree5/Tree8-style nodes
	# in the scene file are in place to count against the total.
	call_deferred("_ensure_honey_trees")


func _restore_planted_trees() -> void:
	var ids = GameManager.get_data_value(REGISTRY_KEY, "ids")
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
	var ids = GameManager.get_data_value(REGISTRY_KEY, "ids")
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


## Every direct-child Tree that's reachable and still alive -- i.e. not the
## "Off-Island Trees" sub-container (or anything under it) and not a tree
## that's already mid-death (has_died true, queue_free() pending but not
## necessarily processed yet).
func _get_eligible_trees() -> Array:
	var eligible: Array = []
	for child in get_children():
		if child.name == OFF_ISLAND_GROUP_NAME:
			continue
		if not ("is_honey_tree" in child):
			continue
		if "has_died" in child and child.has_died:
			continue
		eligible.append(child)
	return eligible


## Tops the honey tree count back up to HONEY_TREE_COUNT by marking random
## eligible trees, without touching any that are already marked. Called once
## at startup and again (deferred) whenever a honey tree dies, so the map
## always settles back to exactly HONEY_TREE_COUNT reachable honey trees.
func _ensure_honey_trees() -> void:
	var eligible := _get_eligible_trees()
	var current_honey := eligible.filter(func(t): return t.is_honey_tree)
	var missing := HONEY_TREE_COUNT - current_honey.size()
	if missing <= 0:
		return

	var candidates := eligible.filter(func(t): return not t.is_honey_tree)
	candidates.shuffle()
	for i in range(min(missing, candidates.size())):
		candidates[i].is_honey_tree = true


func _on_honey_tree_died(_tree: Node) -> void:
	# The dying tree emits this from _on_died() before its queue_free() has
	# actually been processed, so give it a frame to leave the tree before
	# recounting -- otherwise it'd still show up as an eligible honey tree.
	call_deferred("_ensure_honey_trees")
