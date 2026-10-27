class_name ItemRequirement
extends InteractionRequirement

@export var item_id: String = ""


func is_met(_interactor: Node2D) -> bool:
	return GameState.is_valid_id(item_id) and GameState.has_item(item_id)
