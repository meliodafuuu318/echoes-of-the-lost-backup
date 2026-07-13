## AutoShadow2D
## Attach this as a CHILD of the root object node (e.g. CharacterBody2D,
## StaticBody2D), as a SIBLING of the Sprite2D/AnimatedSprite2D -- not as a
## child of the sprite itself. This keeps the shadow's origin at the root
## node's (0, 0) regardless of how the sprite is offset/positioned, so you
## can freely move the sprite to line it up with the shadow.
##
## Point `sprite_path` at the Sprite2D or AnimatedSprite2D to track. It only
## reads that node's texture/frame for SIZING the shadow -- it never inherits
## the sprite's position, offset, or centered flag.
extends Node2D
class_name AutoShadow2D

@export_group("Target")
## Path to the Sprite2D or AnimatedSprite2D whose drawn size this shadow should match.
@export var sprite_path: NodePath = NodePath("../Sprite2D")

@export_group("Shape")
## Shadow width as a fraction of the sprite's drawn width.
@export_range(0.1, 2.0, 0.01) var width_ratio: float = 0.8
## Shadow height as a fraction of the shadow's width (squash factor).
@export_range(0.05, 1.0, 0.01) var height_ratio: float = 0.3
## Optional texture to use instead of the procedural ellipse (e.g. a soft blob PNG).
@export var shadow_texture: Texture2D

@export_group("Look")
@export var shadow_color: Color = Color(0, 0, 0, 0.45)
@export var segments: int = 32

@export_group("Placement")
## Constant local offset from (0, 0) of the root node, for minor manual tweaks.
@export var extra_offset: Vector2 = Vector2.ZERO

var _target_sprite: CanvasItem
var _shadow_sprite: Sprite2D
var _ellipse_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	_target_sprite = get_node_or_null(sprite_path)
	if not (_target_sprite is Sprite2D or _target_sprite is AnimatedSprite2D):
		push_warning("AutoShadow2D: sprite_path does not point to a Sprite2D or AnimatedSprite2D.")
		set_process(false)
		return

	if shadow_texture:
		_shadow_sprite = Sprite2D.new()
		_shadow_sprite.texture = shadow_texture
		_shadow_sprite.centered = true
		add_child(_shadow_sprite)
	
	if not get_tree().get_first_node_in_group("player"):
		_connect_target_signals()
	_update_shadow()


func _connect_target_signals() -> void:
	if _target_sprite is Sprite2D:
		var s := _target_sprite as Sprite2D
		if not s.texture_changed.is_connected(_update_shadow):
			s.texture_changed.connect(_update_shadow)
		if not s.frame_changed.is_connected(_update_shadow):
			s.frame_changed.connect(_update_shadow)
	elif _target_sprite is AnimatedSprite2D:
		var a := _target_sprite as AnimatedSprite2D
		if not a.frame_changed.is_connected(_update_shadow):
			a.frame_changed.connect(_update_shadow)
		if not a.animation_changed.is_connected(_update_shadow):
			a.animation_changed.connect(_update_shadow)
		if not a.sprite_frames_changed.is_connected(_update_shadow):
			a.sprite_frames_changed.connect(_update_shadow)


## Returns {size: Vector2} describing the target sprite's currently drawn
## frame (used for sizing only), or {} if nothing is drawn yet.
func _get_drawn_frame_info() -> Dictionary:
	if _target_sprite is Sprite2D:
		var s := _target_sprite as Sprite2D
		if s.texture == null:
			return {}
		var size: Vector2 = s.texture.get_size()
		if s.region_enabled:
			size = s.region_rect.size
		elif s.hframes > 1 or s.vframes > 1:
			size = size / Vector2(s.hframes, s.vframes)
		return {"size": size}

	elif _target_sprite is AnimatedSprite2D:
		var a := _target_sprite as AnimatedSprite2D
		var frames: SpriteFrames = a.sprite_frames
		if frames == null or a.animation == &"" or not frames.has_animation(a.animation):
			return {}
		var frame_count: int = frames.get_frame_count(a.animation)
		if frame_count == 0 or a.frame >= frame_count:
			return {}
		var tex: Texture2D = frames.get_frame_texture(a.animation, a.frame)
		if tex == null:
			return {}
		return {"size": tex.get_size()}

	return {}


func _update_shadow() -> void:
	var info := _get_drawn_frame_info()
	if info.is_empty():
		visible = false
		return
	visible = true

	var drawn_size: Vector2 = info["size"]

	# Position is fixed at the parent's local (0, 0), plus any manual tweak.
	# Adjust your sprite/object's own placement so its origin lines up with
	# where the shadow should sit, rather than relying on auto-positioning.
	position = extra_offset

	var shadow_width: float = drawn_size.x * width_ratio
	var shadow_height: float = shadow_width * height_ratio

	if _shadow_sprite:
		var tex_size: Vector2 = _shadow_sprite.texture.get_size()
		_shadow_sprite.scale = Vector2(
			shadow_width / max(tex_size.x, 0.001),
			shadow_height / max(tex_size.y, 0.001)
		)
	else:
		_ellipse_size = Vector2(shadow_width, shadow_height)
		queue_redraw()


func _draw() -> void:
	if _shadow_sprite or _ellipse_size == Vector2.ZERO:
		return
	var points := PackedVector2Array()
	var rx := _ellipse_size.x * 0.5
	var ry := _ellipse_size.y * 0.5
	for i in range(segments):
		var angle: float = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, shadow_color)
