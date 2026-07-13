extends Resource

class_name Task

enum TaskType { COLLECT, DEFEAT, CHOP, WALK }

@export var task_id: String = ""
@export var task_name: String = ""
@export var description: String = ""
@export var task_type: TaskType = TaskType.COLLECT
@export var target_amount: int = 1
#@export var reward_amount: int = 0  # Coins, XP, etc.
@export var reward_item: InvItem = null
@export var reward_item_amount: int = 0

var current_progress: int = 0
var is_completed: bool = false
var completed_on_day: int = -1
var reward_claimed: bool = false

func reset() -> void:
	current_progress = 0
	is_completed = false
	reward_claimed = false

func get_progress_percent() -> float:
	if target_amount == 0:
		return 0.0
	return minf(float(current_progress) / float(target_amount), 1.0)

func is_complete() -> bool:
	return current_progress >= target_amount

func to_dict() -> Dictionary:
	return {
		"current_progress": current_progress,
		"is_completed": is_completed,
		"completed_on_day": completed_on_day,
		"reward_claimed": reward_claimed
	}

func from_dict(data: Dictionary) -> void:
	current_progress = data.get("current_progress", 0)
	is_completed = data.get("is_completed", false)
	completed_on_day = data.get("completed_on_day", -1)
	reward_claimed = data.get("reward_claimed", false)
