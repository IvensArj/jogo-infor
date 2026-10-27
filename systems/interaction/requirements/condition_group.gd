class_name ConditionGroup
extends InteractionRequirement

enum Mode { ALL, ANY }
@export var mode: Mode = Mode.ALL
@export var conditions: Array[InteractionRequirement] = []


func is_configured() -> bool:
	return _validate_path([])


func _validate_path(path: Array[int]) -> bool:
	var id := get_instance_id()
	if path.has(id):
		push_warning("Condição circular: " + resource_path + " (" + str(id) + ").")
		return false
	var next_path: Array[int] = path.duplicate()
	next_path.append(id)
	for condition in conditions:
		if condition == null:
			push_warning("Grupo de condições contém um recurso ausente.")
			return false
		if condition is ConditionGroup:
			if not condition._validate_path(next_path):
				return false
		elif not condition.is_configured():
			push_warning("Condição com configuração inválida: " + str(condition))
			return false
	return true


func is_met(actor: Node2D) -> bool:
	# Valida toda a árvore antes de avaliar, inclusive ramos de um ANY.
	if not is_configured():
		return false
	for condition in conditions:
		var result := condition.is_met(actor)
		if mode == Mode.ALL and not result:
			return false
		if mode == Mode.ANY and result:
			return true
	return mode == Mode.ALL
