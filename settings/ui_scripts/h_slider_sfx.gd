extends HSlider

@export var bus_name: String = "SFX"

func _ready() -> void:
	min_value = 0
	max_value = 100
	step = 1
	var bus_idx := AudioServer.get_bus_index(bus_name)
	value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx)) * 100.0
	value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	var linear := new_value / 100.0
	# avoid -inf db at 0
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(linear, 0.0001)))
