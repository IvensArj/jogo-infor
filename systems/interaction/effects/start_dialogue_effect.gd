class_name StartDialogueEffect
extends InteractionEffect

@export var dialogue: DialogueData


func is_valid() -> bool:
	if dialogue == null or dialogue.lines.is_empty():
		return false
	for line in dialogue.lines:
		if line == null:
			return false
	return true


func validate_context(_actor: Node2D, _source: Node2D) -> bool:
	return is_valid() and not DialogueManager.blocks_interaction() and not SaveManager.is_loading()


func execute(actor: Node2D, source: Node2D) -> bool:
	return validate_context(actor, source) and DialogueManager.start_dialogue(dialogue)
