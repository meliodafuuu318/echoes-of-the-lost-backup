extends HitboxComponent

# Used for the "Chop" animation's hitbox, which is shared by every
# OBJECT-target tool (axe, hammer, ...). Since only one physical hitbox
# node is actually driven by the Chop animation, this script switches
# its collision_mask to match whichever tool is currently equipped so
# each tool only ever hits its intended target type.

const TREE_MASK := 64   # layer 7: Environtment Attacks
const STONE_MASK := 128 # layer 8: Stone Attacks


func _ready() -> void:
	Events.player_weapon_equipped.connect(_on_player_weapon_equipped)


func _on_player_weapon_equipped(item: WeaponItem) -> void:
	if item.target != WeaponItem.Target.OBJECT:
		return

	attack_damage = item.damage

	match item.name:
		"Axe":
			collision_mask = TREE_MASK
		"Hammer":
			collision_mask = STONE_MASK
