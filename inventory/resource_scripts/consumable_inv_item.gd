extends InvItem

class_name ConsumableItem

const OUTSIDE = preload("uid://c5g3ll83gblw0")

@export var is_sapling: bool

@export_group("Heal")
@export var can_heal: bool
@export var heal_amount: int

#@export_group("Buff")

func use(player: Node) -> bool:
	if can_heal:
		print("ConsumableItem.use() called — heal_amount: ", heal_amount, " player: ", player)
		if not player.has_method("heal"):
			push_warning("ConsumableItem: player has no heal() method")
			return false
		player.heal(heal_amount)
		return true
	elif is_sapling:
		return true
	else:
		return false
