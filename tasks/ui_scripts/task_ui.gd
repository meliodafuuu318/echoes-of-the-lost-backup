extends Panel

class_name TaskUI

@onready var checkbox = $NinePatchRect/Panel/AnimatedSprite2D
@onready var label = $NinePatchRect/Label
@onready var progress_bar = $NinePatchRect/ProgressBar if has_node("NinePatchRect/ProgressBar") else null
@onready var reward = $task_info/reward
@onready var description = $task_info/description as Label
@onready var desc_panel = $task_info as Panel

var task: Task = null

var hover_timer: float = 0.0
const HOVER_DURATION: float = 1.0  # Display tooltip after 1 second of hovering
var is_hovering: bool = false

func _ready() -> void:
	# Draw the tooltip in global/viewport space so it renders above every
	# sibling row and header, and is never clipped by this row's ancestors
	# (e.g. the list's BodyClip). We restore its visual position manually
	# below since top_level changes what "position" means.
	var local_offset: Vector2 = desc_panel.position
	desc_panel.top_level = true
	desc_panel.z_as_relative = false
	desc_panel.z_index = 100
	desc_panel.set_meta("local_offset", local_offset)

	if task:
		update_display()
		
func _process(delta: float) -> void:
	# Update hover timer if hovering
	if is_hovering:
		hover_timer += delta
		if hover_timer >= HOVER_DURATION:
			_show_task_description()
	else:
		# Reset timer when not hovering
		hover_timer = 0.0
		if description:
			description.visible = false
			desc_panel.visible = false
		
func _on_mouse_entered() -> void:
	# Start hover detection (timer starts in _process)
	is_hovering = true
	hover_timer = 0.0

func _on_mouse_exited() -> void:
	# Stop hover detection
	is_hovering = false
	hover_timer = 0.0
	if description:
		description.visible = false
		desc_panel.visible = false
		
func _show_task_description():
	desc_panel.global_position = global_position + desc_panel.get_meta("local_offset")
	description.visible = true
	desc_panel.visible = true

func set_task(new_task: Task) -> void:
	task = new_task
	if is_node_ready():
		update_display()

func update_display() -> void:
	if not task:
		return
	
	# Update label with task name and progress
	var display_progress = min(task.current_progress, task.target_amount)
	var progress_text = "%s (%d/%d)" % [task.task_name, display_progress, task.target_amount]
	var reward_text = "Reward: %s x%d" % [task.reward_item.name, task.reward_item_amount]
	var desc_text = "Description: %s" % [task.description]
	label.text = progress_text
	reward.text = reward_text
	description.text = desc_text
	
	# Update checkbox animation state
	if task.is_completed:
		checkbox.play("done")
		label.add_theme_color_override("font_color", Color.GREEN)
	else:
		checkbox.play("default")
		label.add_theme_color_override("font_color", Color.BLACK)
	
	# Update progress bar if it exists
	if progress_bar:
		progress_bar.value = task.get_progress_percent() * 100.0

func on_task_completed() -> void:
	if task:
		update_display()
		# Optional: Play a completion animation or sound
		print("[TaskUI] %s completed!" % task.task_name)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if task and task.is_completed and not task.reward_claimed:
			DailyTaskManager.claim_reward(task.task_id)
			update_display()
