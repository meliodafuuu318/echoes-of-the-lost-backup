extends Control

@onready var task_list_ui: TaskListUI = $task_list_ui
@onready var main_quest_list_ui: MainQuestListUI = $main_quest_list_ui

var sections: Array

func _ready() -> void:
	sections = [task_list_ui, main_quest_list_ui]
	for section in sections:
		section.section_toggled.connect(_on_section_toggled)

	task_list_ui.content_bottom_changed.connect(_on_task_list_bottom_changed)
	_on_task_list_bottom_changed(task_list_ui.get_content_bottom())  # set initial position

func _on_section_toggled(opened_section: Control, is_open: bool) -> void:
	for section in sections:
		if section == opened_section:
			continue
		section.set_open(not is_open)

func _on_task_list_bottom_changed(new_bottom: float) -> void:
	main_quest_list_ui.position.y = task_list_ui.position.y + new_bottom
