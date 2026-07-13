extends Node
## Autoload. Handles multi-slot save/load to user:// as JSON.
##
## Design: GameManager already centralizes persistent state (player_health,
## day, phase, map, artifact buffs, and the generic `data` dictionary keyed
## by scene node paths). SaveManager's job is just to snapshot that state
## (plus any other autoload that opts in) to disk and restore it.
##
## DailyTaskManager and MainQuestManager do NOT need get_save_data()/
## load_save_data() — they already persist through GameManager.data via
## store_data_entry("DailyTasks"/"MainQuests", ...), so _serialize_game_manager
## picks them up automatically. They only need to know when a load happens
## so they can re-read that data into their live in-memory dictionaries —
## see the `game_loaded` signal below.
##
## For any OTHER autoload with state that doesn't go through GameManager.data,
## give it two methods:
##   func get_save_data() -> Dictionary
##   func load_save_data(data: Dictionary) -> void
## then add its node name to SAVEABLE_SINGLETONS below.

## Emitted after a load_game() finishes deserializing state, before the
## scene change. Autoloads that cache their own copy of data also stored in
## GameManager.data (DailyTaskManager, MainQuestManager, ...) should connect
## to this and re-pull their state from GameManager.data here.
signal game_loaded

const SAVE_DIR := "user://saves/"
const SAVE_SLOTS := 3
const AUTOSAVE_SLOT := -1  # separate file, doesn't count against SAVE_SLOTS

## Autoload names (as registered in Project Settings > Autoload) that expose
## get_save_data()/load_save_data(). GameManager and the three Inventory
## resources (player/weapon/artifact) are handled specially below since
## they aren't plain "get/load_save_data" singletons.
const SAVEABLE_SINGLETONS: Array[String] = []

## Adjust these paths/accessors to wherever player_inv / weapon_inv /
## artifact_inv actually live in your project (an autoload holding
## preloaded .tres refs, exported vars on Player, etc).
const PLAYER_INV_PATH := "res://inventory/resources/player_inv.tres"
const WEAPON_INV_PATH := "res://inventory/resources/weapon_inv.tres"
const ARTIFACT_INV_PATH := "res://inventory/resources/artifact_inv.tres"

var autosave_enabled: bool = true


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _slot_path(slot: int) -> String:
	if slot == AUTOSAVE_SLOT:
		return SAVE_DIR + "autosave.save"
	return SAVE_DIR + "slot_%d.save" % slot


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


## Lightweight metadata for slot UI without loading the whole save.
## Returns {} if the slot is empty.
func get_save_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed: Variant = _read_json(_slot_path(slot))
	if parsed == null:
		return {}
	return parsed.get("meta", {})


func save_game(slot: int) -> void:
	var player_pos: Vector2 = _get_player_position()
	var drop_manager: Node = _get_item_drop_manager()
	var day_night_cycle: Node = _get_day_night_cycle()

	var save_data: Dictionary = {
		"meta": {
			"day": GameManager.day,
			"phase": GameManager.phase,
			# Replace with however your Events/time system exposes clock time.
			"time_string": Events.get_time_string() if Events.has_method("get_time_string") else "",
			"player_position": [player_pos.x, player_pos.y],
			# Wall-clock save timestamp (UTC unix seconds). Stored as a raw
			# int rather than a pre-formatted string so the UI is free to
			# render it however it likes (and so it stays JSON/locale safe).
			"real_time_unix": Time.get_unix_time_from_system(),
		},
		"game_manager": _serialize_game_manager(),
		"player_inv": (load(PLAYER_INV_PATH) as Inventory).to_save_dict(),
		"weapon_inv": (load(WEAPON_INV_PATH) as Inventory).to_save_dict(),
		"artifact_inv": (load(ARTIFACT_INV_PATH) as Inventory).to_save_dict(),
		# Dropped items currently sitting in the world. Kept separate from
		# GameManager.data since ItemDropManager isn't an autoload — see
		# _get_item_drop_manager().
		"item_drops": drop_manager.get_save_data() if drop_manager else {},
		# The in-game clock (DayNightCycle.time). Kept separate from
		# GameManager.data since DayNightCycle isn't an autoload — see
		# _get_day_night_cycle(), which reads it directly off Main. Without
		# this, loading a save always resumed the clock from wherever it
		# happened to already be ticking, instead of the saved time.
		"day_night_cycle": day_night_cycle.get_save_data() if day_night_cycle else {},
	}

	for singleton_name: String in SAVEABLE_SINGLETONS:
		if not has_node("/root/%s" % singleton_name):
			continue
		var singleton: Node = get_node("/root/%s" % singleton_name)
		if singleton.has_method("get_save_data"):
			save_data[singleton_name] = singleton.get_save_data()

	var f: FileAccess = FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	f.store_string(JSON.stringify(save_data, "\t"))
	f.close()


