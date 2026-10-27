class_name AbilityRequirement
extends InteractionRequirement

@export_enum("dash", "double_jump", "wall_jump") var ability_id: String = "dash"


func is_configured() -> bool:
	return GameState.ABILITY_IDS.has(ability_id)


func is_met(_actor: Node2D) -> bool:
	return is_configured() and GameState.has_ability(ability_id)
