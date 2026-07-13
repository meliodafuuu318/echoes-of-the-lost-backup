extends Control

const DEFAULT_HEADER := "???"
const HEADER_MAX_FONT_SIZE := 75
const HEADER_MIN_FONT_SIZE := 20

@onready var header: Label = $header

@onready var main_categories: Control = $main_categories
@onready var items_category_tab: Control = $main_categories/items_tab
@onready var crafting_category_tab: Control = $main_categories/crafting_tab
@onready var monsters_category_tab: Control = $main_categories/monsters_tab

@onready var items_tab: Control = $items_tab
@onready var crafting_tab: Control = $crafting_tab
@onready var monsters_tab = $monsters_tab

@onready var info_section: Control = $info_section
@onready var item_info: Control = $info_section/item_info
@onready var recipe_info: Control = $info_section/recipe_info

@onready var item_list_ui: ItemListUI = $items_tab/item_list_ui
@onready var item_info_ui: ItemInfoUI = $info_section/item_info/item_info_ui

@onready var back_button: TextureButton = $back_button

@onready var recipe_list_header: Label = $crafting_tab/recipe_list_ui.get_node("Label")
@onready var crafting_ui: CraftingUI = $info_section/recipe_info/crafting_ui
@onready var recipe_list_ui: RecipeListUI = $crafting_tab/recipe_list_ui

@onready var monster_list_ui = $monsters_tab/monster_list_ui
@onready var monster_info = $info_section/monster_info
@onready var monster_info_ui = $info_section/monster_info/monster_info_ui


func _ready() -> void:
	recipe_list_header.visible = false

	items_category_tab.gui_input.connect(_on_category_gui_input.bindv(["items"]))
	crafting_category_tab.gui_input.connect(_on_category_gui_input.bindv(["crafting"]))
	monsters_category_tab.gui_input.connect(_on_category_gui_input.bindv(["monsters"]))

	back_button.pressed.connect(_go_to_categories)
	item_list_ui.item_selected.connect(_on_item_selected)
	recipe_list_ui.recipe_selected.connect(_on_recipe_selected)
	
	monster_list_ui.monster_selected.connect(_on_monster_selected)

	# Reuse crafting_ui read-only, for reference — no crafting from the guide.
	crafting_ui.craft_button.visible = false
	crafting_ui.description_scroll.visible = false

	_go_to_categories()


# ────────────────────────────────────────────────────────────────────────────
# Public reset — called by menu_ui when navigating away / closing the menu
# ────────────────────────────────────────────────────────────────────────────

func reset() -> void:
	_go_to_categories()


# ────────────────────────────────────────────────────────────────────────────
# Level 1 — main categories
# ────────────────────────────────────────────────────────────────────────────

func _go_to_categories() -> void:
	_set_header_text(DEFAULT_HEADER)

	main_categories.visible = true
	back_button.visible = false
	info_section.visible = false

	items_tab.visible = false
	crafting_tab.visible = false
	monsters_tab.visible = false
	item_info.visible = false
	recipe_info.visible = false

	item_list_ui.deselect_all()
	item_info_ui.reset_display()

	recipe_list_ui.deselect_all()
	crafting_ui.reset_display()


# ────────────────────────────────────────────────────────────────────────────
# Level 2 — category selected (list + info section visible, unpopulated)
# ────────────────────────────────────────────────────────────────────────────

func _on_category_gui_input(event: InputEvent, category: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		_open_category(category)


func _open_category(category: String) -> void:
	var category_name = category.substr(0, 1).to_upper() + category.substr(1)
	_set_header_text(category_name)

	main_categories.visible = false
	back_button.visible = true
	info_section.visible = true

	items_tab.visible = category == "items"
	crafting_tab.visible = category == "crafting"
	monsters_tab.visible = category == "monsters"

	item_info.visible = false
	recipe_info.visible = false
	monster_info.visible = false

	if category == "items":
		item_list_ui.populate()
	elif category == "monsters":
		monster_list_ui.populate()


# ────────────────────────────────────────────────────────────────────────────
# Level 3 — item selected (info section populated)
# ────────────────────────────────────────────────────────────────────────────

func _on_item_selected(item: InvItem) -> void:
	item_info.visible = true
	item_info_ui.display(item)


func _on_recipe_selected(recipe: Recipe) -> void:
	recipe_info.visible = true
	crafting_ui.display_recipe(recipe)
	
func _on_monster_selected(monster: Monster) -> void:
	monster_info.visible = true
	monster_info_ui.display(monster)


# ────────────────────────────────────────────────────────────────────────────
# Header — shrink font to fit the label's width
# ────────────────────────────────────────────────────────────────────────────

func _set_header_text(text: String) -> void:
	header.text = text

	var font: Font = header.get_theme_font("font")
	var max_width: float = header.size.x
	if font == null or max_width <= 0.0:
		return

	var font_size: int = HEADER_MAX_FONT_SIZE
	while font_size > HEADER_MIN_FONT_SIZE:
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		if text_width <= max_width:
			break
		font_size -= 1

	header.add_theme_font_size_override("font_size", font_size)
