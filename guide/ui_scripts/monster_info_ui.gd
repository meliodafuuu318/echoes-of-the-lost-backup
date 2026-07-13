extends Control

class_name MonsterInfoUI

@onready var monster_display: Sprite2D = $NinePatchRect/Panel/CenterContainer/monster_display
@onready var monster_stats: Label = $NinePatchRect/monster_stats
@onready var monster_description: Label = $NinePatchRect/ScrollContainer/content/monster_description


func display(monster: Monster) -> void:
	if monster == null:
		return

	monster_display.texture = monster.texture
	monster_display.scale = Vector2(6.0, 6.0)
	monster_display.position = Vector2(55.538, 57.0)

	monster_description.text = monster.description

	_update_stats(monster)


func reset_display() -> void:
	monster_display.texture = null
	monster_description.text = ""
	monster_stats.text = ""
	monster_stats.visible = false


func _update_stats(monster: Monster) -> void:
	var stats_text := "HP: %d   ATK: %d" % [monster.max_health, monster.attack_damage]
	monster_stats.text = stats_text
	monster_stats.visible = true