func load_game(slot: int) -> bool:
	if not has_save(slot):
		return false

	var save_data: Variant = _read_json(_slot_path(slot))
	if save_data == null:
		push_error("SaveManager: corrupt save file in slot %d" % slot)
		return false

	_deserialize_game_manager(save_data.get("game_manager", {}))

	if save_data.has("player_inv"):
		(load(PLAYER_INV_PATH) as Inventory).load_from_save_dict(save_data["player_inv"])
	if save_data.has("weapon_inv"):
		(load(WEAPON_INV_PATH) as Inventory).load_from_save_dict(save_data["weapon_inv"])
	if save_data.has("artifact_inv"):
		(load(ARTIFACT_INV_PATH) as Inventory).load_from_save_dict(save_data["artifact_inv"])

	# Dropped items in the world should survive a save/load just like
	# inventory contents do, so restore them the same way.
	var drop_manager: Node = _get_item_drop_manager()
	if drop_manager and save_data.has("item_drops"):
		drop_manager.load_save_data(save_data["item_drops"])

	# Sync the in-game clock to the saved time. This must happen before
	# game_loaded.emit() below, since load_save_data() re-emits
	# Events.time_tick (which updates Events._current_hour/_minute and
	# GameManager.phase/day) — anything that reacts to game_loaded should
	# see an already-consistent clock/phase/day.
	var day_night_cycle: Node = _get_day_night_cycle()
	if day_night_cycle and save_data.has("day_night_cycle"):
		day_night_cycle.load_save_data(save_data["day_night_cycle"])

	for singleton_name: String in SAVEABLE_SINGLETONS:
		if not save_data.has(singleton_name):
			continue
		if not has_node("/root/%s" % singleton_name):
			continue
		var singleton: Node = get_node("/root/%s" % singleton_name)
		if singleton.has_method("load_save_data"):
			singleton.load_save_data(save_data[singleton_name])

	# Let DailyTaskManager/MainQuestManager/etc. re-pull their in-memory
	# state from the GameManager.data we just restored above.
	game_loaded.emit()

	# Hand off to Main to actually resume gameplay. Main owns TARGET_SCENE
	# (map -> scene), the world container, and menu/HUD visibility, so it's
	# the one place that can take the player straight into the saved map at
	# their saved position instead of bouncing back to the main menu (which
	# is what a bare get_tree().reload_current_scene() used to do — it tore
	# down the whole Main scene, including the menu-hidden/HUD-shown state).
	var main: Node = get_tree().current_scene
	var meta: Dictionary = save_data.get("meta", {})
	var pos_arr: Array = meta.get("player_position", [0.0, 0.0])
	var player_pos := Vector2(pos_arr[0], pos_arr[1])

	if main and main.has_method("load_from_save"):
		main.load_from_save(GameManager.map, player_pos)
	else:
		push_error("SaveManager: current scene has no load_from_save() — falling back to a full scene reload, which will return to the main menu.")
		get_tree().reload_current_scene()

	return true


## ItemDropManager lives as a regular node under Main (not an autoload), so
## it's found by group instead of by absolute path.
func _get_item_drop_manager() -> Node:
	return get_tree().get_first_node_in_group("item_drop_manager")


## DayNightCycle is a sibling of WorldContainer under Main (not inside it),
## so it survives map swaps and Main already holds a direct reference to it
## (main.gd: @onready var day_night_cycle). Read it straight off Main rather
## than via a group tag — a group needs to be manually added to the node in
## the editor and is easy to forget (which is exactly what silently broke
## save/load of the clock: the node was never tagged, so this always
## returned null and the clock was never captured or restored).
func _get_day_night_cycle() -> Node:
	var main: Node = get_tree().current_scene
	if main and ("day_night_cycle" in main):
		return main.day_night_cycle
	return null


