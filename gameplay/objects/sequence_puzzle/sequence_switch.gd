class_name SequenceSwitch
extends Interactable

@export var switch_id: String = ""
@export var puzzle: SequencePuzzle


func can_interact(actor: Node2D) -> bool:
	return (
		super.can_interact(actor) and not DialogueManager.blocks_interaction()
		and GameState.is_valid_id(switch_id) and is_live(puzzle)
		and puzzle.is_configured() and not puzzle.is_completed
	)


func _complete_interaction(actor: Node2D) -> bool:
	return puzzle.submit_switch(switch_id, actor)
