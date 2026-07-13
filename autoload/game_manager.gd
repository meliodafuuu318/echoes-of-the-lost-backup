extends Node

enum PHASE {NIGHT, DAY}

const BASE_MAX_PLAYER_HEALTH: float = 10

## Effective max health = base + total artifact health buffs.
var MAX_PLAYER_HEALTH: float = BASE_MAX_PLAYER_HEALTH

var data: Dictionary

var player_health: float = 10

var anting_anting_saved_pos: Vector2
var anting_anting_collected: bool = false

## Seed for the procedural grass patch layout on the Outside map (see
## grass_spawner.gd). 0 means "not generated yet" — the spawner rolls a
## fresh nonzero seed on first entry and stores it here so the exact same
## layout is restored after a save/load instead of re-rolling every time.
var grass_patch_seed: int = 0

## Totals derived from every ArtifactItem currently owned. Recomputed by
## whoever owns the artifact inventory (see Player._on_artifact_inv_updated)
## and applied here so the buff persists across scenes.
var artifact_health_buff: float = 0.0
var artifact_attack_buff: float = 0.0

var player_weapon: WeaponItem
var phase: PHASE
var map: Events.Map
var day: int


func _ready() -> void:
	# Keep `map` in sync with whatever Main actually loads, so SaveManager
	# (which reads GameManager.map at save time) always writes the map the
	# player is really standing on, instead of whatever `map` happened to
	# be left at (previously: nothing ever wrote to it after the initial
	# declaration, so every save recorded the wrong/default map).
	Events.map_changed.connect(_on_map_changed)


func _on_map_changed(new_map: Events.Map) -> void:
	map = new_map


func _generated_entry_name(node_path_identifier: String) -> String:
	return str(get_tree().current_scene.get_path(), "/", node_path_identifier)


func has_data_entry(node_path_identifier: String) -> bool:
	return data.has(_generated_entry_name(node_path_identifier))


func has_data_value(node_path_identifier: String, value_name: String) -> bool:
	if not has_data_entry(node_path_identifier):
		return false
	return get_data_entry(node_path_identifier).has(value_name)


func get_data_entry(node_path_identifier: String) -> Dictionary:
	if not has_data_entry(node_path_identifier):
		return {}
	return data[_generated_entry_name(node_path_identifier)]


func get_data_value(node_path_identifier: String, value_name: String):
	if not has_data_value(node_path_identifier, value_name):
		return null
	return get_data_entry(node_path_identifier)[value_name]


func store_data_entry(node_path_identifier: String, value: Dictionary) -> void:
	data[_generated_entry_name(node_path_identifier)] = value


func store_data_value(node_path_identifier: String, value_name: String, value) -> void:
	if has_data_entry(node_path_identifier):
		get_data_entry(node_path_identifier)[value_name] = value
	else:
		store_data_entry(node_path_identifier, { value_name: value })


func remove_data_entry(node_path_identifier: String) -> void:
	if not has_data_entry(node_path_identifier):
		return
	data.erase(_generated_entry_name(node_path_identifier))


func remove_data_value(node_path_identifier: String, value_name: String) -> void:
	if not has_data_value(node_path_identifier, value_name):
		return
	get_data_entry(node_path_identifier).erase(value_name)
	if get_data_entry(node_path_identifier).size() == 0:
		remove_data_entry(node_path_identifier)


func clear_all_data() -> void:
	data.clear()


## Applies the current total artifact buffs. Called whenever the artifact
## inventory changes (pickup, or on load). `new_health_buff`/`new_attack_buff`
## are TOTALS across all owned artifacts, not deltas — safe to call repeatedly
## with the same values (e.g. on every scene load) without stacking.
func apply_artifact_buffs(new_health_buff: float, new_attack_buff: float) -> void:
	var health_delta: float = new_health_buff - artifact_health_buff
	artifact_health_buff = new_health_buff
	artifact_attack_buff = new_attack_buff

	MAX_PLAYER_HEALTH = BASE_MAX_PLAYER_HEALTH + artifact_health_buff

	if health_delta != 0.0:
		# Grant the extra health when a buff is newly gained; if a buff were
		# ever lost, clamp current health down to the new max instead of
		# letting it exceed it.
		player_health = min(player_health + health_delta, MAX_PLAYER_HEALTH)

	Events.artifact_buffs_changed.emit(artifact_health_buff, artifact_attack_buff)


func reset() -> void:
	clear_all_data()

	MAX_PLAYER_HEALTH = BASE_MAX_PLAYER_HEALTH
	player_health = BASE_MAX_PLAYER_HEALTH
	Events.player_health_changed.emit(BASE_MAX_PLAYER_HEALTH)
	
	# Artifacts
	artifact_health_buff = 0.0
	artifact_attack_buff = 0.0
	
	# Equipment
	player_weapon = null
	
	# Collectibles
	anting_anting_saved_pos = Vector2.ZERO
	anting_anting_collected = false
	
	# World layout
	grass_patch_seed = 0
	
	# World state
	phase = PHASE.DAY
	day = 1
	
	Events.artifact_buffs_changed.emit(
		artifact_health_buff,
		artifact_attack_buff
	)
