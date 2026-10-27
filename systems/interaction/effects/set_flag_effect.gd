class_name SetFlagEffect
extends InteractionEffect

@export var flag_id: String = ""
@export var value: bool = true


func is_valid() -> bool:
	return GameState.is_valid_id(flag_id)


func execute(_interactor: Node2D, _source: Node2D) -> bool:
	if not is_valid() or SaveManager.is_loading():
		return false
	GameState.set_flag(flag_id, value)
	return true
