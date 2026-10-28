extends Node


func _input(event: InputEvent) -> void:
	# Último filho: executa antes dos TouchScreenButtons na ordem de _input.
	# A captura é por contato, com cancelamento antes de chegar aos botões.
	get_parent().guard_input(event)
