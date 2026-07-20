extends CharacterBody2D

@onready var interactable: Interactable = $Interactable

const FISH_ITEM_PATH := "res://inventory/resources/inventory_items/fish.tres"
const HONEY_ITEM_PATH := "res://inventory/resources/inventory_items/honey.tres"
const IRON_ITEM_PATH := "res://inventory/resources/inventory_items/iron.tres"
const PLAYER_INV_PATH := "res://inventory/resources/player_inv.tres"

const FISH_IRON_CHANCE := 0.01   # 1% iron, 99% random other material
const HONEY_IRON_CHANCE := 0.5   # 50% iron, 50% random other material

var current_day: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interactable.interact = _on_interact
	Events.time_tick.connect(_on_time_tick)
	Dialogic.signal_event.connect(_on_dialogic_signal)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_time_tick(day: int, _hour: int, _minute: int) -> void:
	current_day = day

func _has_traded_today() -> bool:
	var last_trade_day = GameManager.get_data_value(get_path(), "last_trade_day")
	return last_trade_day == current_day

func _on_interact(player: Player) -> void:
	var inv: Inventory = load(PLAYER_INV_PATH)
	var fish_item: InvItem = load(FISH_ITEM_PATH)
	var honey_item: InvItem = load(HONEY_ITEM_PATH)

	Dialogic.VAR.set_variable("BearSpirit.introduced", GameManager.bear_introduced)
	Dialogic.VAR.set_variable("BearSpirit.traded_today", _has_traded_today())
	Dialogic.VAR.set_variable("BearSpirit.player_has_fish", inv.count_item(fish_item.id) > 0)
	Dialogic.VAR.set_variable("BearSpirit.player_has_honey", inv.count_item(honey_item.id) > 0)

	Dialogic.start("bear_spirit_timeline")
	player.state_machine.set_physics_process(false)
	player.state_machine._transition_to_next_state(PlayerState.IDLE)

	await Dialogic.timeline_ended

	player.state_machine.set_physics_process(true)

	if not GameManager.bear_introduced:
		GameManager.bear_introduced = true


func _on_dialogic_signal(argument: Variant) -> void:
	match argument:
		"give_fish":
			_trade(FISH_ITEM_PATH, FISH_IRON_CHANCE)
		"give_honey":
			_trade(HONEY_ITEM_PATH, HONEY_IRON_CHANCE)


func _trade(offered_item_path: String, iron_chance: float) -> void:
	var inv: Inventory = load(PLAYER_INV_PATH)
	var offered_item: InvItem = load(offered_item_path)
	var iron_item: InvItem = load(IRON_ITEM_PATH)

	if _has_traded_today():
		Dialogic.VAR.set_variable("BearSpirit.reward_item", "")
		return

	if inv.count_item(offered_item.id) <= 0:
		Dialogic.VAR.set_variable("BearSpirit.reward_item", "")
		return

	inv.remove(offered_item, 1)
	GameManager.store_data_value(get_path(), "last_trade_day", current_day)

	var reward_item: InvItem = iron_item
	if randf() >= iron_chance:
		reward_item = _pick_random_other_material(iron_item)

	inv.insert(reward_item, 1)

	Dialogic.VAR.set_variable("BearSpirit.reward_item", reward_item.name)


func _pick_random_other_material(exclude_item: InvItem) -> InvItem:
	var candidates: Array[InvItem] = []
	for item in ItemManager.get_all_items():
		if item.item_type == InvItem.ItemType.MATERIAL and item.id != exclude_item.id:
			candidates.append(item)

	if candidates.is_empty():
		return exclude_item

	return candidates[randi() % candidates.size()]
