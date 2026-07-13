extends Area2D

# World-space artifact item: "anting_anting"
#
# The player must click the node to collect it — walking through does nothing.
# (The Sprite2D will be replaced with sparkles later so the actual item stays
# hidden; that's a scene-level change and requires no script modifications here.)
#
# On collection:
#   • Tries to insert the anting-anting into the player's artifact inventory.
#   • Only succeeds if there's an empty artifact slot.
#   • On success the node removes itself from the scene.

const ITEM_PATH = "res://inventory/resources/inventory_items/artifact/anting-anting.tres"

# Autoload / singleton name for the artifact inventory — adjust if yours differs.
# If you access it through menu_ui instead, swap this for a direct node reference.
const ARTIFACT_INV_PATH = "res://inventory/resources/artifact_inv.tres"

var _item: InvItem = null
var _artifact_inv: Inventory = null

# Highlights the sparkle sprite when the mouse is over it.
var _hovered: bool = false

@onready var echo: AudioStreamPlayer2D = $Echo
@onready var pickup_sound: AudioStreamPlayer = $PickupSound

func _ready() -> void:
	_item = load(ITEM_PATH) as InvItem
	_artifact_inv = load(ARTIFACT_INV_PATH) as Inventory

	# Enable mouse interaction on the Area2D itself.
	input_pickable = true

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_try_collect()

func _try_collect() -> void:
	if _item == null or _artifact_inv == null:
		push_warning("anting_anting: missing item or inventory resource.")
		return

	# Find a free artifact slot.
	var collected := false
	for slot in _artifact_inv.slots:
		if slot.item == null:
			_artifact_inv.insert(_item, 1)
			slot.amount = 1
			_artifact_inv.update.emit()
			collected = true
			break

	if collected:
		GameManager.anting_anting_collected = true
		MainQuestManager.update_quest_progress("1", 1)
		Events.artifact_collected.emit()
		echo.stop()
		pickup_sound.play()
		hide()
		await pickup_sound.finished
		queue_free()
	# If no free slot, silently do nothing — the player needs to check their
	# artifact slots. You can add UI feedback here later.

# ── Optional hover feedback ───────────────────────────────────────────────────

func _on_mouse_entered() -> void:
	_hovered = true
	# Brighten the sprite slightly so the player knows it's clickable.
	modulate = Color(1.4, 1.4, 1.4)

func _on_mouse_exited() -> void:
	_hovered = false
	modulate = Color.WHITE
