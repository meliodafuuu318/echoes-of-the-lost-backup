extends Control

const HOTBAR_SLOT_COUNT = 6

@onready var player_inv: Inventory = preload("res://inventory/resources/player_inv.tres")
@onready var slot_nodes: Array = $MarginContainer/VBoxContainer/hotbar_items/MarginContainer/GridContainer.get_children()

var selected_index: int = 0

func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _ready() -> void:
	for i in range(mini(HOTBAR_SLOT_COUNT, slot_nodes.size())):
		slot_nodes[i].setup(i, player_inv)
	player_inv.update.connect(_update_slots)
	_update_slots()
	_highlight_slot(selected_index)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hotbar_next"):
		selected_index = (selected_index + 1) % HOTBAR_SLOT_COUNT
		_highlight_slot(selected_index)

	if event.is_action_pressed("hotbar_prev"):
		selected_index = (selected_index - 1 + HOTBAR_SLOT_COUNT) % HOTBAR_SLOT_COUNT
		_highlight_slot(selected_index)

	for i in range(HOTBAR_SLOT_COUNT):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			selected_index = i
			_highlight_slot(selected_index)

	if event.is_action_pressed("use_item"):
		# Resolve which index to use — prefer the visually selected slot
		var use_index = selected_index
		var selected_slot = InventorySlotUI.currently_selected
		if selected_slot != null and selected_slot.inventory == player_inv:
			use_index = selected_slot.slot_index

		var player = _get_player()
		if player == null:
			push_warning("HotbarUI: no node in group 'player' found")
			return
		player_inv.use_item(use_index, player)

func _highlight_slot(index: int) -> void:
	for i in range(slot_nodes.size()):
		slot_nodes[i].set_selected(i == index)

func _update_slots() -> void:
	for i in range(mini(HOTBAR_SLOT_COUNT, slot_nodes.size())):
		slot_nodes[i].update(player_inv.get_slot_by_index(i))
