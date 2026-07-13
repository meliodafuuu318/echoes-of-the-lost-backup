class_name HitboxComponent
extends Area2D

@export var attack_damage: float = 1.0
@export var knockback_force: float

var _active_hurtboxes: Array[HurtboxComponent] = []


func attack_hurtbox(hurtbox: HurtboxComponent) -> void:
	var attack = Attack.new()
	attack.attack_damage = attack_damage
	attack.knockback_force = knockback_force
	attack.attack_position = get_owner().global_position
	attack.attacker = get_owner()

	hurtbox.damage(attack)


func _physics_process(_delta: float) -> void:
	for hurtbox in _active_hurtboxes:
		if is_instance_valid(hurtbox):
			attack_hurtbox(hurtbox)


func is_overlapping_attacker(node: Node) -> bool:
	for hurtbox in _active_hurtboxes:
		if hurtbox.get_owner() == node:
			return true
	return false


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		_active_hurtboxes.append(area)


func _on_area_exited(area: Area2D) -> void:
	if area is HurtboxComponent:
		_active_hurtboxes.erase(area)
