extends Panel

class_name HotbarSlotUI

# Display-only mirror of an inventory slot shown on the HUD hotbar.
# It does not handle drag-and-drop; interaction happens in the inventory UI.

var item_visual: Sprite2D
var amount_text: Label

func _ready() -> void:
	item_visual = $CenterContainer/Panel/Sprite2D
	amount_text = $CenterContainer/Panel/Label

func update(slot: InvSlot) -> void:
	"""Reflect the state of the given inventory slot"""
	item_visual.visible = false
	amount_text.visible = false

	if slot and slot.item:
		item_visual.visible = true
		item_visual.texture = slot.item.texture

		if slot.amount > 1:
			amount_text.visible = true
			amount_text.text = str(slot.amount)
