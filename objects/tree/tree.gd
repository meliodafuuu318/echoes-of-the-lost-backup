extends StaticBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

@export var log_scene: PackedScene = preload("res://inventory/scenes/pickup_items/log.tscn")
@export var apple_scene: PackedScene = preload("res://inventory/scenes/pickup_items/apple.tscn")
## Path assumed from the log/apple pickup scenes' naming convention -- update
## this if the actual sapling world-pickup scene lives somewhere else.
@export var sapling_scene: PackedScene = preload("res://inventory/scenes/pickup_items/sapling.tscn")
@export var spawn_radius: float = 50.0

@export_group("Sapling Drop Odds")
## Chance (out of 1.0) that a felled tree drops 2 saplings.
@export var sapling_double_drop_chance: float = 0.15
## Chance (out of 1.0) that a felled tree drops 1 sapling (rolled after the
## double-drop chance, so total sapling-drop odds are double + single).
@export var sapling_single_drop_chance: float = 0.30

@export_group("Early Stage Look")
## Tint applied to the sapling/young-tree sprites (stages 0-2) so their
## brighter source art matches the fully-grown tree's darker, desaturated
## palette. Stage 3 always renders at Color.WHITE (its native colors).
@export var early_stage_modulate: Color = Color(0.43, 0.44, 0.64)

@export var growth_stage: int = 3
## How many in-game days a freshly planted sapling spends at each stage
## before advancing to the next. Only relevant to trees planted at runtime
## (growth_stage starts below 3) -- pre-placed map trees stay at the
## default stage 3 forever since they never get a planted_day.
@export var days_per_growth_stage: int = 1

@export_group("Honey Tree")
## If true, this tree gives honey instead of apples when collected, and
## a swarm of bees bursts out to defend it. Only a couple of trees in the
## whole map should have this on.
@export var is_honey_tree: bool = false
@export var bee_scene: PackedScene = preload("res://characters/enemies/bee/bee.tscn")
@export var bee_count: int = 3
@export var bee_spawn_radius: float = 20.0

const APPLE_ITEM_PATH := "res://inventory/resources/inventory_items/apple.tres"
const HONEY_ITEM_PATH := "res://inventory/resources/inventory_items/honey.tres"
const PLAYER_INV_PATH := "res://inventory/resources/player_inv.tres"

const STAGE_0 = preload("uid://xm8w1p8mmjly")
const STAGE_1 = preload("uid://gaep3va887hq")
const STAGE_2 = preload("uid://bebirijxy1xsf")
const TREE = preload("uid://bgwep03ls5j3a")

## Sprite2D Y offsets, one per growth stage. The scene's baseline (-39) is
## calibrated for the full-grown TREE texture (90px tall); the sapling stage
## textures are much shorter, so using that same offset for them makes the
## sprite float well above the ground instead of sitting at the tree's actual
## root point. These were computed from each stage image's own visual
## content bounds so its base lands on the same ground line as the grown
## tree's base does.
const TREE_OFFSET_Y := -39.0
const STAGE_2_OFFSET_Y := -17.0
const STAGE_1_OFFSET_Y := -7.0
const STAGE_0_OFFSET_Y := -1.0

