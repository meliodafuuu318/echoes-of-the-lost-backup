class_name Bee
extends Enemy

## How long the bee can sit un-aggroed (Wander state, not chasing/fighting)
## before it gives up, flies back to where it spawned from, and despawns.
## Set to 0 to disable and let the bee wander forever.
@export var despawn_delay: float = 60.0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = (
	animation_tree.get("parameters/playback")
)

var facing_direction: Vector2 = Vector2.DOWN

var home_position: Vector2
var _undetected_time: float = 0.0
var _returning_to_hive: bool = false


func _ready() -> void:
	super()
	if home_position == Vector2.ZERO:
		home_position = global_position

	animation_tree.set_active(true)
	animation_tree.set("parameters/Idle/blend_position", facing_direction)


func _physics_process(delta: float) -> void:
	super(delta)
	_update_animation()
	_update_despawn_timer(delta)


func _update_animation() -> void:
	if velocity.length() > 1.0:
		facing_direction = velocity.normalized()

	var state_name := "Walk" if velocity.length() > 1.0 else "Idle"
	animation_tree.set("parameters/" + state_name + "/blend_position", facing_direction)
	animation_state.travel(state_name)


func _update_despawn_timer(delta: float) -> void:
	if despawn_delay <= 0.0 or _returning_to_hive:
		return

	if state_machine.state.name == "Wander":
		_undetected_time += delta
		if _undetected_time >= despawn_delay:
			_return_to_hive()
	else:
		_undetected_time = 0.0


func _return_to_hive() -> void:
	_returning_to_hive = true
	set_physics_process(false)
	state_machine.set_physics_process(false)
	velocity = Vector2.ZERO

	var direction := home_position - global_position
	if direction.length() > 1.0:
		facing_direction = direction.normalized()
	_update_animation()

	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position", home_position, 1.5)
	tween.parallel().tween_property($Sprite2D, "modulate:a", 0.0, 1.5)
	await tween.finished
	queue_free()
