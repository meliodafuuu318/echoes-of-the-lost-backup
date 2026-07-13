extends Panel

class_name RecipeUI

signal recipe_selected(recipe: Recipe)

@onready var recipe_name_label = $NinePatchRect/Label
@onready var item_display = $NinePatchRect/Panel/item_display
@onready var animated_sprite: AnimatedSprite2D = $NinePatchRect/AnimatedSprite2D

var recipe: Recipe
var is_selected: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_display()
	gui_input.connect(_on_gui_input)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func set_recipe(new_recipe: Recipe) -> void:
	recipe = new_recipe
	if is_node_ready():
		update_display()

func update_display() -> void:
	if not recipe:
		return

	recipe_name_label.text = recipe.name
	item_display.texture = recipe.product.texture


func set_selected(selected: bool) -> void:
	is_selected = selected
	if animated_sprite:
		animated_sprite.play("selected" if selected else "default")


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if recipe:
			recipe_selected.emit(recipe)
