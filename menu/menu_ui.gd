extends Control

@export var hotbar_ui: Control
@export var main_menu: Control

var current_tab: String = "inventory"
var is_open: bool = false

@onready var artifact_inv: Inventory = preload("res://inventory/resources/artifact_inv.tres")
@onready var artifact_slot_nodes: Array = $inventory/artifact_slots.get_children()
@onready var inv_ui = $inventory
@onready var crafting_ui = $crafting
@onready var guide_ui = $guide
@onready var settings_ui = $settings
@onready var recipe_list_ui: RecipeListUI = $crafting/recipe_list_ui
@onready var crafting_display: CraftingUI = $crafting/crafting_ui
#@onready var animation_player: AnimationPlayer = $inventory/player_view/AnimationPlayer


func _ready() -> void:
	# Let this menu keep processing input/animations even while the
	# SceneTree is paused, since it's the thing responsible for pausing
	# and unpausing it.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if hotbar_ui == null:
		var nodes = get_tree().get_nodes_in_group("hotbar")
		if nodes.size() > 0:
			hotbar_ui = nodes[0]

	# Close FIRST, before any setup below that could throw. GDScript aborts
	# the rest of a function on an unhandled error, so if close() were the
	# last line and something above it (tab wiring, artifact slots, signal
	# connects) threw, the menu would be left open/paused on startup with
	# no way to close it. Calling close() up front means the menu is
	# guaranteed to start hidden and unpaused regardless of what happens
	# in the rest of _ready().
	close()
	
	#Events.player_state_changed.connect(on_player_state_changed)
	
	_setup_artifact_slots()
	_setup_tabs()
	recipe_list_ui.recipe_selected.connect(crafting_display.display_recipe)
	crafting_display.item_crafted.connect(_on_item_crafted)
	
	# main.gd doesn't tear down/recreate menu_ui on a save load (it only
	# swaps the map inside world_container), so this node's _ready() never
	# re-fires after a load and current_tab/visibility would otherwise be
	# stuck on whatever they were when Load was pressed (e.g. left sitting
	# open on the settings tab). Closing here — rather than leaving it to
	# settings_ui to hide itself — properly resets the whole menu: tab,
	# visibility, and pause state together.
	SaveManager.game_loaded.connect(close)
	
	close()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		if main_menu.visible:
			return
		if is_open:
			close()
		else:
			open()


# ────────────────────────────────────────────────────────────────────────────
# Player State Sync
# ────────────────────────────────────────────────────────────────────────────

#func _on_player_state_changed(state: PlayerState) -> void:
	#match state.name:
		#PlayerState.IDLE:
			#animation_player.play("idle")
		#PlayerState.WALKING:
			#animation_player.play("walk")
		#PlayerState.ACTION:
			#animation_player.play("attack")
		#PlayerState.BLOCKING:
			#animation_player.play("block")
		#_:
			#animation_player.play("idle")


# ────────────────────────────────────────────────────────────────────────────
# Crafting feedback
# ────────────────────────────────────────────────────────────────────────────

func _on_item_crafted(product: InvItem, from_pos: Vector2) -> void:
	# Only show the fly-to-inventory ghost when the crafting tab is the one
	# currently open; if items ever get crafted through some other flow while
	# this tab isn't visible, stay quiet.
	if current_tab != "crafting" or not product or not product.texture:
		return

	var inventory_tab: Control = crafting_ui.get_node("tabs/inventory")
	var target_pos: Vector2 = inventory_tab.get_global_transform_with_canvas().origin + inventory_tab.size * inventory_tab.get_global_transform_with_canvas().get_scale() / 2.0
	DragGhost.fly_to(product.texture, from_pos, target_pos)


# ────────────────────────────────────────────────────────────────────────────
# Menu Open/Close
# ────────────────────────────────────────────────────────────────────────────

func open() -> void:
	visible = true
	is_open = true
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Player = players[0]
		var current_state: PlayerState = player.state_machine.state
		if current_state.name != PlayerState.IDLE and current_state.name != PlayerState.WALKING:
			player.state_machine._transition_to_next_state(PlayerState.IDLE)
	
	get_tree().paused = true
	if hotbar_ui:
		hotbar_ui.visible = false

func close() -> void:
	visible = false
	is_open = false
	get_tree().paused = false
	if hotbar_ui:
		hotbar_ui.visible = true
	if current_tab == "guide":
		guide_ui.get_node("guide_ui").reset()
	recipe_list_ui.deselect_all()
	crafting_display.reset_display()

	# Menu always reopens on the inventory tab — treat it as the "home" tab
	# rather than restoring whatever tab was last open.
	current_tab = "inventory"
	inv_ui.visible = true
	crafting_ui.visible = false
	guide_ui.visible = false
	settings_ui.visible = false


# ────────────────────────────────────────────────────────────────────────────
# Tab Management
# ────────────────────────────────────────────────────────────────────────────

func _setup_tabs() -> void:
	# Each ui panel (inventory/crafting/guide/settings) has its own "tabs" node
	# with its own positioning, so the tab bar can be placed differently per ui.
	# Each bar only lists the *other* panels — no need for a button back to the
	# tab you're already on. Panels without a ui yet (like settings) may not
	# have a "tabs" node at all, so skip those instead of erroring.
	for ui_panel in [inv_ui, crafting_ui, guide_ui, settings_ui]:
		if not ui_panel.has_node("tabs"):
			continue
		var tabs_node: Node = ui_panel.get_node("tabs")
		for tab_button in tabs_node.get_children():
			tab_button.gui_input.connect(_on_tab_clicked.bindv([tab_button, String(tab_button.name)]))

func _on_tab_clicked(event: InputEvent, _tab: Panel, tab_name: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		switch_tabs(tab_name)

func switch_tabs(tab_name: String) -> void:
	if current_tab == tab_name:
		return
	
	print("Switching to tab: %s" % tab_name)
	if current_tab == "crafting":
		recipe_list_ui.deselect_all()
		crafting_display.reset_display()
	if current_tab == "guide":
		guide_ui.get_node("guide_ui").reset()
	current_tab = tab_name
	if current_tab == "inventory":
		inv_ui.visible = true
		crafting_ui.visible = false
		guide_ui.visible = false
		settings_ui.visible = false
	elif current_tab == "crafting":
		inv_ui.visible = false
		crafting_ui.visible = true
		guide_ui.visible = false
		settings_ui.visible = false
	elif current_tab == "guide":
		inv_ui.visible = false
		crafting_ui.visible = false
		guide_ui.visible = true
		settings_ui.visible = false
	elif current_tab == "settings":
		inv_ui.visible = false
		crafting_ui.visible = false
		guide_ui.visible = false
		settings_ui.visible = true


# ────────────────────────────────────────────────────────────────────────────
# Artifact slot setup
# ────────────────────────────────────────────────────────────────────────────

func _setup_artifact_slots() -> void:
	for i in range(mini(artifact_inv.slots.size(), artifact_slot_nodes.size())):
		var slot_node = artifact_slot_nodes[i]
		if slot_node is ArtifactSlotUI:
			slot_node.setup(i, artifact_inv)

	artifact_inv.update.connect(_update_artifact_slots)
	_update_artifact_slots()

func _update_artifact_slots() -> void:
	for i in range(mini(artifact_inv.slots.size(), artifact_slot_nodes.size())):
		var slot_node = artifact_slot_nodes[i]
		if slot_node is ArtifactSlotUI:
			slot_node.update(artifact_inv.get_slot_by_index(i))
