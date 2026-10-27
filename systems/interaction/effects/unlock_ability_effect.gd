class_name UnlockAbilityEffect
extends InteractionEffect

@export_enum("dash", "double_jump", "wall_jump") var ability_id: String = "dash"


func is_valid() -> bool:
	return GameState.ABILITY_IDS.has(ability_id)


func execute(_actor: Node2D, _source: Node2D) -> bool:
	if not is_valid() or SaveManager.is_loading():
		return false
	GameState.unlock_ability(ability_id)
	return GameState.has_ability(ability_id)
