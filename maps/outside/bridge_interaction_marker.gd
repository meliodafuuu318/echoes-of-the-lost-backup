extends Node2D

signal bridge_built

const PLAYER_INV = preload("uid://bn2stjinnsiyq")
const LOG = preload("uid://cnkt4rivm68pq")
const HAMMER = preload("uid://bmdgshv0cqx6r")

@export var bridge_uncomplete: TileMapLayer
@export var bridge_finished: TileMapLayer
@export var required_log_amount: int = 50

var is_built: bool = false

@onready var interactable: Interactable = $Interactable


func _enter_tree() -> void:
	if GameManager.get_data_value(get_path(), "is_built") == true:
		_build_bridge()
		queue_free()


func _exit_tree() -> void:
	GameManager.store_data_value(get_path(), "is_built", is_built)


func _ready() -> void:
	interactable.interact = _on_interact


func _build_bridge() -> void:
	bridge_uncomplete.enabled = false
	bridge_finished.enabled = true
	is_built = true
	bridge_built.emit()
	queue_free()
	if is_built:
		MainQuestManager.update_quest_progress("2", 1)


func _on_interact() -> void:
	var weapon = GameManager.player_weapon
	var is_hammer_equipped = weapon and weapon.name == "Hammer"
	var has_hammer = PLAYER_INV.count_item(HAMMER.id) > 0
	var current_logs = PLAYER_INV.count_item(LOG.id)
	
	if current_logs >= required_log_amount and is_hammer_equipped:
		PLAYER_INV.remove(LOG, required_log_amount)
		_build_bridge()
	else:
		Dialogic.VAR.set_variable("Bridge.LogsRequired", required_log_amount)
		Dialogic.VAR.set_variable("Bridge.HasHammer", has_hammer)
		Dialogic.start("bridge_timeline")
