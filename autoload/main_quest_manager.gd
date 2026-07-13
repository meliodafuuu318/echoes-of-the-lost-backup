extends Node

signal quest_updated(quest: MainQuest)
signal quest_completed(quest: MainQuest)

var quests: Dictionary[String, MainQuest] = {}
var main_quests_initialized: bool = false

func _ready() -> void:
	SaveManager.game_loaded.connect(reload_from_save)

func reload_from_save() -> void:
	if not main_quests_initialized:
		initialize_quests()
		return

	var saved_data = GameManager.get_data_entry("MainQuests")
	if saved_data.is_empty():
		return

	for quest_id in quests.keys():
		var quest_data = saved_data.get(quest_id, {})
		if quest_data:
			quests[quest_id].from_dict(quest_data)

func initialize_quests() -> void:
	if main_quests_initialized:
		return

	_create_default_quests()
	main_quests_initialized = true

	# Load saved progress
	var saved_data = GameManager.get_data_entry("MainQuests")
	if saved_data:
		for quest_id in quests.keys():
			var quest_data = saved_data.get(quest_id, {})
			if quest_data:
				quests[quest_id].from_dict(quest_data)

func _create_default_quests() -> void:
	# Load quest resources
	var quest_resources = [
		load("res://tasks/resources/mainquest1.tres"),
		load("res://tasks/resources/mainquest2.tres"),
		load("res://tasks/resources/mainquest3.tres"),
	]

	for quest_resource in quest_resources:
		if quest_resource is MainQuest:
			var quest = quest_resource.duplicate()  # Duplicate to avoid modifying the original resource
			quests[quest.quest_id] = quest
		else:
			push_warning("Failed to load main quest resource")

func update_quest_progress(quest_id: String, amount: int = 1) -> void:
	if not quests.has(quest_id):
		push_warning("Quest not found: %s" % quest_id)
		return

	var quest = quests[quest_id]
	if quest.is_completed:
		return

	quest.current_progress += amount
	if quest.is_complete() and not quest.is_completed:
		quest.is_completed = true
		quest_completed.emit(quest)
		claim_reward(quest_id)
		print("[MainQuests] Quest completed: %s" % quest.quest_name)

	quest_updated.emit(quest)
	save_quests()

func claim_reward(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false

	var quest = quests[quest_id]
	if not quest.is_completed or quest.reward_claimed:
		return false

	# Apply reward - give the reward item from the quest resource
	if quest.reward_item and quest.reward_amount > 0:
		var inv = load("res://inventory/resources/player_inv.tres") as Inventory
		if inv:
			inv.insert(quest.reward_item, quest.reward_amount)
			print("[MainQuests] Reward claimed for quest: %s (+%d %s)" % [quest.quest_name, quest.reward_amount, quest.reward_item.name])

	quest.reward_claimed = true
	save_quests()
	return true

func save_quests() -> void:
	var save_data = {}
	for quest_id in quests.keys():
		save_data[quest_id] = quests[quest_id].to_dict()
	GameManager.store_data_entry("MainQuests", save_data)

func get_quest(quest_id: String) -> MainQuest:
	return quests.get(quest_id)

func get_all_quests() -> Array[MainQuest]:
	var quest_array: Array[MainQuest] = []
	for quest in quests.values():
		quest_array.append(quest)
	return quest_array


func reset_quests() -> void:
	quests.clear()
	main_quests_initialized = false
	initialize_quests()
	save_quests()

	print("[MainQuests] Quests reset for new game")
