
extends Node

signal dialogue_started
signal line_changed(line: DialogueLine)
signal dialogue_finished

var is_active: bool = false

var current_dialogue: DialogueData
var current_index: int = 0
var started_frame: int = -1


func start_dialogue(data: DialogueData) -> bool:
	# Impede diálogos simultâneos.
	if is_active:
		return false
	
	started_frame = Engine.get_process_frames()

	if data == null or data.lines.is_empty():
		push_warning("Diálogo vazio ou inexistente.")
		return false

	current_dialogue = data
	current_index = 0
	is_active = true

	dialogue_started.emit()
	_show_current_line()

	return true


func _show_current_line() -> void:
	if not is_active:
		return

	if current_index >= current_dialogue.lines.size():
		end_dialogue()
		return

	var line := current_dialogue.lines[current_index]

	if line == null:
		push_warning("Linha de diálogo inválida.")
		end_dialogue()
		return

	line_changed.emit(line)


func next_line() -> void:
	if not is_active:
		return

	current_index += 1
	_show_current_line()


func end_dialogue() -> void:
	if not is_active:
		return

	is_active = false
	current_dialogue = null
	current_index = 0

	dialogue_finished.emit()
