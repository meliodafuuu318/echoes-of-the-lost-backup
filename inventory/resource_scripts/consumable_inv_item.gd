extends InvItem

class_name ConsumableItem

@export var heal_amount: int
#@export var attack_buff: int
#@export var speed_buff: float
#@export var buff_duration: float

func use(player: Node) -> bool:
	print("ConsumableItem.use() called — heal_amount: ", heal_amount, " player: ", player)
	if heal_amount <= 0:
		push_warning("ConsumableItem: heal_amount is 0 or less, item won't do anything")
		return false
	if not player.has_method("heal"):
		push_warning("ConsumableItem: player has no heal() method")
		return false
	player.heal(heal_amount)
	return true
