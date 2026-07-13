extends Node

const TARGET_SCENE: Dictionary[Events.Map, String] = {
	Events.Map.HOUSE: "uid://3s5rfvjydnns", 
	Events.Map.OUTSIDE: "uid://c5g3ll83gblw0", 
}
const GAME_OVER = preload("uid://bfd2ikvbrexa8")
const LOADING_SCREEN: PackedScene = preload("uid://da3fy45kwnqqm")

var next_spawn: String = "Default"

## Set by load_from_save() right before a scene load kicked off for a save
## load (as opposed to a normal map transition). When this is anything other
## than Vector2.INF, _position_player() will snap the player to this exact
## world position instead of looking up a named spawn Marker2D — this is what
## lets a loaded save resume exactly where the player saved, rather than at
## whatever the nearest spawn point happens to be.
var pending_load_position: Vector2 = Vector2.INF

@onready var player: Player = $Player
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var day_night_cycle_ui: Control = $CanvasLayer/DayNightCycleUI
@onready var day_night_cycle: CanvasModulate = $DayNightCycle
@onready var world_container = $WorldContainer
@onready var main_menu: CanvasItem = $CanvasLayer/MainMenu
@onready var hud: CanvasLayer = $HUD
@onready var menu_ui: Control = $HUD/menu_ui
@onready var hotbar_ui: Control = $HUD/hotbar_ui
@onready var anting_anting_found: Node2D = $HUD/anting_anting_found
@onready var anting_anting_found_icon: TextureRect = $HUD/anting_anting_found/TextureRect

## How long the "artifact found" popup stays on screen before the
## drag-ghost-into-hotbar animation begins.
const ARTIFACT_FOUND_DISPLAY_TIME := 2.5


func _ready() -> void:
	player.hide()
	player.set_physics_process(false)
	day_night_cycle_ui.hide()
	day_night_cycle.hide()
	day_night_cycle.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Belt-and-suspenders: menu_ui already closes itself in its own _ready(),
	# but that relies on child-before-parent _ready() ordering. Forcing it
	# closed here too guarantees the pause menu can never start a session
	# open/paused, regardless of node instantiation order.
	if menu_ui and menu_ui.has_method("close"):
		menu_ui.close()
	get_tree().paused = false
	
	Events.scene_load_finished.connect(_on_scene_load_finished)
	Events.new_game_started.connect(_on_new_game_started)
	Events.game_over.connect(_on_game_over)
	Events.artifact_collected.connect(_on_artifact_collected)
	
	Events.sleep_sequence_started.connect(_on_sleep_sequence_started)


## Normal in-game map transition (day/night change, going indoors/outdoors,
## etc). Player is placed at the named spawn Marker2D on the new map.
func switch_map(new_map: Events.Map, spawn_name: String = "Default") -> void:
	next_spawn = spawn_name
	pending_load_position = Vector2.INF
	get_tree().paused = true
	SceneLoader.load_scene(TARGET_SCENE[new_map])
	Events.map_changed.emit(new_map)


## Entry point used by SaveManager after a save has been loaded. Loads the
## saved map and drops the player at their exact saved position, then takes
## the game straight into gameplay (see _on_scene_load_finished) instead of
## leaving the player back at the main menu.
func load_from_save(new_map: Events.Map, spawn_position: Vector2) -> void:
	if not TARGET_SCENE.has(new_map):
		push_error("Main: no scene registered in TARGET_SCENE for map %s — cannot resume save." % new_map)
		return
	pending_load_position = spawn_position
	get_tree().paused = true
	SceneLoader.load_scene(TARGET_SCENE[new_map])
	Events.map_changed.emit(new_map)


func _position_player(current_map: Node2D) -> void:
	if pending_load_position != Vector2.INF:
		player.global_position = pending_load_position
		pending_load_position = Vector2.INF
		return
	
	var spawn_container: Node2D = current_map.get_node_or_null("Spawns")
	
	if not spawn_container:
		return
	
	var target_spawn: Marker2D = spawn_container.get_node_or_null(next_spawn)
	
	if not target_spawn:
		return
	
	player.global_position = target_spawn.global_position


func _on_scene_load_finished(loaded_map: PackedScene) -> void:
	for child in world_container.get_children():
		child.queue_free()
		
	var new_map_instance = loaded_map.instantiate()
	world_container.add_child(new_map_instance)
	
	_position_player(new_map_instance)
	
	player.show()
	player.set_physics_process(true)
	day_night_cycle_ui.show()
	day_night_cycle.show()
	day_night_cycle.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Whenever a map finishes loading we are, by definition, in gameplay —
	# whether we got here via New Game, a normal map transition, or a save
	# load. Centralizing this here (rather than leaving it to whatever
	# triggered the load) means loading a save can no longer strand the
	# player back on the main menu.
	_enter_gameplay()
	
	get_tree().paused = false
	
	# Auto-save right after a map finishes loading — this is the one place
	# where both the current map and the player's position on it are fully
	# settled, whether we got here from a normal map transition or a save
	# load, so it's the natural point to persist "where the player is."
	SaveManager.autosave()


