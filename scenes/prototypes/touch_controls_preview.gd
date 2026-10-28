extends Node


func _ready() -> void:
	if OS.is_debug_build():
		InputDeviceManager.set_touch_test_mode(true)
	# O laboratório isola saves e contém os desbloqueios de habilidades.
	get_tree().change_scene_to_file.call_deferred("res://scenes/levels/systems_test_entry.tscn")
