class_name Player
extends CharacterBody2D

const INV: Inventory = preload("uid://bn2stjinnsiyq")
const ARTIFACT_INV: Inventory = preload("uid://douhrv0500seb")
const WEAPON_INV: Inventory = preload("uid://4c04xqhej0fr")

const PLAYER_INV_DEFAULT = preload("uid://ck24isuiv3du3")

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
