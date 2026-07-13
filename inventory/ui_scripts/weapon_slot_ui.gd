extends InventorySlotUI

class_name WeaponSlotUI


# Weapon slot UI: only accepts WEAPON items, enforces max amount 1
# Animations:
# - "default": not selected, no item
# - "selected": selected, no item
# - "equipped": not selected, has item
# - "equipped_selected": selected, has item

func update(slot: InvSlot) -> void:
	# Safety: clear invalid items (non-weapons)
	if slot and slot.item and slot.item.item_type != InvItem.ItemType.WEAPON:
		slot.clear()
	
	# Safety: enforce max amount = 1 (redundant with max_stack, but defensive)
	if slot and slot.item and slot.amount > 1:
		slot.amount = 1
	
	# Null check: wait for _ready() to initialize visuals
	if item_visual == null or amount_text == null:
		return
	
	item_visual.visible = false
	amount_text.visible = false
	
	if slot and slot.item:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		GameManager.player_weapon = slot.item
		Events.player_weapon_equipped.emit(slot.item)
	else:
		GameManager.player_weapon = null
	
	# Update animation after item state changes
	_update_animation_state()

func _update_animation_state() -> void:
	"""Update animation based on equipped state and selection state"""
	if animated_sprite == null:
		return
	
	var slot = inventory.get_slot_by_index(slot_index)
	var has_item = slot and slot.item != null
	var is_selected = currently_selected == self
	
	# Determine which animation to play based on both states
	if is_selected and has_item:
		animated_sprite.play("equipped_selected")
	elif is_selected and not has_item:
		animated_sprite.play("selected")
	elif not is_selected and has_item:
		animated_sprite.play("equipped")
	else:  # not selected and no item
		animated_sprite.play("default")

func _select() -> void:
	"""Override to update animation state when selected"""
	if currently_selected and currently_selected != self:
		currently_selected._deselect()
	currently_selected = self
	_update_animation_state()

func _deselect() -> void:
	"""Override to update animation state when deselected"""
	# Only deselect if this slot is currently selected
	if currently_selected == self:
		currently_selected = null
	_update_animation_state()
