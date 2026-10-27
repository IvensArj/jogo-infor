extends "res://systems/save/save_manager.gd"

var fail_target: String = ""
var remove_target_before_failure := false
var fail_write: bool = false
var fail_scene: bool = false
var fail_root_deferred: bool = false
var mutate_before_failure: bool = false


func _replace_file(from: String, to: String) -> Error:
	if to == fail_target:
		if remove_target_before_failure and FileAccess.file_exists(to):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(to))
			if error != OK:
				return error
		return ERR_CANT_CREATE
	return super._replace_file(from, to)


func _write_validated(path: String, data: Dictionary) -> bool:
	if fail_write:
		return false
	return super._write_validated(path, data)


func _instantiate_scene(path: String) -> Node:
	if fail_scene:
		if mutate_before_failure:
			GameState.set_flag("leaked_init", true)
		return null
	var candidate := super._instantiate_scene(path)
	if fail_root_deferred and candidate != null:
		candidate.ready.connect(func(): candidate.call_deferred("free"), CONNECT_ONE_SHOT)
	return candidate
