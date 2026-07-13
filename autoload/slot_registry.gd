extends Node
 
# Autoload this as "SlotRegistry".
# Every InventorySlotUI registers itself here so that drag-and-drop works
# across separate UI scenes (inventory menu + hotbar HUD).
 
var _slots: Array[InventorySlotUI] = []
 
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register(slot: InventorySlotUI) -> void:
	if slot not in _slots:
		_slots.append(slot)
 
func unregister(slot: InventorySlotUI) -> void:
	_slots.erase(slot)
 
func get_all() -> Array[InventorySlotUI]:
	return _slots
 
func find_slot_at(global_pos: Vector2, exclude: InventorySlotUI = null) -> InventorySlotUI:
	for slot in _slots:
		if slot == exclude:
			continue
		if slot.get_global_rect().has_point(global_pos):
			return slot
	return null

# ── Selection-based lookup (preferred for gameplay) ──
func find_selected() -> InventorySlotUI:
	"""Return the currently selected slot, or null"""
	return InventorySlotUI.currently_selected

func find_selected_in_inventory(inv: Inventory) -> InventorySlotUI:
	"""Return the currently selected slot if it's in the given inventory"""
	var selected = InventorySlotUI.currently_selected
	if selected and selected.inventory == inv:
		return selected
	return null
