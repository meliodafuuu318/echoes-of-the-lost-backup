extends HitboxComponent

var base_damage: float = 0.0


func _ready() -> void:
	Events.player_weapon_equipped.connect(_on_player_weapon_equipped)
	Events.artifact_buffs_changed.connect(_on_artifact_buffs_changed)

	# GameManager.player_weapon may already be set (e.g. returning from
	# another scene), so pick up the current damage immediately rather than
	# waiting for the next equip event.
	if GameManager.player_weapon:
		base_damage = GameManager.player_weapon.damage
	_update_attack_damage()


func _on_player_weapon_equipped(item: WeaponItem) -> void:
	base_damage = item.damage
	_update_attack_damage()


func _on_artifact_buffs_changed(_health_buff: float, _attack_buff: float) -> void:
	_update_attack_damage()


func _update_attack_damage() -> void:
	attack_damage = base_damage + GameManager.artifact_attack_buff
