extends Node

@export var night_hour = 18
@export var day_hour = 5

@onready var day_jingle: AudioStreamPlayer = $DayJingle
@onready var night_jingle: AudioStreamPlayer = $NightJingle
@onready var day_soundscape: AudioStreamPlayer = $DaySoundscape
@onready var night_soundscape: AudioStreamPlayer = $NightSoundscape
@onready var outside_bus_index = AudioServer.get_bus_index("Outside")

func _ready() -> void:
	Events.time_tick.connect(set_daytime)
	Events.map_changed.connect(_on_map_changed)


func set_daytime(_day: int, hour: int, minute: int) -> void:
	if hour <= day_hour or hour >= night_hour:
		# check if we need to play night soundscape
		if not night_soundscape.playing:
			night_soundscape.play()
			day_soundscape.stop()
	else:
		# check if we need to play day soundscape
		if not day_soundscape.playing:
			day_soundscape.play()
			night_soundscape.stop()
	if hour == day_hour and minute == 0:
		day_jingle.play()
		day_soundscape.play()
		night_soundscape.stop()
	if hour == night_hour and minute == 0:
		night_jingle.play()
		day_soundscape.stop()
		night_soundscape.play()


func _on_map_changed(map: Events.Map) -> void:
	match map:
		Events.Map.HOUSE:
			AudioServer.set_bus_mute(outside_bus_index, true)
			
			day_jingle.stop()
			night_jingle.stop()
			
		Events.Map.OUTSIDE:
			AudioServer.set_bus_mute(outside_bus_index, false)