## Main owns the live Player node; grabbing its position directly at save
## time avoids needing Player to continuously mirror its position into
## GameManager on every frame just so SaveManager can read it later.
func _get_player_position() -> Vector2:
	var main: Node = get_tree().current_scene
	if main and ("player" in main) and main.player:
		return main.player.global_position
	return Vector2.ZERO


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_slot_path(slot))


func autosave() -> void:
	if autosave_enabled:
		save_game(AUTOSAVE_SLOT)


func _read_json(path: String) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text: String = f.get_as_text()
	f.close()
	return JSON.parse_string(text)


# ---------------------------------------------------------------------------
# GameManager (de)serialization
# ---------------------------------------------------------------------------

func _serialize_game_manager() -> Dictionary:
	return {
		"player_health": GameManager.player_health,
		"artifact_health_buff": GameManager.artifact_health_buff,
		"artifact_attack_buff": GameManager.artifact_attack_buff,
		"player_weapon_id": GameManager.player_weapon.id if GameManager.player_weapon else "",
		"phase": GameManager.phase,
		"map": GameManager.map,
		"day": GameManager.day,
		"anting_anting_saved_pos": [
			GameManager.anting_anting_saved_pos.x,
			GameManager.anting_anting_saved_pos.y,
		],
		"anting_anting_collected": GameManager.anting_anting_collected,
		"grass_patch_seed": GameManager.grass_patch_seed,
		# The generic per-node data dict. Only JSON-safe values (bool, int,
		# float, String, Array, Dictionary) are safe in here — if any node
		# is storing a Vector2/Resource/etc. via store_data_value, convert
		# it to a plain array/dict before storing, same as done above for
		# anting_anting_saved_pos.
		"data": GameManager.data,
	}


func _deserialize_game_manager(d: Dictionary) -> void:
	# Restore the buff totals and MAX_PLAYER_HEALTH directly rather than
	# going through apply_artifact_buffs(). That function is meant for the
	# *live* case — "an artifact was just picked up, add the difference to
	# current health" — and computes its delta against whatever
	# artifact_health_buff happens to already be sitting in memory. On load
	# that in-memory value has nothing to do with the save being restored
	# (e.g. it's whatever was live before Load was pressed), so the delta
	# it computes is essentially arbitrary and was silently corrupting the
	# player_health we'd just set from the save one line above. The saved
	# player_health already reflects the correct value including buffs, so
	# nothing here needs to "adjust" it — just restore the numbers as-is.
	GameManager.artifact_health_buff = d.get("artifact_health_buff", 0.0)
	GameManager.artifact_attack_buff = d.get("artifact_attack_buff", 0.0)
	GameManager.MAX_PLAYER_HEALTH = GameManager.BASE_MAX_PLAYER_HEALTH + GameManager.artifact_health_buff
	GameManager.player_health = d.get("player_health", GameManager.MAX_PLAYER_HEALTH)
	Events.artifact_buffs_changed.emit(GameManager.artifact_health_buff, GameManager.artifact_attack_buff)

	var weapon_id: String = d.get("player_weapon_id", "")
	if weapon_id != "":
		GameManager.player_weapon = ItemManager.get_item_by_id(weapon_id) as WeaponItem
	else:
		GameManager.player_weapon = null

	GameManager.phase = d.get("phase", GameManager.PHASE.DAY)
	GameManager.map = d.get("map", GameManager.map)
	GameManager.day = d.get("day", 1)

	var pos_arr: Array = d.get("anting_anting_saved_pos", [0.0, 0.0])
	GameManager.anting_anting_saved_pos = Vector2(pos_arr[0], pos_arr[1])
	GameManager.anting_anting_collected = d.get("anting_anting_collected", false)

	GameManager.grass_patch_seed = d.get("grass_patch_seed", 0)

	GameManager.data = d.get("data", {})


func clear_all_saves() -> void:
	for slot in range(SAVE_SLOTS):
		delete_save(slot)
	
	delete_save(AUTOSAVE_SLOT)
	
	DirAccess.remove_absolute(SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
