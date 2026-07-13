extends Panel

class_name IngredientUI

const INSUFFICIENT_ALPHA := 0.4

@onready var item_display: Sprite2D = $CenterContainer/Panel/item_display
@onready var amount_label: Label = $CenterContainer/Panel/Label
@onready var ingredient_name: Label = $CenterContainer/Panel/item_display/Panel/ingredient_name
@onready var ingredient_name_panel: Panel = $CenterContainer/Panel/item_display/Panel

var ingredient: Ingredient
var player_has: int = 0

var hover_timer: float = 0.0
const HOVER_DURATION: float = 1.0 
var is_hovering: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if item_display:
		ingredient_name.visible = false
		ingredient_name_panel.visible = false
		
	update_display()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_hovering:
		hover_timer += delta
		if hover_timer >= HOVER_DURATION:
			_show_ingredient_info()
	else:
		# Reset timer when not hovering
		hover_timer = 0.0
		if ingredient_name:
			ingredient_name.visible = false
			ingredient_name_panel.visible = false


func set_ingredient(new_ingredient: Ingredient, has_amount: int = 0) -> void:
	ingredient = new_ingredient
	player_has = has_amount
	if is_node_ready():
		update_display()


func update_display() -> void:
	if not ingredient or not ingredient.material:
		return

	item_display.texture = ingredient.material.texture
	amount_label.text = "%d/%d" % [player_has, ingredient.amount]
	ingredient_name.text = "Name: %s" % [ingredient.material.name]

	var has_enough := player_has >= ingredient.amount
	item_display.modulate.a = 1.0 if has_enough else INSUFFICIENT_ALPHA
	
func _on_mouse_entered() -> void:	
	# Start hover detection (timer starts in _process)
	is_hovering = true
	hover_timer = 0.0

func _on_mouse_exited() -> void:
	# Stop hover detection
	is_hovering = false
	hover_timer = 0.0
	if ingredient_name:
		ingredient_name.visible = false
		ingredient_name_panel.visible = false

func _show_ingredient_info():	
	ingredient_name_panel.visible = true
	ingredient_name.visible = true
