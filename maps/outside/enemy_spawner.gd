extends Node2D

@export var enemy_scene: PackedScene
@export var tilemap_layer: TileMapLayer
@export var spawn_interval: float = 5.0
@export var max_enemies: int = 5
@export var spawn_margin: float = 150.0

var player: Player
var spawned_enemies: Dictionary = {}
var unique_id_counter: int = 0
var spawn_timer: Timer


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

	_manage_spawner_state()

	Events.map_changed.connect(func(_map): _manage_spawner_state())
	Events.time_tick.connect(func(_d, _h, _m): _manage_spawner_state())


func _manage_spawner_state() -> void:
	if GameManager.phase == GameManager.PHASE.NIGHT:
		if spawned_enemies.is_empty():
			_restore_saved_enemies()
		if spawn_timer.is_stopped() and spawned_enemies.size() < max_enemies:
			spawn_timer.start()
	elif GameManager.phase == GameManager.PHASE.DAY:
		spawn_timer.stop()
		if not spawned_enemies.is_empty():
			despawn_all_enemies()


func _restore_saved_enemies() -> void:
	for i in range(1, max_enemies + 1):
		var check_id = "night_enemy_%d" % i
		if not GameManager.has_data_value(check_id, "pos"):
			continue
		if GameManager.get_data_value(check_id, "day") != GameManager.day:
			GameManager.remove_data_entry(check_id)
			continue
		unique_id_counter = i
		_instantiate_enemy(check_id, Vector2.ZERO, true)


func _on_spawn_timer_timeout() -> void:
	if spawned_enemies.size() >= max_enemies:
		spawn_timer.stop()
		return
	spawn_single_enemy()


func spawn_single_enemy() -> void:
	if not enemy_scene or not player:
		return
	var spawn_pos = get_valid_tilemap_position()
	if spawn_pos == Vector2.ZERO:
		return
	unique_id_counter += 1
	_instantiate_enemy("night_enemy_%d" % unique_id_counter, spawn_pos, false)


func _instantiate_enemy(spawn_id: String, spawn_pos: Vector2, use_saved_pos: bool) -> void:
	var enemy = enemy_scene.instantiate()
	enemy.instance_id = spawn_id
	if not use_saved_pos:
		enemy.global_position = spawn_pos
		GameManager.store_data_value(spawn_id, "day", GameManager.day)
	
	enemy.tree_exited.connect(func():
		spawned_enemies.erase(spawn_id)
		if is_inside_tree() and GameManager.phase == GameManager.PHASE.NIGHT and spawn_timer.is_stopped():
			spawn_timer.start()
	)
	
	spawned_enemies[spawn_id] = enemy
	add_child(enemy)


func despawn_all_enemies() -> void:
	for spawn_id in spawned_enemies.keys():
		var enemy = spawned_enemies[spawn_id]
		GameManager.remove_data_entry(spawn_id)
		enemy.instance_id = ""
		enemy.queue_free()
	spawned_enemies.clear()


func get_valid_tilemap_position() -> Vector2:
	for _attempt in range(10):
		var target_pos = get_outside_viewport_position()
		if not tilemap_layer:
			return target_pos
		var tile_coord = tilemap_layer.local_to_map(tilemap_layer.to_local(target_pos))
		if tilemap_layer.get_cell_tile_data(tile_coord) != null:
			return target_pos
	return Vector2.ZERO


func get_outside_viewport_position() -> Vector2:
	var camera = get_viewport().get_camera_2d()
	var visible_size = get_viewport_rect().size / camera.zoom
	var min_distance = max(visible_size.x, visible_size.y) / 2.0
	var direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	return player.global_position + direction * randf_range(min_distance, min_distance + spawn_margin)
