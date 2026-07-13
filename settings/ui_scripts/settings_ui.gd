extends Control

## Node paths for the three slot panels, matching settings_ui.tscn.
const PANEL_PATHS: Array[String] = [
	"NinePatchRect2/VBoxContainer/Panel",
	"NinePatchRect2/VBoxContainer/Panel2",
	"NinePatchRect2/VBoxContainer/Panel3",
]

@onready var quit_button: TextureButton = $NinePatchRect2/quit_button

var _slot_nodes: Array[Dictionary] = []

## Delete is destructive, so it's armed with one press ("Delete?") and
## committed with a second press on the same slot within CONFIRM_TIMEOUT
## seconds. Any other button press, or switching slots, disarms it.
const CONFIRM_TIMEOUT := 3.0
var _pending_delete_slot: int = -1
var _confirm_timer: SceneTreeTimer


func _ready() -> void:
	for panel_path: String in PANEL_PATHS:
		_slot_nodes.append(_collect_slot_nodes(panel_path))

	for slot_index in _slot_nodes.size():
		var nodes: Dictionary = _slot_nodes[slot_index]
		nodes.save_button.pressed.connect(_on_save_pressed.bind(slot_index))
		nodes.load_button.pressed.connect(_on_load_pressed.bind(slot_index))
		nodes.delete_button.pressed.connect(_on_delete_pressed.bind(slot_index))

	quit_button.pressed.connect(_on_quit_pressed)

	refresh_all_slots()


func _collect_slot_nodes(panel_path: String) -> Dictionary:
	var panel: Panel = get_node(panel_path)
	return {
		"slot_label": panel.get_node("save_slot") as Label,
		# Two separate labels per slot in the scene: in-game day/clock time,
		# and the real-world wall-clock moment the save was written.
		"game_time_label": panel.get_node("save_time_game") as Label,
		"real_time_label": panel.get_node("save_time_real") as Label,
		"save_button": panel.get_node("save_button") as TextureButton,
		"load_button": panel.get_node("load_button") as TextureButton,
		"delete_button": panel.get_node("delete_button") as TextureButton,
	}


func refresh_all_slots() -> void:
	for slot_index in _slot_nodes.size():
		_refresh_slot(slot_index)


func _refresh_slot(slot_index: int) -> void:
	var nodes: Dictionary = _slot_nodes[slot_index]
	var info: Dictionary = SaveManager.get_save_info(slot_index)

	nodes.slot_label.text = "SLOT %d" % (slot_index + 1)

	if info.is_empty():
		nodes.game_time_label.text = "Empty"
		nodes.real_time_label.text = ""
		nodes.load_button.disabled = true
		nodes.load_button.modulate.a = 0.5
		nodes.delete_button.disabled = true
		nodes.delete_button.modulate.a = 0.5
	else:
		nodes.game_time_label.text = _format_game_time(info)
		nodes.real_time_label.text = _format_real_time(info)
		nodes.load_button.disabled = false
		nodes.load_button.modulate.a = 1.0
		nodes.delete_button.disabled = false
		nodes.delete_button.modulate.a = 1.0

	# _refresh_slot re-reads from disk, so any armed confirmation on this
	# slot is stale the moment its contents change (e.g. after deleting).
	if slot_index == _pending_delete_slot:
		_disarm_delete()


## "Day X, XX:XX" using the in-game day counter + Events' clock string.
## Falls back to just "Day X" if no clock string was available at save time.
func _format_game_time(info: Dictionary) -> String:
	var day: int = info.get("day", 0)
	var time_string: String = info.get("time_string", "")
	if time_string == "":
		return "Day %d" % day
	return "Day %d, %s" % [day, time_string]


## "YYYY,MM,DD H:i:s" (24-hour, zero-padded) built from the unix timestamp
## recorded at save time. Uses UTC to match Time.get_unix_time_from_system().
func _format_real_time(info: Dictionary) -> String:
	if not info.has("real_time_unix"):
		return ""
	var unix_time: int = int(info.get("real_time_unix", 0))
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d/%02d/%02d %02d:%02d:%02d" % [
		dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
	]


func _on_save_pressed(slot_index: int) -> void:
	_disarm_delete()
	SaveManager.save_game(slot_index)
	_refresh_slot(slot_index)


func _on_load_pressed(slot_index: int) -> void:
	_disarm_delete()
	if not SaveManager.has_save(slot_index):
		return
	SaveManager.load_game(slot_index)
	# Closing the pause menu on a successful load is handled by menu_ui,
	# which listens for SaveManager.game_loaded — hiding this node directly
	# would only hide the settings panel's own content, not the menu itself,
	# and would leave it permanently hidden the next time this tab is opened.


func _on_delete_pressed(slot_index: int) -> void:
	if not SaveManager.has_save(slot_index):
		return

	if _pending_delete_slot != slot_index:
		_arm_delete(slot_index)
		return

	_disarm_delete()
	SaveManager.delete_save(slot_index)
	_refresh_slot(slot_index)


## Main owns gameplay teardown (world, player, day/night, HUD) and the
## MainMenu overlay, the same way it owns switch_map() — see main_menu.gd's
## _on_play_button_pressed() for the mirror-image call on the way back in.
func _on_quit_pressed() -> void:
	_disarm_delete()
	var main: Node = get_tree().current_scene
	if main and main.has_method("quit_to_main_menu"):
		main.quit_to_main_menu()
	else:
		push_error("settings_ui: current scene has no quit_to_main_menu() — can't return to the main menu.")


## First press on a slot's delete button: arm it and dim the icon as a
## "press again to confirm" cue. Any other slot's arming (or a timeout)
## clears this automatically.
func _arm_delete(slot_index: int) -> void:
	_disarm_delete()
	_pending_delete_slot = slot_index
	_slot_nodes[slot_index].delete_button.modulate = Color(1.0, 0.4, 0.4)

	_confirm_timer = get_tree().create_timer(CONFIRM_TIMEOUT)
	_confirm_timer.timeout.connect(_disarm_delete)


func _disarm_delete() -> void:
	if _confirm_timer:
		if _confirm_timer.timeout.is_connected(_disarm_delete):
			_confirm_timer.timeout.disconnect(_disarm_delete)
		_confirm_timer = null

	if _pending_delete_slot != -1:
		_slot_nodes[_pending_delete_slot].delete_button.modulate = Color(1, 1, 1, 1)
		_pending_delete_slot = -1
