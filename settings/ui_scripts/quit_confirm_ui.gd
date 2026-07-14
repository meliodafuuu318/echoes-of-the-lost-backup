extends Control

## Emitted when the player confirms they want to quit to the main menu.
signal confirmed
## Emitted when the player cancels (does NOT fire on a plain close() call).
signal cancelled

@onready var quit_button: TextureButton = $Panel/quit_button
@onready var cancel_button: TextureButton = $Panel/cancel_button


func _ready() -> void:
	quit_button.pressed.connect(_on_quit_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	# Start closed regardless of whatever "visible" the scene/instance was
	# saved with -- open() is the only supported way in.
	visible = false


## mouse_filter = STOP on the full-rect root (and its Blocker child) means
## once we're visible, every click over the whole screen is consumed here
## and never reaches the game menu underneath -- no need to touch the
## background nodes themselves.
func open() -> void:
	visible = true


func close() -> void:
	visible = false


func _on_quit_pressed() -> void:
	confirmed.emit()


func _on_cancel_pressed() -> void:
	close()
	cancelled.emit()
