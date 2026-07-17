extends CanvasLayer

## Full-screen dark overlay with a transparent "hole" centered on the player
## that fades to full darkness with distance — the cave map's
## limited-visibility effect. Stays hidden (and idle) on every other map.
## Mirrors camera_2d.gd's Events.map_changed handling for the on/off switch.

@export var overlay_rect: ColorRect
@export var player: Player


func _ready() -> void:
	Events.map_changed.connect(_on_map_changed)
	set_process(visible)


func _on_map_changed(map: Events.Map) -> void:
	var is_cave: bool = map == Events.Map.CAVE
	visible = is_cave
	set_process(is_cave)


func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not overlay_rect or not overlay_rect.material:
		return

	# Converts the player's world position into the same screen-pixel space
	# CanvasLayer content is drawn in, so the hole tracks the player
	# regardless of camera position/zoom.
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * player.global_position
	overlay_rect.material.set_shader_parameter("light_center", screen_pos)
