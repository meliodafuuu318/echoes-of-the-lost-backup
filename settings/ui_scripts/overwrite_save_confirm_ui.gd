extends Control

## Shown by settings_ui when Save is pressed on a slot that already has a
## save file. Purely a yes/no gate — settings_ui owns which slot is
## pending and actually calls SaveManager.save_game() once `confirmed`
## fires. Mirrors quit_confirm_ui's confirmed-signal pattern.

signal confirmed
signal cancelled

@onready var confirm_button: TextureButton = $Panel/confirm_button
@onready var cancel_button: TextureButton = $Panel/cancel_button


func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)


func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	hide()
	cancelled.emit()
