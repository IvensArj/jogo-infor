
class_name Interactable
extends Area2D

signal interacted(interactor: Node2D)
signal interaction_denied(interactor: Node2D, reason: String)
signal availability_changed

@export_group("Interação")
@export var interaction_name: String = "Objeto"
@export var action_text: String = "Interagir"
@export var enabled: bool = true
@export var one_shot: bool = false
@export var show_when_locked: bool = true

@export_group("Condições")
@export var requirements: Array[InteractionRequirement] = []

@export_group("Consequências")
@export var effects: Array[InteractionEffect] = []

@export_group("Seleção")
@export_range(0, 100, 1) var selection_priority: int = 0

@export_group("Indicador")
@export var prompt_offset: Vector2 = Vector2(0, -40)

@onready var prompt_anchor: Marker2D = get_node_or_null(
	"PromptAnchor"
) as Marker2D


var has_interacted: bool = false
var _executing: bool = false
var _requirements_dirty: bool = true
var _cached_actor_id: int = 0
var _blocked_reason: String = ""


func _ready() -> void:
	if not GameState.progress_changed.is_connected(invalidate_requirements):
		GameState.progress_changed.connect(invalidate_requirements)


func invalidate_requirements() -> void:
	_requirements_dirty = true
	if is_live(self):
		availability_changed.emit()


static func is_live(node: Variant) -> bool:
	return GameplayContext.is_live(node)


func is_available(interactor: Node2D) -> bool:
	return (
		enabled and not (one_shot and has_interacted)
		and is_live(self) and is_live(interactor)
	)


func get_block_reason(interactor: Node2D) -> String:
	if not is_instance_valid(interactor):
		return "Personagem indisponível."
	if _requirements_dirty or _cached_actor_id != interactor.get_instance_id():
		_requirements_dirty = false
		_cached_actor_id = interactor.get_instance_id()
		_blocked_reason = ""
		for requirement in requirements:
			if requirement == null:
				_blocked_reason = "Condição não configurada."
				break
			if not requirement.is_met(interactor):
				_blocked_reason = requirement.failure_message
				if _blocked_reason.is_empty():
					_blocked_reason = "Requisitos não atendidos."
				break
	return _blocked_reason


func can_select(interactor: Node2D) -> bool:
	return is_available(interactor) and (show_when_locked or can_interact(interactor))


func get_prompt_text(interactor: Node2D) -> String:
	var reason: String = get_block_reason(interactor)
	return get_interaction_text() if reason.is_empty() else reason


func can_interact(interactor: Node2D) -> bool:
	return is_available(interactor) and get_block_reason(interactor).is_empty()



func get_prompt_position() -> Vector2:
	if is_instance_valid(prompt_anchor):
		return prompt_anchor.global_position

	return global_position + prompt_offset


func interact(interactor: Node2D) -> bool:
	if _executing or SaveManager.is_loading() or not is_available(interactor):
		return false
	# Revalidação real na tentativa; consultas de seleção usam o cache.
	_requirements_dirty = true
	if not can_interact(interactor):
		interaction_denied.emit(interactor, get_block_reason(interactor))
		return false
	var sequence: Array[InteractionEffect] = effects.duplicate()
	for effect in sequence:
		if effect == null or not effect.validate_context(interactor, self):
			interaction_denied.emit(interactor, "Consequência não configurada corretamente.")
			return false
	_executing = true
	var success := InteractionEffect.execute_sequence(sequence, interactor, self)
	if not is_instance_valid(self):
		return false
	if not success:
		_executing = false
		return false
	var previously_interacted := has_interacted
	has_interacted = true
	var completed_successfully := _complete_interaction(interactor)
	if not is_instance_valid(self):
		return completed_successfully
	if not completed_successfully:
		has_interacted = previously_interacted
		_executing = false
		if is_live(self) and is_live(interactor):
			interaction_denied.emit(interactor, "Não foi possível concluir a interação.")
		return false
	if is_live(self) and is_live(interactor):
		interacted.emit(interactor)
	if is_instance_valid(self):
		_executing = false
		invalidate_requirements()
	return true


func _on_interact(_interactor: Node2D) -> void:
	pass


# Mantém o hook legado; novos componentes podem propagar falhas de conclusão.
func _complete_interaction(interactor: Node2D) -> bool:
	_on_interact(interactor)
	return true


func get_interaction_text() -> String:
	return action_text
