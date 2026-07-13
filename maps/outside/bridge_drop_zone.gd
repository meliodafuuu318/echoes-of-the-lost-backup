extends Area2D

@export var bridge_uncomplete: TileMapLayer
@export var bridge_finished: TileMapLayer

var is_built: bool = false


func _enter_tree() -> void:
	if GameManager.get_data_value(get_path(), "is_built") == true:
		_build_bridge()
		queue_free()


func _exit_tree() -> void:
	GameManager.store_data_value(get_path(), "is_built", is_built)


func _build_bridge() -> void:
	bridge_uncomplete.enabled = false
	bridge_finished.enabled = true
	is_built = true


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bridge"):
		_build_bridge()
		
		area.queue_free()
		queue_free()
