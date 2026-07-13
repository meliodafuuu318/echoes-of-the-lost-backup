extends Manananggal

@onready var health_ui: CanvasLayer = $HealthUI
@onready var health_bar: ProgressBar = $HealthUI/MarginContainer/VBoxContainer/HealthBar


func _ready() -> void:
	super()
	health_bar.init_health(health_component.health)


func _on_health_changed(current_health: float, attack: Attack) -> void:
	super(current_health, attack)
	health_bar.health = current_health


func _on_death() -> void:
	MainQuestManager.update_quest_progress("3", 1)
	$HealthUI.hide()
	super()
	Events.game_over.emit(true)


func _on_show_health_bar_detection_body_entered(_body: Node2D) -> void:
	health_ui.show()


func _on_show_health_bar_detection_body_exited(_body: Node2D) -> void:
	health_ui.hide()
