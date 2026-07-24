class_name Player
extends CharacterBody2D

const INV: Inventory = preload("uid://bn2stjinnsiyq")
const ARTIFACT_INV: Inventory = preload("uid://douhrv0500seb")
const WEAPON_INV: Inventory = preload("uid://4c04xqhej0fr")

const PLAYER_INV_DEFAULT = preload("uid://ck24isuiv3du3")

const PLANT_DISTANCE := 24.0
const PLANT_CHECK_RADIUS := 12.0
## Same layers the player's own CollisionShape2D already collides with
## (see player.tscn), so "is this spot blocked" matches whatever would
## actually stop the player from walking there -- trees, stones, the
## cabin, enemies, etc.
const PLANT_BLOCK_MASK := 244

@export var speed: float = 100.0

var walk_distance_accum: float = 0.0
var facing_direction: Vector2 = Vector2.DOWN

@onready var hurt: AudioStreamPlayer2D = $Hurt
@onready var health_component: HealthComponent = $HealthComponent
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var state_machine: StateMachine = $StateMachine
@onready var shadow: AutoShadow2D = $Shadow
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	print(health_component.health)
	ARTIFACT_INV.update.connect(_on_artifact_inv_updated)
	_on_artifact_inv_updated()  # apply buffs from whatever artifacts are already owned, and sync health_component

	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_death)
	
	# health_component.health is the value actually used for taking damage,
	# and _on_health_changed() writes it straight back into
	# GameManager.player_health on every hit — so if it's left stale after a
	# load, the very next hit silently overwrites the health we just
	# restored with whatever health_component had before the load happened.
	SaveManager.game_loaded.connect(_on_game_loaded)
	
	animation_tree.set_active(true)
	animation_tree.set("parameters/Idle/blend_position", facing_direction)

func _on_game_loaded() -> void:
	health_component.max_health = GameManager.MAX_PLAYER_HEALTH
	health_component.health = GameManager.player_health

func _on_artifact_inv_updated() -> void:
	# Sum buffs across every artifact currently owned. Only one of each
	# artifact can ever exist and the artifact slot can't be emptied once
	# filled, so this never double-counts or needs to handle removal —
	# but it stays generic so it scales cleanly when more artifacts exist.
	var total_health_buff: float = 0.0
	var total_attack_buff: float = 0.0
	for slot in ARTIFACT_INV.slots:
		if slot.item and slot.item is ArtifactItem:
			total_health_buff += slot.item.health_buff
			total_attack_buff += slot.item.attack_buff

	GameManager.apply_artifact_buffs(total_health_buff, total_attack_buff)

	health_component.max_health = GameManager.MAX_PLAYER_HEALTH
	health_component.health = GameManager.player_health
	Events.player_health_changed.emit(GameManager.player_health)


func _on_health_changed(current_health: float, attack: Attack) -> void:
	GameManager.player_health = current_health
	Events.player_health_changed.emit(current_health)
	
	if attack:
		hurt.play()


func _on_death() -> void:
	print("dead")
	state_machine._transition_to_next_state(PlayerState.DEAD)
	Events.game_over.emit(false)


func collect(item):
	INV.insert(item)


func heal(amount: int) -> void:
	var health = GameManager.player_health
	var max_health = GameManager.MAX_PLAYER_HEALTH
	health = min(health + amount, max_health)
	GameManager.player_health = health
	health_component.health = health
	Events.player_health_changed.emit(health)
	print([amount, health])


func respawn() -> void:
	hurtbox_component.set_deferred("monitorable", true)
	health_component.max_health = GameManager.MAX_PLAYER_HEALTH
	health_component.revive()
	
	state_machine._transition_to_next_state(PlayerState.IDLE)
	set_physics_process(true)
	shadow.show()


func reset_inventory_for_new_game() -> void:
	INV.copy_from(PLAYER_INV_DEFAULT)
	ARTIFACT_INV.clear()
	WEAPON_INV.clear()


## Called by ConsumableItem.use() when a sapling is used. Checks the spot
## directly in front of the player and, if it's clear, plants a stage-0
## tree there. Returns whether the sapling should actually be consumed.
func try_plant_sapling() -> bool:
	if GameManager.map != Events.Map.OUTSIDE:
		print("🌱 Can't plant a sapling here.")
		return false

	var trees_container := _find_trees_container()
	if trees_container == null:
		push_warning("Player: couldn't find the outside map's Trees container to plant into.")
		return false

	var plant_position := global_position + facing_direction * PLANT_DISTANCE

	var shape := CircleShape2D.new()
	shape.radius = PLANT_CHECK_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, plant_position)
	query.collision_mask = PLANT_BLOCK_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var space_state := get_world_2d().direct_space_state
	if not space_state.intersect_shape(query, 1).is_empty():
		print("🌱 Something's in the way -- can't plant a sapling there.")
		return false

	trees_container.plant_tree(plant_position)
	return true


## The currently-loaded map lives as the sole child of Main's WorldContainer
## (see main.gd) -- this digs into it to find the "Trees" node that
## trees_container.gd is attached to, without hardcoding the map's own
## root node name.
func _find_trees_container() -> Node:
	var world_container := get_tree().current_scene.get_node_or_null("WorldContainer")
	if world_container == null or world_container.get_child_count() == 0:
		return null
	return world_container.get_child(0).find_child("Trees", true, false)
