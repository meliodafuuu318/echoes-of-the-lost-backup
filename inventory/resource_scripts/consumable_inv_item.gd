extends InvItem

class_name ConsumableItem

@export var heal_amount: int
#@export var attack_buff: int
#@export var speed_buff: float
#@export var buff_duration: float

func use(player: Node) -> bool:
	print("ConsumableItem.use() called — heal_amount: ", heal_amount, " player: ", player)
	if not player.has_method("heal"):
		push_warning("ConsumableItem: player has no heal() method")
		return false
	player.heal(heal_amount)
	return true