func _on_new_game_started() -> void:
	pending_load_position = Vector2.INF
	next_spawn = "Default"
	
	GameManager.reset()
	MainQuestManager.reset_quests()
	DailyTaskManager.reset_daily_tasks_for_new_game()
	day_night_cycle.reset()
	
	switch_map(Events.Map.OUTSIDE)
	
	await Events.scene_load_finished
	hud.show()
	menu_ui.set_process(true)
	player.reset_inventory_for_new_game()
	player.respawn()


func _on_game_over(win: bool) -> void:
	SaveManager.clear_all_saves()
	var real_settigs_ui = menu_ui.settings_ui.get_node("settings_ui")
	real_settigs_ui.refresh_all_slots()
	var game_over_scene = GAME_OVER.instantiate()
	game_over_scene.win = win
	print(win)
	canvas_layer.add_child(game_over_scene)
	menu_ui.set_process(false)
	hud.hide()


## Runs the full "artifact picked up" feedback sequence:
##   1. Show the anting_anting_found popup for a few seconds.
##   2. Hide it again.
##   3. Spawn a drag-ghost copy of the popup's own icon — same texture, same
##      on-screen size and position it was just displayed at — and shrink it
##      continuously as it flies into the hotbar, disappearing on arrival.
##      Using the popup's icon (rather than the world pickup scene's sprite,
##      which stays hidden and is often a different placeholder image) is
##      what sells the illusion that the item on screen is what flies into
##      the inventory.
func _on_artifact_collected() -> void:
	anting_anting_found.show()
	await get_tree().create_timer(ARTIFACT_FOUND_DISPLAY_TIME).timeout
	anting_anting_found.hide()

	if not is_instance_valid(anting_anting_found_icon):
		push_error("main.gd: anting_anting_found_icon is null/invalid — check that $HUD/anting_anting_found/TextureRect still exists at that exact path.")
		return
	if not is_instance_valid(hotbar_ui):
		push_error("main.gd: hotbar_ui is null/invalid — check that $HUD/hotbar_ui still exists at that exact path.")
		return
	if anting_anting_found_icon.texture == null:
		push_error("main.gd: anting_anting_found_icon.texture is null — the TextureRect has no texture assigned.")
		return

	# Don't read .size / .global_position separately — the icon can carry its
	# own scale (it does: 15x, pivoting from its top-left corner), which those
	# properties ignore entirely. Transforming the local rect's corners through
	# the full global transform (with canvas) gives the actual on-screen box,
	# scale/pivot/canvas-transform and all.
	var xform: Transform2D = anting_anting_found_icon.get_global_transform_with_canvas()
	var top_left: Vector2 = xform * Vector2.ZERO
	var bottom_right: Vector2 = xform * anting_anting_found_icon.size
	var start_size: Vector2 = bottom_right - top_left
	var start_center: Vector2 = (top_left + bottom_right) / 2
	var hotbar_screen_pos: Vector2 = hotbar_ui.get_global_transform_with_canvas().origin + Vector2(200.0, 100.0)
	DragGhost.fly_and_shrink(anting_anting_found_icon.texture, start_center, hotbar_screen_pos, start_size)


func _enter_gameplay() -> void:
	if main_menu:
		main_menu.hide()
	if hud:
		hud.show()


## Called from settings_ui's "Quit to Main Menu" button (inside the pause
## menu). Mirror image of _enter_gameplay()/_on_scene_load_finished(): tears
## down the current session and hands control back to the MainMenu overlay,
## which main_menu.gd now hide()s rather than queue_free()s on Play so it's
## still here to show again.
func quit_to_main_menu() -> void:
	for child in world_container.get_children():
		child.queue_free()
	
	GameManager.reset()
	player.hide()
	player.set_physics_process(false)

	day_night_cycle_ui.hide()
	day_night_cycle.hide()
	day_night_cycle.process_mode = Node.PROCESS_MODE_DISABLED

	if menu_ui and menu_ui.has_method("close"):
		menu_ui.close()
	if hud:
		hud.hide()
	if main_menu:
		main_menu.show()
		if main_menu.has_method("close_load_panel"):
			main_menu.close_load_panel()

	pending_load_position = Vector2.INF
	get_tree().paused = false


func _on_sleep_sequence_started(wake_hour: int) -> void:
	get_tree().paused = true 

	var transition = LOADING_SCREEN.instantiate()
	canvas_layer.add_child(transition)

	await transition.loading_screen_ready

	Events.sleep_requested.emit(wake_hour)

	await get_tree().create_timer(1.0).timeout

	transition.fade_out()

	get_tree().paused = false
