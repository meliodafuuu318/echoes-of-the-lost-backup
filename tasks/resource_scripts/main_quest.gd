extends Resource

class_name MainQuest

@export var quest_id: String = ""
@export var quest_name: String = ""
@export var description: String = ""
@export var target_amount: int
@export var reward_item: InvItem
@export var reward_amount: int

var current_progress: int = 0
var is_completed: bool = false
var reward_claimed: bool = false

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
		"reward_claimed": reward_claimed,
	}

func from_dict(data: Dictionary) -> void:
	current_progress = data.get("current_progress", 0)
	is_completed = data.get("is_completed", false)
	reward_claimed = data.get("reward_claimed", false)
