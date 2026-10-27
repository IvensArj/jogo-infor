class_name InteractionRequirement
extends Resource

@export_multiline var failure_message: String = ""


func is_met(_interactor: Node2D) -> bool:
	return true
