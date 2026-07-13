extends HSlider

@export var bus_names: Array[String] = ["Music", "Outside"]

func _ready() -> void:
	min_value = 0
	max_value = 100
	step = 1
	# use the first bus as the reference for the initial slider position
	var bus_idx := AudioServer.get_bus_index(bus_names[0])
	value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx)) * 100.0
	value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: float) -> void:
	var linear := new_value / 100.0
	var db := linear_to_db(max(linear, 0.0001))
	# avoid -inf db at 0
	for bus_name in bus_names:
		var bus_idx := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_volume_db(bus_idx, db)
