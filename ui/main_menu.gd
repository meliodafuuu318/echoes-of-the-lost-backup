extends Control

@export var hud: CanvasLayer

@onready var help_panel: NinePatchRect = $"../controls_help"
@onready var load_panel: NinePatchRect = $NinePatchRect
## Slot TextureButtons, in slot order. Each has three child Labels —
## "slot_number", "game_time", "real_time" (see main_menu.tscn) — that
## _refresh_slot() rewrites individually.
@onready var slot_buttons: Array[TextureButton] = [
	$NinePatchRect/Panel/VBoxContainer/slot1,
	$NinePatchRect/Panel/VBoxContainer/slot2,
	$NinePatchRect/Panel/VBoxContainer/slot3,
]


func _ready() -> void:
	# Panel starts closed; Load Button toggles it open.
	load_panel.hide()
	for slot_index in slot_buttons.size():
		slot_buttons[slot_index].pressed.connect(_on_slot_pressed.bind(slot_index))
	_refresh_all_slots()


func _on_play_button_pressed() -> void:
	# Get map from save if implemented
	var map = Events.Map.OUTSIDE
	Events.new_game_started.emit()
	#get_tree().current_scene.switch_map(map)
	await Events.scene_load_finished
	hud.show()
	# Hide rather than queue_free(): Main.quit_to_main_menu() re-shows this
	# same node later, so it needs to still exist in the tree.
	hide()


func _on_load_button_pressed() -> void:
	if load_panel.visible:
		load_panel.hide()
		return
	# Re-read from disk each time the panel opens so it reflects saves made
	# (or deleted) elsewhere, e.g. a previous session.
	_refresh_all_slots()
	load_panel.show()


## Loads the given slot directly on press, mirroring settings_ui's load
## button behavior. SaveManager.load_game() hands off to Main.load_from_save(),
## which switches to the saved map — so wait for the same
## Events.scene_load_finished signal _on_play_button_pressed() waits on
## before revealing the HUD and hiding this menu.
func _on_slot_pressed(slot_index: int) -> void:
	if not SaveManager.has_save(slot_index):
		return
	if not SaveManager.load_game(slot_index):
		return
	await Events.scene_load_finished
	hud.show()
	hide()


func _refresh_all_slots() -> void:
	for slot_index in slot_buttons.size():
		_refresh_slot(slot_index)


func _refresh_slot(slot_index: int) -> void:
	var slot_button: TextureButton = slot_buttons[slot_index]
	var slot_number_label: Label = slot_button.get_node("slot_number")
	var game_time_label: Label = slot_button.get_node("game_time")
	var real_time_label: Label = slot_button.get_node("real_time")
	var info: Dictionary = SaveManager.get_save_info(slot_index)

	slot_number_label.text = "Slot %d" % (slot_index + 1)

	if info.is_empty():
		game_time_label.text = "Empty"
		real_time_label.text = ""
		slot_button.disabled = true
		slot_button.modulate.a = 0.5
	else:
		game_time_label.text = _format_game_time(info)
		real_time_label.text = _format_real_time(info)
		slot_button.disabled = false
		slot_button.modulate.a = 1.0


## "Day X, XX:XX" using the in-game day counter + Events' clock string.
## Falls back to just "Day X" if no clock string was available at save time.
func _format_game_time(info: Dictionary) -> String:
	var day: int = info.get("day", 0)
	var time_string: String = info.get("time_string", "")
	if time_string == "":
		return "Day %d" % day
	return "Day %d, %s" % [day, time_string]


## "YYYY/MM/DD H:i:s" (24-hour, zero-padded) built from the unix timestamp
## recorded at save time. Uses UTC to match Time.get_unix_time_from_system().
func _format_real_time(info: Dictionary) -> String:
	if not info.has("real_time_unix"):
		return ""
	var unix_time: int = int(info.get("real_time_unix", 0))
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d/%02d/%02d %02d:%02d:%02d" % [
		dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
	]


func _on_exit_button_pressed() -> void:
	get_tree().quit()


## Public so external callers (e.g. Main.quit_to_main_menu()) can close the
## load panel without reaching into this node's private load_panel var.
func close_load_panel() -> void:
	load_panel.hide()


## Clicks that land on the panel (or its slot buttons) are consumed there by
## normal Control input handling and never bubble up to this function — it
## only fires for clicks elsewhere on screen, since MainMenu is the
## full-screen root Control that unconsumed clicks bubble up to. (Note:
## _unhandled_input would NOT work here, since this root Control's default
## mouse_filter is STOP and swallows any click as GUI input first.)
func _gui_input(event: InputEvent) -> void:
	if not load_panel.visible and not help_panel.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if not load_panel.get_global_rect().has_point(event.global_position):
			load_panel.hide()
			accept_event()
		if not help_panel.get_global_rect().has_point(event.global_position):
			help_panel.hide()
			accept_event()


func _on_help_button_pressed() -> void:
	if help_panel.visible:
		help_panel.hide()
		return
	help_panel.show()
