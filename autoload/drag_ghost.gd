# DragGhost.gd - autoload this as "DragGhost"
extends Node

var ghost: TextureRect = null
var canvas: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = CanvasLayer.new()
	canvas.layer = 100  # renders on top of everything
	add_child(canvas)

func start(texture: Texture2D, pos: Vector2) -> void:
	if ghost:
		stop()
	ghost = TextureRect.new()
	ghost.texture = texture
	ghost.size = Vector2(32, 32)          # match your item icon size
	ghost.pivot_offset = ghost.size / 2   # center it on cursor
	ghost.modulate = Color(1, 1, 1, 0.75) # slightly transparent
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ghost)
	ghost.global_position = pos - ghost.pivot_offset

func stop() -> void:
	if ghost:
		ghost.queue_free()
		ghost = null


# Spawns a standalone icon at `from_pos` that flies to `to_pos`, shrinking and
# fading out on arrival, then frees itself. Independent of the cursor-following
# `ghost` above — used for "item was crafted, here it goes into your inventory"
# feedback rather than drag-and-drop.
func fly_to(texture: Texture2D, from_pos: Vector2, to_pos: Vector2, duration: float = 1.5) -> void:
	var flying_ghost := TextureRect.new()
	flying_ghost.texture = texture
	flying_ghost.size = Vector2(32, 32)
	flying_ghost.pivot_offset = flying_ghost.size / 2
	flying_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(flying_ghost)
	flying_ghost.global_position = from_pos - flying_ghost.pivot_offset

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(flying_ghost, "global_position", to_pos - flying_ghost.pivot_offset, duration)
	tween.tween_property(flying_ghost, "scale", Vector2(0.4, 0.4), duration)
	tween.chain().tween_property(flying_ghost, "modulate:a", 0.0, 0.1)
	tween.chain().tween_callback(flying_ghost.queue_free)


# Used for artifact-pickup feedback (e.g. the anting-anting "found" popup):
# spawns a copy of the artifact's sprite at `from_pos`, sized to match the
# artifact's actual on-screen size, then continuously shrinks it while it
# travels to `to_pos` (the hotbar), disappearing the instant it arrives.
#
# Unlike fly_to(), which stays full-size and only fades at the end, this
# tweens "scale" alongside "position" for the whole trip so the shrink is
# continuous and finishes exactly as the ghost reaches the hotbar.
func fly_and_shrink(texture: Texture2D, from_pos: Vector2, to_pos: Vector2, start_size: Vector2, duration: float = 1.5) -> void:
	if texture == null:
		push_error("DragGhost.fly_and_shrink: texture is null, nothing to show.")
		return
	if not is_instance_valid(canvas):
		push_error("DragGhost.fly_and_shrink: canvas is null/invalid — DragGhost autoload may not have run _ready() yet.")
		return

	var shrinking_ghost := TextureRect.new()
	shrinking_ghost.texture = texture
	shrinking_ghost.size = start_size
	shrinking_ghost.pivot_offset = start_size / 2
	shrinking_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shrinking_ghost)
	shrinking_ghost.position = from_pos - shrinking_ghost.pivot_offset
	print("DragGhost.fly_and_shrink: ghost spawned at ", shrinking_ghost.position, " size ", start_size, " -> ", to_pos)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(shrinking_ghost, "position", to_pos - shrinking_ghost.pivot_offset, duration)
	tween.tween_property(shrinking_ghost, "scale", Vector2.ZERO, duration)
	tween.chain().tween_callback(shrinking_ghost.queue_free)


func _process(_delta: float) -> void:
	if ghost:
		ghost.global_position = ghost.get_global_mouse_position() - ghost.pivot_offset
