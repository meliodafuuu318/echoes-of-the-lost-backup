extends Control

class_name MainQuestListUI

signal section_toggled(section: Control, is_open: bool)

@onready var header: Button = $Header
@onready var body_clip: Control = $BodyClip
@onready var body_container: VBoxContainer = $BodyClip/Body
@onready var indicator: TextureRect = $Header/accordion_indicator

var is_open: bool = false
var open_height: float = 0.0
var toggle_tween: Tween
var indicator_tween: Tween

const TOGGLE_DURATION: float = 0.25
const INDICATOR_FLIP_DURATION: float = 0.25

var quest_ui_instances: Array[MainQuestUI] = []

func _ready() -> void:
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_gui_input)

	body_clip.clip_contents = true
	open_height = body_clip.size.y
	body_clip.size.y = open_height if is_open else 0.0
	indicator.flip_h = is_open

	# Initialize the quest manager
	if not MainQuestManager.main_quests_initialized:
		MainQuestManager.initialize_quests()

	# Connect to quest manager signals
	MainQuestManager.quest_updated.connect(_on_quest_updated)
	MainQuestManager.quest_completed.connect(_on_quest_completed)
	
	# Populate UI with quests
	_setup_quest_uis()

func _setup_quest_uis() -> void:
	var all_quests = MainQuestManager.get_all_quests()

	for i in range(body_container.get_child_count()):
		var quest_ui = body_container.get_child(i) as MainQuestUI
		if quest_ui and i < all_quests.size():
			quest_ui.set_quest(all_quests[i])
			quest_ui_instances.append(quest_ui)
		elif quest_ui:
			quest_ui.queue_free()

func _on_quest_updated(quest: MainQuest) -> void:
	for quest_ui in quest_ui_instances:
		if quest_ui.quest == quest:
			quest_ui.update_display()
			break

func _on_quest_completed(quest: MainQuest) -> void:
	for quest_ui in quest_ui_instances:
		if quest_ui.quest == quest:
			quest_ui.on_quest_completed()
			break
	print("[MainQuestListUI] Quest completed: %s" % quest.quest_name)

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
