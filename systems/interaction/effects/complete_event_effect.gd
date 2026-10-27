class_name CompleteEventEffect
extends InteractionEffect

@export var event_id: String = ""


func is_valid() -> bool:
	return GameState.is_valid_id(event_id)


func execute(_interactor: Node2D, _source: Node2D) -> bool:
	if not is_valid() or SaveManager.is_loading():
		return false
	GameState.complete_event(event_id)
	return true
