class_name Enemy
extends CharacterBody2D

var instance_id: String

@onready var health_component: HealthComponent = $HealthComponent
@onready var state_machine: StateMachine = $StateMachine


func _enter_tree() -> void:
	if instance_id.is_empty():
		return
	var saved_pos = GameManager.get_data_value(instance_id, "pos")
	if saved_pos:
		global_position = saved_pos


func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_death)
	
	if not instance_id.is_empty():
		var saved_hp = GameManager.get_data_value(instance_id, "hp")
		if saved_hp:
			health_component.health = saved_hp
			if health_component.health <= 0:
				health_component.die()


func _exit_tree() -> void:
	if instance_id.is_empty():
		return
	GameManager.store_data_value(instance_id, "pos", global_position)
	GameManager.store_data_value(instance_id, "hp", health_component.health)


func _physics_process(_delta: float) -> void:
	move_and_slide()


func _on_health_changed(_current_health: float, _attack: Attack) -> void:
	pass


func _on_death() -> void:
	GameManager.remove_data_entry(instance_id)
	instance_id = ""
	queue_free()
