extends Node2D

## Spawns grass in organic random patches across the ground TileMapLayer.
## Grass avoids the full footprint of the Cabin and every Stone (not just
## their exact position), but intentionally does NOT avoid Trees — patches
## are free to grow right under them.
##
## The layout is seeded through GameManager.grass_patch_seed so the exact
## same patches reappear after a save/load instead of re-rolling every time
## the map loads. See SaveManager._serialize_game_manager() /
## _deserialize_game_manager(), which persist grass_patch_seed just like
## GameManager.anting_anting_saved_pos.

const GRASS_SCENE: PackedScene = preload("res://objects/grass/grass.tscn")

## Ground layer to scatter grass onto. Wire this in the editor (see node_paths
## on the Grass node in outside.tscn) or it will auto-resolve to "../Layers/Ground".
@export var ground_layer: TileMapLayer

## Soil overlaps part of the ground layer (e.g. tilled/farmable patches).
## Any tile that appears in both layers is excluded from valid spawn area —
## grass only spawns on ground tiles that are NOT also soil tiles. Wire this
## in the editor or it will auto-resolve to "../Layers/Soil".
@export var soil_layer: TileMapLayer

## Containers whose children are treated as no-spawn obstacles — grass is
## excluded from each obstacle's full footprint (not just its exact center
## point), measured from its CollisionShape2D if it has one. Defaults to
## "../Objects" (the Cabin) and "../Stones" if left empty. Trees are
## intentionally NOT included here — grass is fine growing under trees.
@export var obstacle_container_paths: Array[NodePath] = []

## Extra buffer (px) added around every obstacle's measured footprint radius,
## so grass doesn't spawn flush against the edge of a stone/the cabin.
@export var obstacle_padding: float = 8.0

## Fallback footprint radius (px) for an obstacle where no CollisionShape2D
## could be found to measure automatically.
@export var default_obstacle_radius: float = 16.0

## Target percentage of ground tiles that should end up covered in grass.
@export_range(0.0, 1.0, 0.01) var coverage_min: float = 0.30
@export_range(0.0, 1.0, 0.01) var coverage_max: float = 0.40

## How big each individual patch is allowed to grow, in tile count.
@export var min_patch_size: int = 5
@export var max_patch_size: int = 20

## Controls how densely each patch fills itself in as it grows.
## 0.0 = loose: each step picks a uniformly random frontier tile, so patches
##       sprawl into gappy, tendril-like shapes (more like a random walk).
## 1.0 = tight: each step prefers whichever frontier tile already borders the
##       most already-placed grass, so patches fill in solidly first and read
##       as dense, roughly circular blobs before spreading outward.
@export_range(0.0, 1.0, 0.01) var patch_tightness: float = 0.75

## If true, patches can grow diagonally too (rounder blobs). If false,
## patches only grow up/down/left/right (more jagged, plus-shaped blobs).
@export var use_diagonal_growth: bool = true

## Editor/debug only: forces a brand-new random layout (and overwrites the
## seed stored on GameManager) even if one is already saved. Leave this off
## for normal play so loaded saves keep their original grass layout.
@export var force_reseed: bool = false


func _ready() -> void:
	_resolve_seed()
	_spawn_grass_patches()


## Reuses the seed already stored on GameManager (e.g. restored from a save)
## so the grass layout stays identical across saves/loads. If none exists yet
## (first time this map is ever entered, or force_reseed is on), rolls a new
## one and stores it back on GameManager immediately — mirroring how
## _spawn_anting_anting() in outside.gd generates-and-saves on first spawn.
func _resolve_seed() -> void:
	if force_reseed or GameManager.grass_patch_seed == 0:
		var new_seed: int = randi()
		while new_seed == 0:
			new_seed = randi()
		GameManager.grass_patch_seed = new_seed

	seed(GameManager.grass_patch_seed)
	print("[GrassSpawner] seed = ", GameManager.grass_patch_seed)


