extends Control

class_name CraftingUI

# Emitted after a successful craft. `from_pos` is where the ghost animation
# should originate from (the product icon in this UI).
signal item_crafted(product: InvItem, from_pos: Vector2)

const IngredientUIScene: PackedScene = preload("res://crafting/scenes/ingredient_ui.tscn")

const MAX_INGREDIENT_COLUMNS := 3

@onready var product_display: Sprite2D = $NinePatchRect/product_ui/CenterContainer/item_display
@onready var product_name: Label = $NinePatchRect/product_ui/product_name
@onready var description_scroll: ScrollContainer = $NinePatchRect/product_ui/ScrollContainer
@onready var description_panel: Panel = $NinePatchRect/product_ui/ScrollContainer/Panel
@onready var product_description: Label = $NinePatchRect/product_ui/ScrollContainer/Panel/product_description
@onready var ingredients_grid: GridContainer = $NinePatchRect/ingredients_grid
@onready var craft_button: TextureButton = $NinePatchRect/craft_button

var player_inv: Inventory = preload("res://inventory/resources/player_inv.tres")

var current_recipe: Recipe

# Vertical scrollbar for the description box. Kept invisible until the user
# actually scrolls, then faded back out after a short idle period.
var _description_scrollbar: VScrollBar
var _scrollbar_fade_tween: Tween


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	craft_button.pressed.connect(_craft)
	player_inv.update.connect(_on_player_inv_update)

	_description_scrollbar = description_scroll.get_v_scroll_bar()
	_description_scrollbar.modulate.a = 0.0
	_description_scrollbar.value_changed.connect(_on_description_scrolled)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func display_recipe(recipe: Recipe) -> void:
	current_recipe = recipe

	if not recipe:
		return

	if recipe.product:
		product_display.texture = recipe.product.texture
		product_name.text = recipe.product.name
		product_description.text = recipe.product.description
		_update_description_size()

	_populate_ingredients(recipe.ingredients)


func reset_display() -> void:
	current_recipe = null
	product_display.texture = null
	product_name.text = ""
	product_description.text = ""
	_update_description_size()
	_populate_ingredients([])


func _update_description_size() -> void:
	# The Panel that wraps product_description is the ScrollContainer's
	# scrollable content. Instead of a fixed height (which made it always
	# scrollable, even for a one-line description), measure the actual
	# wrapped text height and only let the panel grow that tall. The
	# ScrollContainer then only allows scrolling once real content
	# overflows its visible area.
	var font: Font = product_description.get_theme_font("font")
	var font_size: int = product_description.get_theme_font_size("font_size")
	var wrap_width: float = product_description.offset_right - product_description.offset_left
	var text_size: Vector2 = font.get_multiline_string_size(
		product_description.text,
		HORIZONTAL_ALIGNMENT_CENTER,
		wrap_width,
		font_size,
	)
	description_panel.custom_minimum_size.y = text_size.y * product_description.scale.y


func _on_description_scrolled(_value: float) -> void:
	_flash_description_scrollbar()


func _flash_description_scrollbar() -> void:
	# Briefly reveal the scrollbar, then fade it back out after a short
	# idle period so it stays hidden unless the user is actively scrolling.
	if _scrollbar_fade_tween:
		_scrollbar_fade_tween.kill()
	_scrollbar_fade_tween = create_tween()
	_scrollbar_fade_tween.tween_property(_description_scrollbar, "modulate:a", 1.0, 0.1)
	_scrollbar_fade_tween.tween_interval(0.8)
	_scrollbar_fade_tween.tween_property(_description_scrollbar, "modulate:a", 0.0, 0.4)


func _populate_ingredients(ingredients: Array[Ingredient]) -> void:
	var existing_slots := ingredients_grid.get_children()

	for i in range(existing_slots.size()):
		var slot := existing_slots[i] as IngredientUI
		if not slot:
			continue
		if i < ingredients.size():
			_update_ingredient_slot(slot, ingredients[i])
			slot.visible = true
		else:
			slot.visible = false

	# In case a recipe has more ingredients than there are slots in the grid.
	for i in range(existing_slots.size(), ingredients.size()):
		var new_slot: IngredientUI = IngredientUIScene.instantiate()
		ingredients_grid.add_child(new_slot)
		_update_ingredient_slot(new_slot, ingredients[i])

	ingredients_grid.columns = clampi(ingredients.size(), 1, MAX_INGREDIENT_COLUMNS)
	_center_ingredients_grid()


func _update_ingredient_slot(slot: IngredientUI, ingredient: Ingredient) -> void:
	var has_amount := player_inv.count_item(ingredient.material.id) if ingredient.material else 0
	slot.set_ingredient(ingredient, has_amount)


func _center_ingredients_grid() -> void:
	# ingredients_grid's parent isn't a layout Container, so its box doesn't
	# auto-shrink to fit its children. Resize it to its content's minimum
	# width and re-center it within the parent each time the column count
	# (and therefore the grid's width) changes.
	var grid_width: float = ingredients_grid.get_combined_minimum_size().x
	var grid_height: float = ingredients_grid.get_combined_minimum_size().y
	var parent_width: float = ingredients_grid.get_parent().size.x
	var center_x: float = parent_width / 2.0

	ingredients_grid.offset_left = center_x - grid_width / 2.0
	ingredients_grid.offset_right = center_x + grid_width / 2.0
	ingredients_grid.offset_bottom = ingredients_grid.offset_top + grid_height


func _on_player_inv_update() -> void:
	# Keep the displayed x/y counts and opacity in sync with the player's
	# inventory (e.g. items picked up or used elsewhere while this is open).
	if current_recipe:
		_populate_ingredients(current_recipe.ingredients)


func _can_craft(recipe: Recipe) -> bool:
	if not recipe:
		return false

	for ingredient in recipe.ingredients:
		if not ingredient.material:
			continue
		if player_inv.count_item(ingredient.material.id) < ingredient.amount:
			return false

	return true


func _craft() -> void:
	print("crafting")
	if not _can_craft(current_recipe):
		return

	for ingredient in current_recipe.ingredients:
		if ingredient.material:
			player_inv.remove(ingredient.material, ingredient.amount)

	var product_display_pos = product_display.get_global_transform_with_canvas().origin
	if current_recipe.product:
		player_inv.insert(current_recipe.product, 1)
		item_crafted.emit(current_recipe.product, product_display_pos)
