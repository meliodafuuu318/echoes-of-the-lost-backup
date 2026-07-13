extends Control

class_name ItemInfoUI

@onready var item_display: Sprite2D = $NinePatchRect/Panel/CenterContainer/item_display
@onready var item_stats: Label = $NinePatchRect/item_stats
@onready var item_description: Label = $NinePatchRect/ScrollContainer/content/item_description


func display(item: InvItem) -> void:
	if item == null:
		return
	item_display.texture = item.texture
	item_description.text = item.description
	
	if item.id == "3":
		item_display.scale = Vector2(3.5, 3.5)
		item_display.position = Vector2(65.538, 65.0)
	else:
		item_display.scale = Vector2(6.0, 6.0)
		item_display.position = Vector2(55.538, 57.0)
	
	_update_stats(item)


func reset_display() -> void:
	item_display.texture = null
	item_description.text = ""
	item_stats.text = ""
	item_stats.visible = false


func _update_stats(item: InvItem) -> void:
	var stats_text := ""
	
	if item.name == "Axe" or item.name == "Hammer":
		item_stats.visible = false
		return
	
	if item is WeaponItem:
		stats_text = "Attack: %d" % item.damage
	elif item is ConsumableItem:
		stats_text = "Heal: %d" % item.heal_amount

	item_stats.text = stats_text
	item_stats.visible = stats_text != ""
