class_name EventRequirement
extends InteractionRequirement

@export var event_id: String = ""


func is_met(_interactor: Node2D) -> bool:
	return GameState.is_valid_id(event_id) and GameState.is_event_complete(event_id)
