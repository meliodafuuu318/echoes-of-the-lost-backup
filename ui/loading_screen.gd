extends CanvasLayer

signal loading_screen_ready

@export var animation_player: AnimationPlayer


func _ready() -> void:
	Events.scene_progress_changed.connect(_on_scene_progress_changed)
	Events.scene_load_finished.connect(_on_scene_load_finished)
	
	await animation_player.animation_finished
	loading_screen_ready.emit()


func _on_scene_progress_changed(_new_value: float) -> void:
	pass


func _on_scene_load_finished(_loaded_map: PackedScene) -> void:
	fade_out()


func fade_out() -> void:
	if Events.scene_load_finished.is_connected(_on_scene_load_finished):
		Events.scene_load_finished.disconnect(_on_scene_load_finished)
	if Events.scene_progress_changed.is_connected(_on_scene_progress_changed):
		Events.scene_progress_changed.disconnect(_on_scene_progress_changed)

	animation_player.play_backwards("transition")
	await animation_player.animation_finished
	queue_free()
