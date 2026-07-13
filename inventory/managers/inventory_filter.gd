extends Node
 
class_name InventoryFilter
 
func filter_by_type(inventory: Inventory, item_type: InvItem.ItemType) -> Array[InvSlot]:
	"""Get all slots containing items of specific type"""
	var filtered: Array[InvSlot] = []
	for slot in inventory.slots:
		if slot.item and slot.item.item_type == item_type:
			filtered.append(slot)
	return filtered
 
func filter_by_id(inventory: Inventory, item_id: String) -> Array[InvSlot]:
	"""Get all slots containing specific item ID"""
	var filtered: Array[InvSlot] = []
	for slot in inventory.slots:
		if slot.item and slot.item.id == item_id:
			filtered.append(slot)
	return filtered
 
func get_empty_slots(inventory: Inventory) -> Array[int]:
	"""Get indices of empty slots"""
	var empty: Array[int] = []
	for i in range(inventory.slots.size()):
		if inventory.slots[i].item == null:
			empty.append(i)
	return empty
 
func has_space(inventory: Inventory, amount: int = 1) -> bool:
	"""Check if inventory has space for items"""
	return len(get_empty_slots(inventory)) >= amount
