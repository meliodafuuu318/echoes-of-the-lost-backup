extends Control

@export var hotbar_ui: Control
@export var main_menu: Control
@export var opening_overlay: ColorRect

var current_tab: String = "inventory"
var is_open: bool = false

var tabs_locked: bool = true

@onready var artifact_inv: Inventory = preload("res://inventory/resources/artifact_inv.tres")
@onready var artifact_slot_nodes: Array = $inventory/artifact_slots.get_children()
@onready var inv_ui = $inventory
@onready var crafting_ui = $crafting
@onready var guide_ui = $guide
@onready var settings_ui = $settings
@onready var recipe_list_ui: RecipeListUI = $crafting/recipe_list_ui
@onready var crafting_display: CraftingUI = $crafting/crafting_ui
#@onready var animation_player: AnimationPlayer = $inventory/player_view/AnimationPlayer
@onready var settings_ui_tabs: Node2D = $settings/tabs

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	tabs_locked = not GameManager.book_found
	if tabs_locked:
		switch_tabs("settings")

	if hotbar_ui == null:
		var nodes = get_tree().get_nodes_in_group("hotbar")
		if nodes.size() > 0:
			hotbar_ui = nodes[0]

	close()
	
	_setup_artifact_slots()
	_setup_tabs()
	recipe_list_ui.recipe_selected.connect(crafting_display.display_recipe)
	crafting_display.item_crafted.connect(_on_item_crafted)

	SaveManager.game_loaded.connect(_on_game_loaded)
	Events.book_found.connect(_on_book_found)
	
	close()


func _on_book_found() -> void:
	unlock_tabs()


## A loaded save carries its own book_found value, which may not match
## whatever this menu was locked/unlocked to before Load was pressed —
## re-derive the lock state from it rather than assuming.
func _on_game_loaded() -> void:
	tabs_locked = not GameManager.book_found
	close()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		if main_menu.visible or opening_overlay.visible or Dialogic.current_timeline != null:
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

	settings_ui_tabs.visible = not tabs_locked

	if tabs_locked:
		# While locked there's only one tab to land on.
		current_tab = "settings"
		inv_ui.visible = false
		crafting_ui.visible = false
		guide_ui.visible = false
		settings_ui.visible = true
	else:
		# Menu always reopens on the inventory tab — treat it as the "home"
		# tab rather than restoring whatever tab was last open.
		current_tab = "inventory"
		inv_ui.visible = true
		crafting_ui.visible = false
		guide_ui.visible = false
		settings_ui.visible = false


# ────────────────────────────────────────────────────────────────────────────
# Tab Management
# ────────────────────────────────────────────────────────────────────────────

## Called once, when the book is found (see _on_book_found). Leaves the menu
## on whichever tab it's currently showing (settings, since that's the only
## reachable one while locked) — just makes the rest of the tab bar usable.
func unlock_tabs() -> void:
	if not tabs_locked:
		return
	tabs_locked = false
	settings_ui_tabs.visible = true
	switch_tabs("inventory")


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
	if tabs_locked and tab_name != "settings":
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
