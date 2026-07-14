extends Node2D
## Rotating "shining" light-ray burst for high-rarity item popups (the
## classic radial glow you see behind a legendary drop icon).
##
## Pure procedural draw code — no texture/particle asset needed. Uses
## additive blending so bright pixels actually glow against the dark
## backdrop instead of flatly overlaying it.
##
## SETUP: add as a Node2D child of anting_anting_found, positioned at the
## icon's on-screen CENTER, and placed BEFORE the TextureRect in the node
## tree (earlier sibling = drawn first = appears behind the icon).

## Where the burst is centered, in the parent node's local coordinates.
## Editing this (rather than the generic Transform > Position field) is the
## easiest way to re-center it if you resize/move the icon later — it
## drives this node's actual position immediately, live in the editor.
@export var center_position: Vector2 = Vector2(623, 268):
	set(value):
		center_position = value
		position = value

@export var ray_count: int = 10
@export var ray_length: float = 420.0
@export var ray_base_color: Color = Color(1.0, 0.95, 0.7, 0.5)

@export var glow_radius: float = 260.0
@export var glow_color: Color = Color(1.0, 0.97, 0.8, 0.35)

## Radians/sec. Positive = clockwise.
@export var spin_speed: float = 0.12
## Radians/sec for the fainter, shorter second ring of rays — going the
## opposite way from spin_speed is what sells the "shimmer" look.
@export var counter_spin_speed: float = -0.2

@export var pulse_speed: float = 1.4
@export var pulse_amount: float = 0.1

var _time: float = 0.0
var _counter_rotation: float = 0.0


func _ready() -> void:
	position = center_position
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	rotation += spin_speed * delta
	_counter_rotation += counter_spin_speed * delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 1.0 + sin(_time * pulse_speed) * pulse_amount

	# Soft core glow so the rays don't look like they're radiating from
	# nothing.
	draw_circle(Vector2.ZERO, glow_radius * pulse, glow_color)

	# Main ray ring.
	_draw_ray_ring(ray_count, ray_length * pulse, ray_base_color, 0.0)

	# Fainter, shorter secondary ring spinning the other way.
	var secondary_color: Color = ray_base_color
	secondary_color.a *= 0.55
	_draw_ray_ring(
		ray_count,
		ray_length * 0.65 * pulse,
		secondary_color,
		_counter_rotation - rotation
	)


## Draws `count` triangular rays evenly spaced around the origin, each
## fading from `color` at the center to transparent at the tip.
## extra_rotation offsets this ring relative to the node's own rotation
## (used to make the secondary ring spin independently of the primary one).
func _draw_ray_ring(count: int, length: float, color: Color, extra_rotation: float) -> void:
	var angle_step: float = TAU / count
	var half_width: float = 0.045  # radians — how fanned-out each ray is

	for i in range(count):
		var angle: float = i * angle_step + extra_rotation
		var tip: Vector2 = Vector2.RIGHT.rotated(angle) * length
		var left: Vector2 = Vector2.RIGHT.rotated(angle - half_width) * length
		var right: Vector2 = Vector2.RIGHT.rotated(angle + half_width) * length

		var faded: Color = color
		faded.a = 0.0

		var points: PackedVector2Array = [Vector2.ZERO, left, tip, right]
		var colors: PackedColorArray = [color, faded, faded, faded]
		draw_polygon(points, colors)
