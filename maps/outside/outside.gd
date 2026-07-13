extends Node2D

const ANTING_ANTING = preload("uid://d17jlxhursebq")
const BOSS = preload("uid://bi7bu6gcsxqgl")

const MIN_DIST_FROM_OBSTACLES = 48.0
const RAYCAST_LENGTH = 100.0  # How far to raycast downward

@onready var ground_layer: TileMapLayer = $Layers/Ground
@onready var soil_layer: TileMapLayer = $Layers/Soil
@onready var objects_node: Node2D = $Objects
@onready var trees_node: Node2D = $Trees
@onready var player_spawn: Marker2D = $Spawns/Default
@onready var bridge_interaction_marker: Node2D = $BridgeInteractionMarker


func _ready() -> void:
	bridge_interaction_marker.bridge_built.connect(_on_bridge_built)
	
	if GameManager.anting_anting_collected:
		print("[Spawn] Anting-anting already collected. Skipping spawn.")
		return
		
	if GameManager.anting_anting_saved_pos != Vector2.ZERO:
		_instantiate_item(GameManager.anting_anting_saved_pos)
		print("[Spawn] Restored anting_anting at saved pos: ", GameManager.anting_anting_saved_pos)
	else:
		_spawn_anting_anting()


func _spawn_anting_anting() -> void:
	var valid_cells = soil_layer.get_used_cells() + ground_layer.get_used_cells()
	if valid_cells.is_empty():
		push_warning("No valid cells found!")
		return

	var obstacle_positions: Array[Vector2] = []
	for child in objects_node.get_children():
		obstacle_positions.append(child.global_position)
	for child in trees_node.get_children():
		obstacle_positions.append(child.global_position)
	obstacle_positions.append(player_spawn.position)

	var filtered_cells: Array = []
	for cell in valid_cells:
		var world_pos = soil_layer.map_to_local(cell)
		if _is_clear(world_pos, obstacle_positions) and _is_on_ground(world_pos):
			filtered_cells.append(world_pos)

	if filtered_cells.is_empty():
		push_warning("No valid spawn positions after filtering!")
		return

	var spawn_pos: Vector2 = filtered_cells[randi() % filtered_cells.size()]

	GameManager.anting_anting_saved_pos = spawn_pos
	
	_instantiate_item(spawn_pos)
	print("[Spawn] First time setup. Spawned and saved at: ", spawn_pos)
	print("[Spawn] Total valid cells: ", filtered_cells.size())


func _instantiate_item(pos: Vector2) -> void:
	var item = ANTING_ANTING.instantiate()
	item.position = pos
	objects_node.add_child(item)


func _is_clear(pos: Vector2, obstacles: Array[Vector2]) -> bool:
	for obs_pos in obstacles:
		if pos.distance_to(obs_pos) < MIN_DIST_FROM_OBSTACLES:
			return false
	return true


func _is_on_ground(pos: Vector2) -> bool:
	# Use a raycast query to check if there's ground below this position
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(pos, pos + Vector2.DOWN * RAYCAST_LENGTH)
	
	# Optional: set collision mask to only check certain layers (adjust if needed)
	# query.collision_mask = 1  # e.g., layer 1 for ground colliders
	
	var result = space_state.intersect_ray(query)
	
	# If the raycast hits something below, it's valid ground
	return result != null


func _on_bridge_built() -> void:
	var boss_scene = BOSS.instantiate()
	boss_scene.global_position = $Spawns/BossSpawn.global_position
	add_child(boss_scene)
