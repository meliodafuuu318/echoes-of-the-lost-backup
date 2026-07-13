extends Node
 
class_name InventoryHotkey
 
@export var hotbar_slots: Array[InventorySlotUI]
var inventory: Inventory
 
func _ready() -> void:
	inventory = get_tree().root.find_child("InventoryUI", true, false).get_inventory()
 
func _input(event: InputEvent) -> void:
	# Number keys 1-6 for hotbar
	if event is InputEventKey and event.pressed:
		var slot_index = -1
		
		match event.keycode:
			KEY_1: slot_index = 0
			KEY_2: slot_index = 1
			KEY_3: slot_index = 2
			KEY_4: slot_index = 3
			KEY_5: slot_index = 4
			KEY_6: slot_index = 5
		
		if slot_index != -1 and slot_index < hotbar_slots.size():
			_use_hotbar_item(slot_index)
 
func _use_hotbar_item(index: int) -> void:
	"""Use/equip item in hotbar slot"""
	var slot = inventory.get_slot_by_index(index)
	if slot and slot.item:
		# Emit signal or call method on player
		get_tree().get_first_child_in_group("player").use_item(slot.item, slot.amount)
