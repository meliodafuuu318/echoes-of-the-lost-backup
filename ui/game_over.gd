extends Control

var win: bool

@onready var label: Label = $VBoxContainer/Label


func _ready() -> void:
	label.text = "You Win!" if win else "You Died"


func _process(_delta: float) -> void:
	pass


func _on_start_new_game_button_pressed() -> void:
	Events.new_game_started.emit()
	await Events.scene_load_finished
	queue_free()


func _on_exit_button_pressed() -> void:
	get_tree().quit()
