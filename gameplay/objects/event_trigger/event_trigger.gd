class_name GameplayEventTrigger
extends Interactable

enum ActivationMode { INTERACTION, AREA_ENTRY }
@export var activation_mode: ActivationMode = ActivationMode.INTERACTION
@export var condition: InteractionRequirement
@export var event_id: String = ""
@export var persistent_completion: bool = false


func _ready() -> void:
	super._ready()
	body_entered.connect(_on_body_entered)
	GameState.progress_changed.connect(apply_persistent_state)
	apply_persistent_state()


func uses_persistence() -> bool:
	return persistent_completion


func get_persistent_id() -> String:
	return event_id


func apply_persistent_state() -> void:
	if is_live(self) and persistent_completion:
		has_interacted = GameState.is_event_complete(event_id)
		invalidate_requirements()


func can_select(actor: Node2D) -> bool:
	return activation_mode == ActivationMode.INTERACTION and super.can_select(actor)


func get_block_reason(actor: Node2D) -> String:
	var reason := super.get_block_reason(actor)
	if not reason.is_empty():
		return reason
	if condition != null and (not condition.is_configured() or not condition.is_met(actor)):
		return condition.failure_message if not condition.failure_message.is_empty() else "Condição do evento não atendida."
	return ""


func is_available(actor: Node2D) -> bool:
	return (
		super.is_available(actor) and not DialogueManager.blocks_interaction()
		and not get_tree().paused
		and (not persistent_completion or GameState.is_valid_id(event_id))
		and not (persistent_completion and has_interacted)
		and not effects.is_empty()
	)


func _on_interact(_actor: Node2D) -> void:
	if persistent_completion:
		GameState.complete_event(event_id)


func _on_body_entered(body: Node2D) -> void:
	if activation_mode == ActivationMode.AREA_ENTRY and body.is_in_group("Player"):
		interact(body)
