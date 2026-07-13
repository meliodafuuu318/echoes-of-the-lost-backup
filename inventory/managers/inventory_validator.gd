extends Node
 
class_name InventoryValidator
 
static func can_hold_item(inventory: Inventory, item: InvItem, amount: int = 1) -> bool:
	"""Check if inventory can hold item"""
	var space_needed = amount
	
	# Count existing stacks of this item
	for slot in inventory.slots:
		if slot.item and slot.item.id == item.id:
			var room = item.max_stack - slot.amount
			if room > 0:
				space_needed -= mini(room, space_needed)
				if space_needed <= 0:
					return true
	
	# Check empty slots
	var empty_slots = 0
	for slot in inventory.slots:
		if slot.item == null:
			empty_slots += 1
	
	var slots_needed = ceil(float(space_needed) / item.max_stack)
	return empty_slots >= slots_needed
 
static func is_slot_valid(inventory: Inventory, slot_index: int) -> bool:
	"""Check if slot index is valid"""
	return slot_index >= 0 and slot_index < inventory.slots.size()
 
static func can_move_to_slot(inventory: Inventory, from_index: int, to_index: int) -> bool:
	"""Check if move operation is valid"""
	if not (is_slot_valid(inventory, from_index) and is_slot_valid(inventory, to_index)):
		return false
	
	var from_slot = inventory.slots[from_index]
	if from_slot.item == null:
		return false
	
	return true
