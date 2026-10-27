class_name InteractionEffect
extends Resource

# Preflight sem mutação. Efeitos são síncronos; transições devem ser adiadas.
func is_valid() -> bool:
	return true


func validate_context(_interactor: Node2D, _source: Node2D) -> bool:
	return is_valid()


func execute(_interactor: Node2D, _source: Node2D) -> bool:
	return true


static func execute_sequence(actions: Array[InteractionEffect], actor: Node2D, source: Node2D) -> bool:
	if SaveManager.is_loading() or not GameplayContext.is_live(actor) or not GameplayContext.is_live(source):
		return false
	var sequence: Array[InteractionEffect] = actions.duplicate()
	for action in sequence:
		if action == null or not action.validate_context(actor, source):
			push_warning("Sequência de ações com configuração ou contexto inválido.")
			return false
	for index in range(sequence.size()):
		var success := sequence[index].execute(actor, source)
		if not success or not GameplayContext.is_live(actor) or not GameplayContext.is_live(source) or SaveManager.is_loading():
			push_warning("Sequência interrompida na ação %d; ações anteriores podem ter sido aplicadas." % index)
			return false
	return true
