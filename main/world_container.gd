extends Node2D

@onready var item_drop_manager: ItemDropManager = $"../item_drop_manager"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_connect_inventory_signals(player.INV)
	else:
		push_error("[Outside] Player not found — inventory drop signal not connected")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _connect_inventory_signals(player_inventory: Inventory) -> void:
	player_inventory.item_dropped.connect(_on_item_dropped)
	var weapon_inv: Inventory = load("res://inventory/resources/weapon_inv.tres")
	weapon_inv.item_dropped.connect(_on_item_dropped)

func _on_item_dropped(item: InvItem, amount: int) -> void:
	var player = get_tree().get_first_node_in_group("player") as Player
	print(player.global_position)
	var facing = player.facing_direction
	var offset = facing * randf_range(24, 40)
	var throw_origin = player.global_position
	var landing_spot = player.global_position + offset
	item_drop_manager.spawn_item_drop(item, amount, throw_origin, landing_spot)
