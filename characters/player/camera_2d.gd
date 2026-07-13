extends Camera2D


func _ready() -> void:
	Events.map_changed.connect(_on_map_changed)

func _on_map_changed(map: Events.Map) -> void:
	match map:
		Events.Map.OUTSIDE:
			limit_enabled = true
			limit_left = 3
			limit_top = 3
			limit_right = 1405
			limit_bottom = 1340
		Events.Map.HOUSE:
			limit_enabled = false
