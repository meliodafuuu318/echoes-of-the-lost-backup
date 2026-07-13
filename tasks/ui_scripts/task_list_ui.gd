extends Control

class_name TaskListUI

signal section_toggled(section: Control, is_open: bool)
signal content_bottom_changed(new_bottom: float)

@onready var panel: NinePatchRect = $NinePatchRect
@onready var grid_container = $NinePatchRect/BodyClip/Body/GridContainer
@onready var label = $NinePatchRect/Header/Label
@onready var refresh_timer_label = $NinePatchRect/Header/refresh_timer
@onready var header: Button = $NinePatchRect/Header
@onready var body_clip: Control = $NinePatchRect/BodyClip
@onready var indicator: TextureRect = $NinePatchRect/Header/accordion_indicator

var is_open: bool = true
var open_height: float = 0.0
var toggle_tween: Tween
var indicator_tween: Tween

const TOGGLE_DURATION: float = 0.25
const INDICATOR_FLIP_DURATION: float = 0.25

var task_ui_prefab: PackedScene = preload("res://tasks/scenes/task_ui.tscn")
var task_ui_instances: Array[TaskUI] = []

# Timer tracking
var current_day: int = 0
var current_hour: int = 0
var current_minute: int = 0

func _ready() -> void:
	body_clip.clip_contents = true
	open_height = body_clip.size.y
	body_clip.size.y = open_height if is_open else 0.0
	body_clip.resized.connect(_on_body_clip_resized)
	_on_body_clip_resized()
	header.pressed.connect(_on_header_pressed)
	indicator.flip_h = is_open
	# Initialize the task manager
	if not DailyTaskManager.daily_tasks_initialized:
		DailyTaskManager.initialize_tasks()
	
	# Connect to task manager signals
	DailyTaskManager.task_updated.connect(_on_task_updated)
	DailyTaskManager.task_completed.connect(_on_task_completed)
	DailyTaskManager.tasks_reset.connect(_on_tasks_reset)
	
	# Connect to time tick for countdown updates
	Events.time_tick.connect(_on_time_tick)
	
	# Populate UI with tasks
	_setup_task_uis()

func _setup_task_uis() -> void:
	var all_tasks = DailyTaskManager.get_all_tasks()
	
	for i in range(grid_container.get_child_count()):
		var task_ui = grid_container.get_child(i) as TaskUI
		if task_ui and i < all_tasks.size():
			task_ui.set_task(all_tasks[i])
			task_ui_instances.append(task_ui)
		elif task_ui:
			task_ui.queue_free()

func _on_time_tick(day: int, hour: int, minute: int) -> void:
	current_day = day
	current_hour = hour
	current_minute = minute
	_update_countdown_timer()

func _on_task_updated(task: Task) -> void:
	for task_ui in task_ui_instances:
		if task_ui.task == task:
			task_ui.update_display()
			break

func _on_task_completed(task: Task) -> void:
	for task_ui in task_ui_instances:
		if task_ui.task == task:
			task_ui.on_task_completed()
			break
	print("[TaskListUI] Task completed: %s" % task.task_name)

func _on_tasks_reset() -> void:
	_setup_task_uis()

func _update_countdown_timer() -> void:
	# Calculate time remaining until next day (midnight / 00:00)
	var hours_until_reset = 24 - current_hour - 1
	var minutes_until_reset = 60 - current_minute
	
	# Handle the edge case where we're at minute 59
	if minutes_until_reset == 60:
		minutes_until_reset = 0
		hours_until_reset += 1
	
	# Format as HH:MM
	var timer_text = "Refresh in: %02d:%02d" % [hours_until_reset, minutes_until_reset]
	refresh_timer_label.text = timer_text
	
func _on_header_pressed() -> void:
	set_open(!is_open)
	section_toggled.emit(self, is_open)

func set_open(value: bool, animate: bool = true) -> void:
	is_open = value
	var target_height: float = open_height if is_open else 0.0

	if toggle_tween and toggle_tween.is_valid():
		toggle_tween.kill()

	if not animate:
		body_clip.size.y = target_height
		indicator.flip_h = is_open
		return

	toggle_tween = create_tween()
	toggle_tween.set_trans(Tween.TRANS_CUBIC)
	toggle_tween.set_ease(Tween.EASE_OUT)
	toggle_tween.tween_property(body_clip, "size:y", target_height, TOGGLE_DURATION)

	_animate_indicator_flip(is_open)

	print(["set_open_daily", is_open])

func _animate_indicator_flip(target_flip_h: bool) -> void:
	if indicator.flip_h == target_flip_h:
		return

	if indicator_tween and indicator_tween.is_valid():
		indicator_tween.kill()

	var original_scale_x: float = abs(indicator.scale.x)
	var half_duration: float = INDICATOR_FLIP_DURATION * 0.5

	indicator_tween = create_tween()
	indicator_tween.set_trans(Tween.TRANS_CUBIC)
	indicator_tween.set_ease(Tween.EASE_IN)
	indicator_tween.tween_property(indicator, "scale:x", 0.0, half_duration)
	indicator_tween.tween_callback(func(): indicator.flip_h = target_flip_h)
	indicator_tween.set_ease(Tween.EASE_OUT)
	indicator_tween.tween_property(indicator, "scale:x", original_scale_x, half_duration)

func _is_open() -> bool:
	return is_open

func get_content_bottom() -> float:
	return panel.position.y + panel.size.y

func _on_body_clip_resized() -> void:
	# Panel hugs however much of the body is currently visible,
	# so the whole card shrinks/grows along with the animation.
	panel.size.y = body_clip.position.y + body_clip.size.y
	content_bottom_changed.emit(get_content_bottom())
