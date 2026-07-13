extends InventorySlotUI

class_name ArtifactSlotUI

# Artifact slot UI: only accepts ARTIFACT items.
# Once an artifact is placed, the slot is permanently locked —
# the item cannot be dragged out, dropped (right-click / Q), or swapped.
# Clicking the slot still selects it (reserved for future item-info display).

## True once an artifact has been committed to this slot.
var is_locked: bool = false

func update(slot: InvSlot) -> void:
	# Safety: clear invalid items (non-artifacts) — should never happen in
	# normal play, but guards against editor mistakes.
	if slot and slot.item and slot.item.item_type != InvItem.ItemType.ARTIFACT:
		slot.clear()

	# Null-guard: _ready() may not have run yet on the first call.
	if item_visual == null or amount_text == null:
		return

	item_visual.visible = false
	amount_text.visible = false  # Artifacts are max_stack 1; label never needed.

	if slot and slot.item:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		# Lock permanently once an artifact is in the slot.
		is_locked = true

# ── Input overrides ───────────────────────────────────────────────────────────
# NOTE: We do NOT override _on_gui_input here.
# The base class connects _on_gui_input via signal in _ready(), so overriding
# the method would cause both to run. Instead, we block at the three callsites
# the base class delegates to: _handle_drop, _handle_right_click, and drag
# initiation (guarded below via mouse_pressed block in _on_gui_input override).

func _on_gui_input(event: InputEvent) -> void:
	# If locked, suppress all mouse button events except left-click select.
	if is_locked:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_select()
				get_viewport().set_input_as_handled()
				return
			# Consume right-click and release events so base class never sees them.
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseMotion:
			# Swallow motion events too — prevents the base threshold check from
			# ever setting mouse_pressed = true path into drag_started.
			return

	# Not locked — delegate to base class for normal behaviour (pre-lock drag-in).
	super._on_gui_input(event)

# ── Drop target overrides ─────────────────────────────────────────────────────

func _handle_drop() -> void:
	# Locked slot — nothing can be dragged out.
	if is_locked:
		return

	var target = SlotRegistry.find_slot_at(get_global_mouse_position(), self)
	if target == null:
		return

	# Pre-lock: only allow dropping onto another (empty) artifact slot.
	if not (target is ArtifactSlotUI):
		_deselect()
		return

	_perform_slot_action(target.slot_index, target.inventory)
	_deselect()
	target._select()

# Override to validate incoming drops FROM other slot types.
# Called by the source slot's _perform_slot_action when it targets us.
func _accept_drop_from(source: InventorySlotUI) -> void:
	# Locked slots reject everything.
	if is_locked:
		return

	var source_slot = source.inventory.get_slot_by_index(source.slot_index)
	if source_slot == null or source_slot.item == null:
		return

	# Only ARTIFACT items are accepted.
	if source_slot.item.item_type != InvItem.ItemType.ARTIFACT:
		return

	_cross_inventory_move_from(source)

func _cross_inventory_move_from(source: InventorySlotUI) -> void:
	var source_slot = source.inventory.get_slot_by_index(source.slot_index)
	var target_slot = inventory.get_slot_by_index(slot_index)

	if source_slot == null or source_slot.item == null or target_slot == null:
		return

	if target_slot.item != null:
		# Slot already occupied — reject.
		return

	target_slot.item = source_slot.item
	target_slot.amount = source_slot.amount
	source_slot.clear()

	source.inventory.update.emit()
	inventory.update.emit()

# ── Block right-click drop ───────────────────────────────────────────────────
func _handle_right_click() -> void:
	# Intentionally empty — no dropping from artifact slots ever.
	pass
