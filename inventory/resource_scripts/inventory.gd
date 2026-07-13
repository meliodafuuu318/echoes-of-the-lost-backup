extends Resource

class_name Inventory

signal update
signal item_dropped(item: InvItem, amount: int)

@export var slots: Array[InvSlot]

func insert(item: InvItem, amount: int = 1):
	"""Insert item(s) into inventory, stacking if possible"""
	var remaining = amount
	
	# Try to stack with existing items
	for slot in slots:
		if slot.item and slot.item.id == item.id and slot.amount < item.max_stack:
			var space = item.max_stack - slot.amount
			var to_add = mini(space, remaining)
			slot.amount += to_add
			remaining -= to_add
			if remaining <= 0:
				update.emit()
				return
	
	# Fill empty slots
	for slot in slots:
		if slot.item == null:
			var to_add = mini(item.max_stack, remaining)
			slot.item = item
			slot.amount = to_add
			remaining -= to_add
			if remaining <= 0:
				update.emit()
				return
	
	# If still items left, inventory is full
	update.emit()

func remove(item: InvItem, amount: int = 1):
	for slot in slots:
		if slot.item and slot.item.id == item.id:
			slot.amount -= amount
			
			if slot.amount <= 0:
				slot.item = null
				slot.amount = 0
			
			update.emit()
			return

func move_slot(from_index: int, to_index: int) -> bool:
	"""Move entire stack from one slot to another (merge with existing stacks)"""
	if from_index < 0 or from_index >= slots.size() or to_index < 0 or to_index >= slots.size():
		return false
	
	var from_slot = slots[from_index]
	var to_slot = slots[to_index]
	
	if from_slot.item == null:
		return false
	
	# If target is empty, just move
	if to_slot.item == null:
		to_slot.item = from_slot.item
		to_slot.amount = from_slot.amount
		from_slot.clear()
		update.emit()
		return true
	
	# If target has different item, swap
	if to_slot.item.id != from_slot.item.id:
		return swap_slot(from_index, to_index)
	
	# If same item, try to stack
	if stack_slots(from_index, to_index):
		return true
	
	# If stacking failed (no space), swap instead
	return swap_slot(from_index, to_index)

func swap_slot(index_a: int, index_b: int) -> bool:
	"""Swap two slots completely"""
	if index_a < 0 or index_a >= slots.size() or index_b < 0 or index_b >= slots.size():
		return false
	
	var temp_item = slots[index_a].item
	var temp_amount = slots[index_a].amount
	
	slots[index_a].item = slots[index_b].item
	slots[index_a].amount = slots[index_b].amount
	
	slots[index_b].item = temp_item
	slots[index_b].amount = temp_amount
	
	update.emit()
	return true

func stack_slots(from_index: int, to_index: int) -> bool:
	"""Stack items from one slot into another (same item type)"""
	if from_index < 0 or from_index >= slots.size() or to_index < 0 or to_index >= slots.size():
		return false
	
	var from_slot = slots[from_index]
	var to_slot = slots[to_index]
	
	if from_slot.item == null or to_slot.item == null:
		return false
	
	if from_slot.item.id != to_slot.item.id:
		return false
	
	var item = from_slot.item
	var space = item.max_stack - to_slot.amount
	
	if space <= 0:
		return false
	
	var transfer = mini(space, from_slot.amount)
	to_slot.amount += transfer
	from_slot.amount -= transfer
	
	if from_slot.amount <= 0:
		from_slot.clear()
	
	update.emit()
	return true

func drop_item(slot_index: int, amount: int = 1) -> bool:
	"""Remove item from inventory and emit signal for dropping in world"""
	if slot_index < 0 or slot_index >= slots.size():
		return false
	
	var slot = slots[slot_index]
	
	if slot.item == null or amount <= 0:
		return false
	
	var drop_amount = mini(amount, slot.amount)
	var dropped_item = slot.item
	slot.amount -= drop_amount
	
	if slot.amount <= 0:
		slot.clear()
	
	item_dropped.emit(dropped_item, drop_amount)
	update.emit()
	return true

func get_slot_by_index(index: int) -> InvSlot:
	"""Get slot by index"""
	if index >= 0 and index < slots.size():
		return slots[index]
	return null

func find_item_slot(item_id: String) -> int:
	"""Find first slot containing item"""
	for i in range(slots.size()):
		if slots[i].item and slots[i].item.id == item_id:
			return i
	return -1

func count_item(item_id: String) -> int:
	"""Count total amount of item in inventory"""
	var total = 0
	for slot in slots:
		if slot.item and slot.item.id == item_id:
			total += slot.amount
	return total
	
func to_save_dict() -> Dictionary:
	"""Serialize this inventory to a JSON-safe dictionary (item ids + amounts only)."""
	var slot_data: Array = []
	for slot in slots:
		if slot.item == null:
			slot_data.append({})
		else:
			slot_data.append({"item_id": slot.item.id, "amount": slot.amount})
	return {"slots": slot_data}

func load_from_save_dict(data: Dictionary) -> void:
	"""Restore this inventory from a dict produced by to_save_dict().
	Looks up items by id via ItemManager — adjust the lookup call below if
	your item database lives elsewhere or has a different method name."""
	var slot_data: Array = data.get("slots", [])
	for i in range(mini(slot_data.size(), slots.size())):
		var entry: Dictionary = slot_data[i]
		if entry.is_empty():
			slots[i].clear()
		else:
			var item: InvItem = ItemManager.get_item_by_id(entry.get("item_id", ""))
			slots[i].item = item
			slots[i].amount = entry.get("amount", 0)
	update.emit()

func use_item(slot_index: int, player: Node) -> bool:
	var slot = get_slot_by_index(slot_index)
	if slot == null or slot.item == null:
		return false

	# Guard by item_type enum — safer than class check alone
	if slot.item.item_type != InvItem.ItemType.CONSUMABLE:
		return false

	# Also confirm it's actually a ConsumableItem script
	if not slot.item is ConsumableItem:
		return false

	var consumed: bool = (slot.item as ConsumableItem).use(player)
	if consumed:
		slot.amount -= 1
		if slot.amount <= 0:
			slot.clear()
		update.emit()

	return consumed


func clear() -> void:
	for slot in slots:
		slot.clear()

	update.emit()


func copy_from(other: Inventory) -> void:
	for i in range(slots.size()):
		if i < other.slots.size():
			slots[i].item = other.slots[i].item
			slots[i].amount = other.slots[i].amount
		else:
			slots[i].clear()

	update.emit()
