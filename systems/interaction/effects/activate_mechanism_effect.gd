class_name ActivateMechanismEffect
extends InteractionEffect

# Caminho relativo à origem da ação (gatilho, puzzle ou Interactable).
@export_node_path("Area2D") var target_path: NodePath


func is_valid() -> bool:
	return not target_path.is_empty()


func validate_context(_actor: Node2D, source: Node2D) -> bool:
	if not is_valid() or not Interactable.is_live(source):
		return false
	var target := source.get_node_or_null(target_path) as FlagInteractable
	return Interactable.is_live(target) and target.enabled and GameState.is_valid_id(target.get_persistent_id())


func execute(actor: Node2D, source: Node2D) -> bool:
	if not validate_context(actor, source) or SaveManager.is_loading():
		return false
	var target := source.get_node_or_null(target_path) as FlagInteractable
	return target.activate()
