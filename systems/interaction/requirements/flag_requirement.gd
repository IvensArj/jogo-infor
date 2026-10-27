class_name FlagRequirement
extends InteractionRequirement

@export var flag_id: String = ""
@export var expected_value: bool = true


func is_met(_interactor: Node2D) -> bool:
	return GameState.is_valid_id(flag_id) and GameState.get_flag(flag_id) == expected_value
