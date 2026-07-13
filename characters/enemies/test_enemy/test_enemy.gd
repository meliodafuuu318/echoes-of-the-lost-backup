class_name TestEnemy
extends Enemy

@onready var animation_tree: AnimationTree = $AnimationTree


func _ready() -> void:
	super()
	
	animation_tree.set_active(true)
	
	animation_tree.set("parameters/Idle/blend_position", Vector2.DOWN)
