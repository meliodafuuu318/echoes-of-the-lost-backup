extends Node

signal task_updated(task: Task)
signal task_completed(task: Task)
signal tasks_reset

var tasks: Dictionary[String, Task] = {}
var current_day: int = 0
var daily_tasks_initialized: bool = false

func _ready() -> void:
	Events.time_tick.connect(_on_time_tick)
	SaveManager.game_loaded.connect(reload_from_save)

func reload_from_save() -> void:
	if not daily_tasks_initialized:
		initialize_tasks()
		return

	var saved_data = GameManager.get_data_entry("DailyTasks")
	if saved_data.is_empty():
		return

	current_day = saved_data.get("day", current_day)
	for task_id in tasks.keys():
		var task_data = saved_data.get(task_id, {})
		if task_data:
			tasks[task_id].from_dict(task_data)
	tasks_reset.emit()

func _on_time_tick(day: int, _hour: int, _minute: int) -> void:
	if current_day != day:
		current_day = day
		_check_daily_reset()

func _check_daily_reset() -> void:
	# Load tasks for this day, reset if needed
	var saved_day = GameManager.get_data_value("DailyTasks", "last_reset_day")
	
	if saved_day != current_day:
		reset_daily_tasks()

func initialize_tasks() -> void:
	if daily_tasks_initialized:
		return
	
	_create_default_tasks()
	daily_tasks_initialized = true
	
	# Load saved progress for today
	var saved_data = GameManager.get_data_entry("DailyTasks")
	if saved_data and saved_data.get("day") == current_day:
		for task_id in tasks.keys():
			var task_data = saved_data.get(task_id, {})
			if task_data:
				tasks[task_id].from_dict(task_data)

func _create_default_tasks() -> void:
	# Load task resources
	var task_resources = [
		load("res://tasks/resources/dailytask1.tres"),
		load("res://tasks/resources/dailytask2.tres"),
		load("res://tasks/resources/dailytask3.tres"),
		load("res://tasks/resources/dailytask4.tres"),
		load("res://tasks/resources/dailytask5.tres")
	]
	
	for task_resource in task_resources:
		if task_resource is Task:
			var task = task_resource.duplicate()  # Duplicate to avoid modifying the original resource
			tasks[task.task_id] = task
		else:
			push_warning("Failed to load task resource")

func reset_daily_tasks() -> void:
	for task in tasks.values():
		task.reset()
	
	GameManager.store_data_value("DailyTasks", "last_reset_day", current_day)
	save_tasks()
	tasks_reset.emit()
	print("[DailyTasks] Tasks reset for day %d" % current_day)

func update_task_progress(task_id: String, amount: int = 1) -> void:
	if not tasks.has(task_id):
		push_warning("Task not found: %s" % task_id)
		return
	
	var task = tasks[task_id]
	if task.is_completed:
		return
	
	task.current_progress += amount
	if task.is_complete() and not task.is_completed:
		task.is_completed = true
		task.completed_on_day = current_day
		task_completed.emit(task)
		claim_reward(task_id)
		print("[DailyTasks] Task completed: %s" % task.task_name)
	
	task_updated.emit(task)
	save_tasks()

func claim_reward(task_id: String) -> bool:
	if not tasks.has(task_id):
		return false
	
	var task = tasks[task_id]
	if not task.is_completed or task.reward_claimed:
		return false
	
	# Apply rewards - give the reward item from the task resource
	if task.reward_item and task.reward_item_amount > 0:
		var inv = load("res://inventory/resources/player_inv.tres") as Inventory
		if inv:
			inv.insert(task.reward_item, task.reward_item_amount)
			print("[DailyTasks] Reward claimed for task: %s (+%d %s)" % [task.task_name, task.reward_item_amount, task.reward_item.name])
	
	task.reward_claimed = true
	save_tasks()
	return true

func save_tasks() -> void:
	var save_data = {"day": current_day}
	for task_id in tasks.keys():
		save_data[task_id] = tasks[task_id].to_dict()
	GameManager.store_data_entry("DailyTasks", save_data)

func get_task(task_id: String) -> Task:
	return tasks.get(task_id)

func get_all_tasks() -> Array[Task]:
	var task_array: Array[Task] = []
	for task in tasks.values():
		task_array.append(task)
	return task_array


func reset_daily_tasks_for_new_game() -> void:
	tasks.clear()
	current_day = 0
	daily_tasks_initialized = false

	initialize_tasks()

	# Save clean daily task state
	save_tasks()

	tasks_reset.emit()
	print("[DailyTasks] Daily tasks reset for new game")
