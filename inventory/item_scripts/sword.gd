extends Area2D

@export var item: InvItem

var player = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if item == null:
		item = load("res://inventory/resources/inventory_items/sword.tres")

# Called every frame. 'delta' is the elapsed time since he previous frame.
func _process(_delta: float) -> void:
	pass
	
func setup(inv_item: InvItem, _amount: int) -> void:
	item = inv_item

func _on_body_entered(body: Node2D) -> void:
	if item == null:
		push_error("Pickup item not set on: ", name)
		return
	player = body
	player.collect(item)
	queue_free()
