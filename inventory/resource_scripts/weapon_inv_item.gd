extends InvItem

class_name WeaponItem

@export var damage: int
#@export var attack_speed: float = 1.0
#@export var crit_chance: float = 0.0
@export var target: Target

enum Target {
	ENEMY,
	OBJECT
}