func _spawn_grass_patches() -> void:
	# Defensive: clear out any previously spawned grass first, in case this
	# ever runs more than once (e.g. force_reseed toggled at runtime).
	for child in get_children():
		child.queue_free()

	if ground_layer == null:
		ground_layer = get_node_or_null("../Layers/Ground")

	if ground_layer == null:
		push_warning("[GrassSpawner] No ground_layer assigned or found!")
		return

	if soil_layer == null:
		soil_layer = get_node_or_null("../Layers/Soil")

	var ground_cells: Array[Vector2i] = ground_layer.get_used_cells()
	if ground_cells.is_empty():
		push_warning("[GrassSpawner] Ground layer has no used cells!")
		return

	# Soil overlaps the ground layer in places (e.g. tilled patches) — exclude
	# any cell that's used in both, so grass only ever lands on "pure" ground.
	var soil_lookup: Dictionary = {}
	if soil_layer != null:
		for cell in soil_layer.get_used_cells():
			soil_lookup[cell] = true

	var obstacles: Array[Dictionary] = _gather_obstacles()

	var all_cells: Array[Vector2i] = []
	for cell in ground_cells:
		if soil_lookup.has(cell):
			continue
		var world_pos: Vector2 = ground_layer.to_global(ground_layer.map_to_local(cell))
		if _is_inside_obstacle(world_pos, obstacles):
			continue
		all_cells.append(cell)

	if all_cells.is_empty():
		push_warning("[GrassSpawner] No ground tiles left after excluding soil overlap and obstacles!")
		return

	var cell_lookup: Dictionary = {}
	for cell in all_cells:
		cell_lookup[cell] = true

	var target_coverage: float = randf_range(coverage_min, coverage_max)
	var target_count: int = int(round(all_cells.size() * target_coverage))

	var selected: Dictionary = {}
	var shuffled_cells: Array = all_cells.duplicate()
	shuffled_cells.shuffle()

	var seed_index: int = 0
	var safety_counter: int = 0
	var max_safety: int = target_count * 30 + 500

	while selected.size() < target_count and safety_counter < max_safety:
		safety_counter += 1

		if seed_index >= shuffled_cells.size():
			# Ran out of fresh seed candidates but still need more coverage —
			# reshuffle and keep trying (growth naturally skips already-selected cells).
			shuffled_cells.shuffle()
			seed_index = 0

		var start_cell: Vector2i = shuffled_cells[seed_index]
		seed_index += 1

		if selected.has(start_cell):
			continue

		var patch_size: int = randi_range(min_patch_size, max_patch_size)
		_grow_patch(start_cell, patch_size, cell_lookup, selected, target_count)

	for cell in selected.keys():
		_place_grass(cell)

	var achieved_pct: float = (float(selected.size()) / float(all_cells.size())) * 100.0
	print("[GrassSpawner] Spawned grass on ", selected.size(), " / ", all_cells.size(),
		" valid ground tiles (", "%.1f" % achieved_pct, "%, soil excluded)")


## Collects every child under obstacle_container_paths (or the "../Objects"
## and "../Stones" fallback) as a circular no-spawn footprint: global center
## position + measured radius + obstacle_padding.
func _gather_obstacles() -> Array[Dictionary]:
	var containers: Array[Node] = []
	if obstacle_container_paths.is_empty():
		for fallback_path in ["../Objects", "../Stones"]:
			var node: Node = get_node_or_null(fallback_path)
			if node != null:
				containers.append(node)
	else:
		for path in obstacle_container_paths:
			var node: Node = get_node_or_null(path)
			if node != null:
				containers.append(node)

	var obstacles: Array[Dictionary] = []
	for container in containers:
		for child in container.get_children():
			if child is Node2D:
				obstacles.append({
					"position": (child as Node2D).global_position,
					"radius": _compute_footprint_radius(child as Node2D) + obstacle_padding,
				})
	return obstacles


## Measures how far an obstacle's footprint actually extends by walking its
## descendants for CollisionShape2D AND CollisionPolygon2D nodes (covers the
## common StaticBody2D/Area2D + collider pattern regardless of how deep it's
## nested), and returns the largest radius found, measured in world space
## from root's global_position. Falls back to default_obstacle_radius if no
## collider turns up anywhere under the node.
func _compute_footprint_radius(root: Node2D) -> float:
	var measured: float = _measure_footprint_radius(root, root)
	if measured < 0.0:
		return default_obstacle_radius
	return measured


## Returns -1.0 if no collider is found anywhere under node, so the caller
## can tell "found nothing" apart from "found a genuinely tiny shape".
## Radii are computed in world space (global position + global scale)
## relative to root rather than naively summing local offsets, so this
## correctly handles shapes nested several levels deep (e.g. Stone's
## Shadow/HealthComponent/HurtboxComponent children) and obstacles whose
## scale changes at runtime (e.g. Stone._randomize_scale()'s random 1x-3x).
func _measure_footprint_radius(node: Node, root: Node2D) -> float:
	var max_radius: float = -1.0

	if node is CollisionShape2D and (node as CollisionShape2D).shape != null:
		max_radius = _shape_world_radius((node as CollisionShape2D).shape, node as Node2D, root)
	elif node is CollisionPolygon2D:
		max_radius = _polygon_world_radius((node as CollisionPolygon2D).polygon, node as Node2D, root)

	for child in node.get_children():
		var child_radius: float = _measure_footprint_radius(child, root)
		if child_radius > max_radius:
			max_radius = child_radius

	return max_radius


