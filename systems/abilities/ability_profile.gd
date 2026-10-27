class_name AbilityProfile
extends Resource

@export var dash: bool = true
@export var double_jump: bool = true
@export var wall_jump: bool = true


func allows(ability_id: String) -> bool:
	match ability_id:
		"dash": return dash
		"double_jump": return double_jump
		"wall_jump": return wall_jump
	return false
