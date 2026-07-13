class_name HealthComponent
extends Node2D

signal health_changed(current_health: float, attack: Attack)
signal died

@export var sprite_2d: Sprite2D
@export var max_health: float = 10.0
@export var block_hitbox: HitboxComponent

var health: float
var can_take_damage: bool = true
var is_blocking: bool = false
var dead: bool = false


func _ready() -> void:
	health = max_health


func damage(attack: Attack, invincible_time: float = 0.0,
		ignore_invincible: bool = false) -> void:
	if dead:
		return
	if not can_take_damage and not ignore_invincible:
		return
	if is_blocking and block_hitbox.is_overlapping_attacker(attack.attacker):
		return
	
	health -= attack.attack_damage
	health_changed.emit(health, attack)

	if health <= 0:
		die()
		return

	if invincible_time > 0.0:
		_apply_invincibility(invincible_time, attack.attack_damage > 0)


func die() -> void:
	dead = true
	can_take_damage = false
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite_2d, "modulate:a", 0.0, 0.2)
	await tween.parallel().tween_property(sprite_2d, "scale", Vector2.ZERO, 0.2).finished
	get_owner().set_physics_process(false)
	died.emit()


func _apply_invincibility(duration: float, should_flash: bool = true) -> void:
	can_take_damage = false
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	var step = duration / 4.0

	if should_flash:
		tween.tween_property(sprite_2d, "modulate", Color(1, 0.2, 0.2), step)
		tween.tween_property(sprite_2d, "modulate", Color(1, 1, 1), step)
		tween.tween_property(sprite_2d, "modulate", Color(1, 0.2, 0.2), step)
		tween.tween_property(sprite_2d, "modulate", Color(1, 1, 1), step)
	else:
		tween.tween_interval(duration)
	
	tween.finished.connect(func(): can_take_damage = true)


func revive() -> void:
	dead = false
	can_take_damage = true
	is_blocking = false
	
	health = max_health
	
	sprite_2d.modulate = Color.WHITE
	sprite_2d.scale = Vector2.ONE
	
	get_owner().set_physics_process(true)
	
	health_changed.emit(health, null)
