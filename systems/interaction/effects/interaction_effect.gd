class_name InteractionEffect
extends Resource

# Preflight sem mutação. Efeitos são síncronos; transições devem ser adiadas.
func is_valid() -> bool:
	return true


func execute(_interactor: Node2D, _source: Node2D) -> bool:
	return true
