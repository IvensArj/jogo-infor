
extends Interactable

@export var dialogue: DialogueData
@export_range(1.0, 500.0, 1.0) var dialogue_max_distance: float = 110.0
@export_range(0.0, 32.0, 1.0) var dialogue_distance_tolerance: float = 8.0

var _dialogue_actor: WeakRef


func can_interact(actor: Node2D) -> bool:
	if not super.can_interact(actor) or DialogueManager.blocks_interaction():
		return false
	if dialogue == null or dialogue.lines.is_empty():
		return false
	var interactor := actor.get_node_or_null("Interactor") as Interactor
	return (
		interactor != null and interactor.interaction_enabled
		and interactor.overlaps_area(self)
		and global_position.distance_to(actor.global_position) <= dialogue_max_distance
	)


func _on_interact(actor: Node2D) -> void:
	_dialogue_actor = weakref(actor)
	DialogueManager.start_dialogue(dialogue, self)


func is_dialogue_source_valid() -> bool:
	var actor := _dialogue_actor.get_ref() as Node2D if _dialogue_actor != null else null
	return (
		Interactable.is_live(actor) and enabled
		and global_position.distance_to(actor.global_position)
		<= dialogue_max_distance + dialogue_distance_tolerance
	)
