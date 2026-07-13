class_name HurtboxComponent
extends Area2D

@export var health_component: HealthComponent
@export var invincible_time: float = 0.5

func damage(attack: Attack) -> void:
	if health_component:
		health_component.damage(attack, invincible_time)
