extends Node

@warning_ignore_start("unused_signal")

signal scene_progress_changed(progress)
signal scene_load_finished(loaded_map: PackedScene)

signal map_changed(map: Map)

signal time_tick(day: int, hour: int, minute: int)
signal sleep_sequence_started(wake_hour: int)
signal sleep_requested(wake_up_hour: int)

signal player_health_changed(current_health: float)
signal player_weapon_equipped(item: WeaponItem)
signal artifact_buffs_changed(health_buff: float, attack_buff: float)
#signal player_state_changed(state: PlayerState)

signal new_game_started
signal game_over(win: bool)

## Emitted when a world artifact (e.g. anting-anting) is picked up. No
## payload needed: main.gd owns the HUD's "found" popup and its icon directly,
## so it sources the texture/size to fly into the hotbar from there rather
## than from the (hidden, often-different) sprite on the world pickup scene.
signal artifact_collected

enum Map {HOUSE, OUTSIDE}

## Cached clock, kept in sync with whatever the day/night cycle emits via
## time_tick. Lets other systems (e.g. SaveManager) ask "what time is it
## right now" without needing their own reference to the clock's owner.
var _current_hour: int = 0
var _current_minute: int = 0


func _ready() -> void:
	time_tick.connect(_on_time_tick)


func _on_time_tick(_day: int, hour: int, minute: int) -> void:
	_current_hour = hour
	_current_minute = minute


## "HH:MM", 24-hour, zero-padded — consumed by SaveManager's meta.time_string
## and shown by the save/load UI as part of "Day X, HH:MM".
func get_time_string() -> String:
	return "%02d:%02d" % [_current_hour, _current_minute]