var has_died: bool = false
var _hovered: bool = false
var spawned_drops: Array = []
var current_day: int = 0
## The in-game day this tree was planted on. -1 for trees that were already
## in the map from the start (never grows, always stage 3). Set by
## TreesContainer.plant_tree() right after instantiate().
var planted_day: int = -1


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
	save_data["growth_stage"] = growth_stage
	save_data["planted_day"] = planted_day

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
	
	# Restore growth_stage (and catch it up to the current day) BEFORE the
	# sprite is built, so sprite_2d.hframes already matches this tree's real
	# stage by the time sprite_2d.frame is touched below. Previously this ran
	# *after* the frame restore, so a stage-0/1/2 tree (1 hframe) could still
	# be sitting at the previous call's hframes == 2 when frame got set --
	# and the no-save-data branch below always rolled randi_range(0, 1)
	# regardless of stage, a coin flip to crash on any freshly-planted or
	# freshly-loaded sapling (frame 1 is out of bounds when hframes == 1).
	if value.has("growth_stage"):
		growth_stage = value["growth_stage"]
		planted_day = value.get("planted_day", -1)
		_advance_growth(GameManager.day)  # catch up on any days that passed while this tree wasn't loaded
	
	update_sprite()
	
	if not value:
		sprite_2d.frame = randi_range(0, sprite_2d.hframes * sprite_2d.vframes - 1)
		return
		
	health_component.health = value["hp"]
	var pos_arr: Array = value["pos"]
	global_position = Vector2(pos_arr[0], pos_arr[1])
	sprite_2d.frame = clampi(value["frame"], 0, sprite_2d.hframes * sprite_2d.vframes - 1)
	
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
	_advance_growth(day)


## Recomputes growth_stage from how many days have passed since planting.
## No-op for pre-placed trees (planted_day == -1) and once fully grown.
func _advance_growth(day: int) -> void:
	if planted_day < 0 or growth_stage >= 3 or days_per_growth_stage <= 0:
		return

	var elapsed_days := day - planted_day
	var new_stage: int = clampi(elapsed_days / days_per_growth_stage, 0, 3)
	if new_stage != growth_stage:
		growth_stage = new_stage
		update_sprite()

func _on_died() -> void:
	if has_died:
		return
	has_died = true
	spawned_drops = []
	
	if is_honey_tree:
		# Let TreesContainer know a honey tree just went down so it can mark
		# a replacement among the remaining on-island trees.
		Events.honey_tree_died.emit(self)
	
	var log_count = randi_range(1, 3)
	
	var last_collection_day = GameManager.get_data_value(get_path(), "last_collection_day")
	var should_spawn_apples = last_collection_day != current_day
	var apple_count = randi_range(3,4) if should_spawn_apples else 0
	
	var sapling_roll = randf()
	var sapling_count = 0
	if sapling_roll < sapling_double_drop_chance:
		sapling_count = 2
	elif sapling_roll < sapling_double_drop_chance + sapling_single_drop_chance:
		sapling_count = 1
	
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

	for i in range(sapling_count):
		var angle = randf() * TAU
		var distance = randf_range(20.0, spawn_radius)
		var offset = Vector2(cos(angle), sin(angle)) * distance

		var sapling_position = global_position + offset
		var sapling_drop := {"id": "sapling_%d" % spawned_drops.size(), "item": "sapling", "pos": [sapling_position.x, sapling_position.y]}
		spawned_drops.append(sapling_drop)
		_spawn_drop(sapling_scene, sapling_drop)

	queue_free()
	DailyTaskManager.update_task_progress("3", 1)
	
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_try_collect()
		
func _try_collect() -> void:
	if Dialogic.current_timeline != null:
		return
	
	if growth_stage < 3:
		return
	
	var last_collection_day = GameManager.get_data_value(get_path(), "last_collection_day")
	
	if last_collection_day == current_day:
		print("🌳 Already collected from this tree today! Come back tomorrow.")
		Dialogic.VAR.set_variable("Item.already_collected", true)
		Dialogic.start("item_collect_timeline")
		return
	
	var item_path := HONEY_ITEM_PATH if is_honey_tree else APPLE_ITEM_PATH
	var _item: InvItem = load(item_path)
	var _inv: Inventory = load(PLAYER_INV_PATH)
	
	if _item == null or _inv == null:
		push_warning("tree: missing item or inventory resource.")
		Dialogic.VAR.set_variable("Item.already_collected", true)
		Dialogic.start("item_collect_timeline")
		return
	
	var collected_amount = randi_range(1, 2) if is_honey_tree else randi_range(2, 4)
	
	Dialogic.VAR.set_variable("Item.already_collected", false)
	Dialogic.VAR.set_variable("Item.name", _item.name)
	Dialogic.VAR.set_variable("Item.amount", collected_amount)
	
	GameManager.store_data_value(get_path(), "last_collection_day", current_day)
	_inv.insert(_item, collected_amount)
	
	if is_honey_tree:
		print("🍯 Collected %d honey! The hive is not going to let that slide." % collected_amount)
		_spawn_bees()
	else:
		print("🍎 Collected %d apples! Come back tomorrow for more." % collected_amount)
		DailyTaskManager.update_task_progress("1", collected_amount)
	
	Dialogic.start("item_collect_timeline")


