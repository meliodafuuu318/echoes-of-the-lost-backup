extends StaticBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

@export var log_scene: PackedScene = preload("res://inventory/scenes/pickup_items/log.tscn")
@export var apple_scene: PackedScene = preload("res://inventory/scenes/pickup_items/apple.tscn")
@export var spawn_radius: float = 50.0

var has_died: bool = false
var _hovered: bool = false
var spawned_drops: Array = []
var current_day: int = 0


func _exit_tree() -> void:
	var save_data = GameManager.get_data_entry(get_path())
	save_data["hp"] = health_component.health
	# GameManager.data goes straight into JSON via SaveManager, which can't
	# represent a raw Vector2 — it silently gets str()'d into something like
	# "(12, 34)" and then blows up on load when assigned back to
	# global_position. Store it as a plain [x, y] array instead, same as
	# GameManager.anting_anting_saved_pos already does correctly.
	save_data["pos"] = [global_position.x, global_position.y]
	save_data["frame"] = sprite_2d.frame

	if has_died:
		save_data["dead"] = true
		if GameManager.has_data_value(get_path(), "drops"):
			save_data["drops"] = GameManager.get_data_value(get_path(), "drops")
		else:
			save_data["drops"] = spawned_drops

	GameManager.store_data_entry(get_path(), save_data)

func _ready() -> void:
	$interaction_area.input_event.connect(_on_input_event)
	health_component.died.connect(_on_died)
	Events.time_tick.connect(_on_time_tick)
	
	var value = GameManager.get_data_entry(get_path())
	if not value:
		sprite_2d.frame = randi_range(0, 1)
		return
	
	health_component.health = value["hp"]
	var pos_arr: Array = value["pos"]
	global_position = Vector2(pos_arr[0], pos_arr[1])
	sprite_2d.frame = value["frame"]
	
	if value.has("dead") and value["dead"]:
		has_died = true
		spawned_drops = value.get("drops", [])
		if spawned_drops.size() > 0:
			_spawn_drops(spawned_drops)
		queue_free()
		return

	if health_component.health <= 0:
		if value.has("drops"):
			has_died = true
			spawned_drops = value["drops"]
			_spawn_drops(spawned_drops)
			queue_free()
		else:
			health_component.die()

		health_component.die()
		
func _on_time_tick(day: int, _hour: int, _minute: int) -> void:
	current_day = day

func _on_died() -> void:
	if has_died:
		return
	has_died = true
	spawned_drops = []
	
	var log_count = randi_range(1, 3)
	
	var last_collection_day = GameManager.get_data_value(get_path(), "last_collection_day")
	var should_spawn_apples = last_collection_day != current_day
	var apple_count = randi_range(3,4) if should_spawn_apples else 0
	
	for i in range(log_count):
		var angle = randf() * TAU
		var distance = randf_range(20.0, spawn_radius)
		var offset = Vector2(cos(angle), sin(angle)) * distance

		var log_position = global_position + offset
		var log_drop := {"id": "log_%d" % spawned_drops.size(), "item": "log", "pos": [log_position.x, log_position.y]}
		spawned_drops.append(log_drop)
		_spawn_drop(log_scene, log_drop)
		
	for i in range(apple_count):
		var angle = randf() * TAU
		var distance = randf_range(20.0, spawn_radius)
		var offset = Vector2(cos(angle), sin(angle)) * distance

		var apple_position = global_position + offset
		var apple_drop := {"id": "apple_%d" % spawned_drops.size(), "item": "apple", "pos": [apple_position.x, apple_position.y]}
		spawned_drops.append(apple_drop)
		_spawn_drop(apple_scene, apple_drop)

	queue_free()
	DailyTaskManager.update_task_progress("3", 1)
	
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_try_collect()
		
func _try_collect() -> void:
	var last_collection_day = GameManager.get_data_value(get_path(), "last_collection_day")
	
	if last_collection_day == current_day:
		print("🌳 Already collected from this tree today! Come back tomorrow.")
		return
	
	var _item: InvItem = load("res://inventory/resources/inventory_items/apple.tres")
	var _inv: Inventory = load("res://inventory/resources/player_inv.tres")
	var collected_amount = randi_range(2, 4)
	
	if _item == null or _inv == null:
		push_warning("apple: missing item or inventory resource.")
		return
	
	GameManager.store_data_value(get_path(), "last_collection_day", current_day)
	_inv.insert(_item, collected_amount)
	print("🍎 Collected %d apples! Come back tomorrow for more." % collected_amount)
	DailyTaskManager.update_task_progress("1", collected_amount)
	
func _on_mouse_entered() -> void:
	_hovered = true
	# Brighten the sprite slightly so the player knows it's clickable.
	modulate = Color(1.4, 1.4, 1.4)

func _on_mouse_exited() -> void:
	_hovered = false
	modulate = Color.WHITE


func _spawn_drops(drops: Array) -> void:
	for drop in drops:
		var item_scene: PackedScene
		match drop["item"]:
			"log":
				item_scene = log_scene
			"apple":
				item_scene = apple_scene
			_:
				continue

		_spawn_drop(item_scene, drop)


func _spawn_drop(item_scene: PackedScene, drop: Dictionary) -> void:
	var drop_instance = item_scene.instantiate()
	var pos_arr: Array = drop["pos"]
	drop_instance.global_position = Vector2(pos_arr[0], pos_arr[1])
	drop_instance.set_meta("tree_save_path", get_path())
	drop_instance.set_meta("drop_id", drop["id"])
	get_parent().call_deferred("add_child", drop_instance)
