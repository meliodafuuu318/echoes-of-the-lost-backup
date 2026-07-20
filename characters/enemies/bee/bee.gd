class_name Bee
extends Enemy

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = (
	animation_tree.get("parameters/playback")
)

var facing_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	super()
	animation_tree.set_active(true)
	animation_tree.set("parameters/Idle/blend_position", facing_direction)


func _physics_process(delta: float) -> void:
	super(delta)
	_update_animation()


func _update_animation() -> void:
	if velocity.length() > 1.0:
		facing_direction = velocity.normalized()

	var state_name := "Walk" if velocity.length() > 1.0 else "Idle"
	animation_tree.set("parameters/" + state_name + "/blend_position", facing_direction)
	animation_state.travel(state_name)