## Bursts 3 (by default) bees out of the tree to defend the hive. They
## spawn close enough to the player -- who has to be standing right next to
## the tree to have clicked it -- that they pick up the chase on their own
## via the normal Wander -> Follow detection, no forced state needed. Each
## one is told to treat the tree itself as "home" so they all converge back
## on it once they give up the chase (see Bee.despawn_delay).
func _spawn_bees() -> void:
	if bee_scene == null:
		return

	for i in range(bee_count):
		var bee: Bee = bee_scene.instantiate()
		var angle := randf() * TAU
		var distance := randf_range(4.0, bee_spawn_radius)
		bee.global_position = global_position + Vector2(cos(angle), sin(angle)) * distance
		bee.home_position = global_position
		get_parent().call_deferred("add_child", bee)
	
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
			"sapling":
				item_scene = sapling_scene
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


func update_sprite():
	# hframes MUST be set before texture: AutoShadow2D (on the Shadow sibling
	# node) listens to Sprite2D.texture_changed and reads sprite_2d.hframes
	# synchronously the instant that signal fires to size itself. Setting
	# texture first (old order) meant the signal fired while hframes still
	# held the *previous* stage's value, so on the growth_stage == 3 tree
	# specifically, hframes was still 1 at that instant -- the shadow sized
	# itself off the whole 140x90 two-frame sheet instead of one 70x90
	# frame, i.e. exactly the "shadow uses the entire sprite frame" bug.
	# Shadow position/scale are otherwise left alone entirely -- AutoShadow2D
	# re-anchors itself to (0, 0) and re-sizes itself off the sprite on its
	# own, so this script only ever needs to move the sprite (and, if you
	# add stage-specific hitboxes later, the collision shapes) per stage.
	if growth_stage == 3:
		sprite_2d.hframes = 2
		sprite_2d.texture = TREE
		sprite_2d.position.y = TREE_OFFSET_Y
	elif growth_stage == 2:
		sprite_2d.hframes = 1
		sprite_2d.texture = STAGE_2
		sprite_2d.position.y = STAGE_2_OFFSET_Y
	elif growth_stage == 1:
		sprite_2d.hframes = 1
		sprite_2d.texture = STAGE_1
		sprite_2d.position.y = STAGE_1_OFFSET_Y
	elif growth_stage == 0:
		sprite_2d.hframes = 1
		sprite_2d.texture = STAGE_0
		sprite_2d.position.y = STAGE_0_OFFSET_Y

	# A sapling/young tree has nothing to collect yet -- turn off its
	# clickable area entirely (this also suppresses the mouse-enter/exit
	# hover highlight, since both ride on input_pickable) rather than just
	# rejecting the click in _try_collect(), so it doesn't even look
	# interactive until it's grown.
	$interaction_area.input_pickable = growth_stage == 3
	if growth_stage < 3 and _hovered:
		_on_mouse_exited()

	# Stages 0-2 use brighter source art than the grown tree; tint them to
	# match instead of having color jump the moment growth_stage hits 3.
	# Hover brightening (_on_mouse_entered/_on_mouse_exited) only ever runs
	# while growth_stage == 3, since input_pickable is off otherwise, so it
	# can't clobber this.
	modulate = Color.WHITE if growth_stage == 3 else early_stage_modulate
