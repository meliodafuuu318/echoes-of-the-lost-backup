extends Node

## Assign your Recipe resources (e.g. axe_recipe.tres) here in the Inspector.
@export var recipe_resources: Array[Recipe] = []

var recipes: Dictionary[String, Recipe] = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_recipes()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _load_recipes() -> void:
	for recipe in recipe_resources:
		if recipe == null:
			continue
		if recipe.id.is_empty():
			push_warning("RecipeManager: skipped a Recipe resource with an empty id.")
			continue
		recipes[recipe.id] = recipe
	print(recipes)

func get_all_recipes() -> Array[Recipe]:
	var recipe_array: Array[Recipe] = []
	for recipe in recipes.values():
		recipe_array.append(recipe)
	return recipe_array

func get_recipe(id: String) -> Recipe:
	return recipes.get(id)
