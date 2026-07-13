extends Resource

class_name InvItem

@export var id: String
@export var name: String = ""
@export var texture: Texture2D
@export var max_stack: int
@export var description: String = ""

@export var item_type: ItemType

enum ItemType {
	CONSUMABLE,
	WEAPON,
	MATERIAL,
	ARTIFACT
}
