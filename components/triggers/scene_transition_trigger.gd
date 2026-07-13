extends Area2D

@export var target_map: Events.Map
@export var target_spawn: String


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		get_tree().current_scene.switch_map(target_map, target_spawn)
		await Events.scene_load_finished
