extends Panel

class_name MainQuestUI

@onready var checkbox = $NinePatchRect/Panel/AnimatedSprite2D
@onready var label = $NinePatchRect/Label
@onready var progress_bar = $NinePatchRect/ProgressBar if has_node("NinePatchRect/ProgressBar") else null
@onready var reward = $quest_info/reward
@onready var description = $quest_info/description as Label
@onready var desc_panel = $quest_info as Panel

var quest: MainQuest = null

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

	if quest:
		update_display()

func _process(delta: float) -> void:
	# Update hover timer if hovering
	if is_hovering:
		hover_timer += delta
		if hover_timer >= HOVER_DURATION:
			_show_quest_description()
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

func _show_quest_description():
	desc_panel.global_position = global_position + desc_panel.get_meta("local_offset")
	description.visible = true
	desc_panel.visible = true

func set_quest(new_quest: MainQuest) -> void:
	quest = new_quest
	if is_node_ready():
		update_display()

func update_display() -> void:
	if not quest:
		return

	# Update label with quest name and progress
	var display_progress = min(quest.current_progress, quest.target_amount)
	var progress_text = "%s (%d/%d)" % [quest.quest_name, display_progress, quest.target_amount]
	var reward_text: String
	if quest.reward_item:
		reward_text = "Reward: %s x%d" % [quest.reward_item.name, quest.reward_amount]
	var desc_text = "Description: %s" % [quest.description]
	label.text = progress_text
	if reward_text:
		reward.text = reward_text
		description.set_position(Vector2.ZERO)
	else:
		desc_panel.remove_child(reward)
		description.set_position(Vector2(2.0, 6.0))
	description.text = desc_text

	# Update checkbox animation state
	if quest.is_completed:
		checkbox.play("done")
		label.add_theme_color_override("font_color", Color.GREEN)
	else:
		checkbox.play("default")
		label.add_theme_color_override("font_color", Color.BLACK)

	# Update progress bar if it exists
	if progress_bar:
		progress_bar.value = quest.get_progress_percent() * 100.0

func on_quest_completed() -> void:
	if quest:
		update_display()
		# Optional: Play a completion animation or sound
		print("[MainQuestUI] %s completed!" % quest.quest_name)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if quest and quest.is_completed and not quest.reward_claimed:
			MainQuestManager.claim_reward(quest.quest_id)
			update_display()
