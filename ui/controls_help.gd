extends NinePatchRect

@export var main_menu: Control   # assign the MainMenu node in the Inspector

@onready var help_panel: NinePatchRect = $"."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	help_panel.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_help"):
		toggle()

func toggle():
	if main_menu.visible:
		return
	print("toggle")
	if help_panel.visible:
		help_panel.hide()
	else:
		help_panel.show()
		