## Converts a Shape2D's local extent into a world-space radius measured from
## root's global_position.
func _shape_world_radius(shape: Shape2D, shape_node: Node2D, root: Node2D) -> float:
	var local_radius: float = default_obstacle_radius
	if shape is CircleShape2D:
		local_radius = (shape as CircleShape2D).radius
	elif shape is RectangleShape2D:
		local_radius = (shape as RectangleShape2D).size.length() / 2.0
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		local_radius = max(capsule.radius, capsule.height / 2.0)
	return _to_world_radius(local_radius, shape_node, root)


## Converts a CollisionPolygon2D's local extent (farthest vertex from its own
## origin) into a world-space radius measured from root's global_position.
## This is what actually catches the Cabin's building footprint — it has no
## CollisionShape2D on its main body at all, only this polygon.
func _polygon_world_radius(polygon: PackedVector2Array, poly_node: Node2D, root: Node2D) -> float:
	var local_radius: float = 0.0
	for point in polygon:
		local_radius = max(local_radius, point.length())
	return _to_world_radius(local_radius, poly_node, root)


## Scales a shape-local radius by the shape node's actual global scale (so
## runtime scale changes like Stone's are respected) and adds the world-space
## distance from the shape to root (so offsets at every level of nesting are
## captured correctly, not just the shape's immediate parent).
func _to_world_radius(local_radius: float, shape_node: Node2D, root: Node2D) -> float:
	var global_scale: Vector2 = shape_node.get_global_transform().get_scale()
	var scale_factor: float = max(global_scale.x, global_scale.y)
	var center_offset: float = shape_node.global_position.distance_to(root.global_position)
	return local_radius * scale_factor + center_offset


func _is_inside_obstacle(world_pos: Vector2, obstacles: Array[Dictionary]) -> bool:
	for obstacle in obstacles:
		if world_pos.distance_to(obstacle["position"]) < obstacle["radius"]:
			return true
	return false


## Flood-fills outward from start_cell, so the patch reads as an organic blob
## rather than a straight line or a perfect diamond. Which frontier tile gets
## picked each step is governed by patch_tightness (see _pick_frontier_index).
func _grow_patch(start_cell: Vector2i, patch_size: int, cell_lookup: Dictionary,
		selected: Dictionary, target_count: int) -> void:
	var patch_count: int = 0
	var frontier: Array[Vector2i] = [start_cell]

	while patch_count < patch_size and not frontier.is_empty() and selected.size() < target_count:
		var idx: int = _pick_frontier_index(frontier, selected)
		var current: Vector2i = frontier[idx]
		frontier.remove_at(idx)

		if selected.has(current) or not cell_lookup.has(current):
			continue

		selected[current] = true
		patch_count += 1

		for neighbor in _get_neighbors(current):
			if cell_lookup.has(neighbor) and not selected.has(neighbor):
				frontier.append(neighbor)


## Chooses which frontier tile to grow into next.
## Rolls against patch_tightness: on a "hit", picks whichever frontier tile
## already borders the most selected tiles (ties broken randomly) so the
## patch fills itself in before sprawling further out. On a "miss" (or when
## patch_tightness is 0), just picks a uniformly random frontier tile.
func _pick_frontier_index(frontier: Array[Vector2i], selected: Dictionary) -> int:
	if patch_tightness <= 0.0 or frontier.size() == 1:
		return randi() % frontier.size()

	if randf() < patch_tightness:
		var best_score: int = -1
		var best_indices: Array[int] = []
		for i in frontier.size():
			var score: int = _count_selected_neighbors(frontier[i], selected)
			if score > best_score:
				best_score = score
				best_indices = [i]
			elif score == best_score:
				best_indices.append(i)
		return best_indices[randi() % best_indices.size()]

	return randi() % frontier.size()


func _count_selected_neighbors(cell: Vector2i, selected: Dictionary) -> int:
	var count: int = 0
	for neighbor in _get_neighbors(cell):
		if selected.has(neighbor):
			count += 1
	return count


func _get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = [
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1),
	]
	if use_diagonal_growth:
		neighbors.append(cell + Vector2i(1, 1))
		neighbors.append(cell + Vector2i(-1, -1))
		neighbors.append(cell + Vector2i(1, -1))
		neighbors.append(cell + Vector2i(-1, 1))
	return neighbors


func _place_grass(cell: Vector2i) -> void:
	var grass_instance: Node2D = GRASS_SCENE.instantiate()
	grass_instance.position = ground_layer.map_to_local(cell)
	add_child(grass_instance)
