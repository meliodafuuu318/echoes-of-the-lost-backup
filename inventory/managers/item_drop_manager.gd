class_name ItemDropManager
extends Node

@export var spawn_root: Node2D

@export_group("Throw Feel")
@export var throw_duration: float = 0.4
@export var throw_height: float = 24.0       # peak arc height in pixels
@export var throw_spins: float = 1.0        # full rotations while airborne

## Tracks every drop currently sitting in the world so it can be written to a
## save file and respawned on load — see get_save_data()/load_save_data().
## Keyed by the drop node's instance id so an entry can be cleanly removed the
## moment the node leaves the tree (picked up, despawned, whatever) without
## this manager needing to know *why* it left.
## Value shape: {"item_id": String, "amount": int, "position": Vector2}
var _active_drops: Dictionary = {}


func _ready() -> void:
	# Not an autoload (it's scoped to the Main scene instance), so
	# SaveManager finds it via group lookup rather than an autoload path.
	add_to_group("item_drop_manager")


## from_position: usually the player's global_position (throw origin)
## target_position: where it should land (your existing offset-in-facing-direction spot)
func spawn_item_drop(item: InvItem, amount: int, from_position: Vector2, target_position: Vector2) -> Node:
	var drop: Node = _instantiate_drop(item, amount, from_position)
	if drop == null:
		return null

	_register_drop(drop, item, amount, target_position)

	_set_pickup_enabled(drop, false)
	_animate_throw(drop, from_position, target_position)
	return drop


## Places a drop directly at its resting position with no throw animation.
## Used to restore drops that were already sitting in the world when a save
## was made — they should be exactly where they were, not re-thrown.
func restore_item_drop(item: InvItem, amount: int, position: Vector2) -> Node:
	var drop: Node = _instantiate_drop(item, amount, position)
	if drop == null:
		return null

	_register_drop(drop, item, amount, position)
	_set_pickup_enabled(drop, true)
	return drop


func _instantiate_drop(item: InvItem, amount: int, position: Vector2) -> Node:
	var packed: PackedScene = ItemSceneRegistry.get_scene(item)
	if packed == null:
		push_error("No pickup scene registered for item: ", item.name)
		return null

	var drop = packed.instantiate()

	if drop.has_method("setup"):
		drop.setup(item, amount)

	drop.global_position = position
	spawn_root.add_child(drop)
	return drop


func _register_drop(drop: Node, item: InvItem, amount: int, resting_position: Vector2) -> void:
	var key: int = drop.get_instance_id()
	_active_drops[key] = {
		"item_id": item.id,
		"amount": amount,
		"position": resting_position,
	}
	# One-shot: as soon as this node leaves the tree (picked up, freed,
	# whatever), drop it from the registry. Works regardless of how the
	# pickup scenes themselves are implemented internally.
	drop.tree_exited.connect(_on_drop_removed.bind(key), CONNECT_ONE_SHOT)


func _on_drop_removed(key: int) -> void:
	_active_drops.erase(key)


## Removes every currently-tracked drop from the world (used before restoring
## a save so stale drops from the current session don't linger alongside the
## ones being loaded in).
func clear_all_drops() -> void:
	for child in spawn_root.get_children():
		child.queue_free()
	_active_drops.clear()


func get_save_data() -> Dictionary:
	var drops: Array = []
	for entry in _active_drops.values():
		var pos: Vector2 = entry.position
		drops.append({
			"item_id": entry.item_id,
			"amount": entry.amount,
			"position": [pos.x, pos.y],
		})
	return {"drops": drops}


func load_save_data(data: Dictionary) -> void:
	clear_all_drops()
	for entry: Dictionary in data.get("drops", []):
		var item: InvItem = ItemManager.get_item_by_id(entry.get("item_id", ""))
		if item == null:
			push_warning("ItemDropManager: skipped save drop with unknown item id '%s'" % entry.get("item_id", ""))
			continue
		var pos_arr: Array = entry.get("position", [0.0, 0.0])
		var pos := Vector2(pos_arr[0], pos_arr[1])
		restore_item_drop(item, entry.get("amount", 1), pos)


func _animate_throw(drop: Area2D, from_pos: Vector2, to_pos: Vector2) -> void:
	var visual := _get_visual_node(drop)          # Sprite2D — this is what bobs upward
	var shadow: Node2D = drop.get_node_or_null("Shadow")   # stays grounded, just shrinks a bit

	var visual_base_y := visual.position.y if visual else 0.0
	var shadow_base_scale := shadow.scale if shadow else Vector2.ONE

	# Random left/right spin direction so throws don't all look identical
	var spin_dir := 1.0 if randf() < 0.5 else -1.0
	var spin_amount := spin_dir * TAU * throw_spins

	if visual:
		visual.rotation = 0.0

	# Root travels the flat ground path (so the Shadow, which sits at the
	# root's local origin, tracks correctly along the ground the whole time).
	# Only the Sprite2D lifts upward for the arc — that's what sells the throw.
	var update_frame := func(t: float) -> void:
		drop.global_position = from_pos.lerp(to_pos, t)
		var arc := throw_height * 4.0 * t * (1.0 - t)  # 0 at t=0/1, peak at t=0.5
		if visual:
			visual.position.y = visual_base_y - arc
			visual.rotation = spin_amount * t
		if shadow:
			# shadow shrinks slightly at the peak of the arc, grows back on landing
			shadow.scale = shadow_base_scale * lerp(1.0, 0.6, sin(PI * t))

	var tween := create_tween()
	tween.bind_node(drop)
	tween.tween_method(update_frame, 0.0, 1.0, throw_duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func(): _land_impact(drop, visual, visual_base_y, shadow, shadow_base_scale))


func _land_impact(drop: Area2D, visual: Node2D, visual_base_y: float, shadow: Node2D, shadow_base_scale: Vector2) -> void:
	_set_pickup_enabled(drop, true)

	if shadow:
		shadow.scale = shadow_base_scale

	if visual == null:
		return

	visual.rotation = 0.0
	visual.position.y = visual_base_y
	visual.scale = Vector2.ONE

	var bounce := create_tween()
	bounce.tween_property(visual, "scale", Vector2(1.25, 0.75), 0.08).set_trans(Tween.TRANS_SINE)
	bounce.tween_property(visual, "scale", Vector2(0.9, 1.1), 0.08).set_trans(Tween.TRANS_SINE)
	bounce.tween_property(visual, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)


## The node that visually lifts/spins during the throw. Matches your pickup
## scenes' "Sprite2D" child; falls back to the drop root if none is found.
func _get_visual_node(drop: Node) -> Node2D:
	for node_name in ["Sprite2D", "Visual", "Icon"]:
		if drop.has_node(node_name):
			return drop.get_node(node_name)
	if drop is Node2D:
		return drop
	return null


## Disables pickup collection while the item is mid-throw so the player can't
## instantly re-collect it before it lands. Your pickup scenes' root node IS
## the Area2D (apple.tscn, axe.tscn, etc.), so this toggles it directly.
func _set_pickup_enabled(drop: Node, enabled: bool) -> void:
	if drop.has_method("set_pickup_enabled"):
		drop.set_pickup_enabled(enabled)
		return
	if drop is CollisionObject2D:
		drop.set_deferred("monitoring", enabled)
		drop.set_deferred("monitorable", enabled)
