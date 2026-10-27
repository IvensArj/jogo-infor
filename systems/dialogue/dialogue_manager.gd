
extends Node

signal dialogue_started
signal line_changed(line: DialogueLine)
signal dialogue_finished
signal inspection_started
signal inspection_finished

var is_active: bool = false

var current_dialogue: DialogueData
var current_index: int = 0
var started_frame: int = -1
var finished_frame: int = -1
var _source: WeakRef
var inspection_active: bool = false
var _inspection_source: WeakRef
var _inspection_ui: WeakRef


func start_dialogue(data: DialogueData, source: Node = null) -> bool:
	# Impede diálogos simultâneos.
	if is_active or inspection_active or get_tree().paused or SaveManager.is_loading():
		return false

	started_frame = Engine.get_process_frames()

	if data == null or data.lines.is_empty():
		push_warning("Diálogo vazio ou inexistente.")
		return false
	if source != null and not Interactable.is_live(source):
		return false

	_source = weakref(source) if source != null else null
	if source != null:
		source.tree_exiting.connect(end_dialogue)

	current_dialogue = data
	current_index = 0
	is_active = true

	dialogue_started.emit()
	_show_current_line()

	return true


func get_dialogue_source() -> Node:
	return _source.get_ref() as Node if _source != null else null


func blocks_interaction() -> bool:
	# A entrada que encerra a conversa não pode iniciar outra no mesmo quadro.
	return is_active or inspection_active or finished_frame == Engine.get_process_frames()


# Arbitragem mínima das interfaces bloqueantes, sem um novo Autoload.
func begin_inspection(source: Node, ui: Node) -> bool:
	if blocks_interaction() or get_tree().paused or SaveManager.is_loading():
		return false
	if not Interactable.is_live(source) or not Interactable.is_live(ui):
		return false
	_inspection_source = weakref(source)
	_inspection_ui = weakref(ui)
	source.tree_exiting.connect(end_inspection)
	inspection_active = true
	inspection_started.emit()
	return true


func end_inspection() -> void:
	if not inspection_active:
		return
	var source: Node = _inspection_source.get_ref() as Node
	if is_instance_valid(source) and source.tree_exiting.is_connected(end_inspection):
		source.tree_exiting.disconnect(end_inspection)
	_inspection_source = null
	_inspection_ui = null
	inspection_active = false
	finished_frame = Engine.get_process_frames()
	inspection_finished.emit()


func _process(_delta: float) -> void:
	if inspection_active:
		var source := _inspection_source.get_ref() as Node
		if not Interactable.is_live(source) or not Interactable.is_live(_inspection_ui.get_ref()):
			end_inspection()
		elif source is Interactable and not source.enabled:
			end_inspection()
	if not is_active or _source == null:
		return
	var source := get_dialogue_source()
	if not Interactable.is_live(source):
		end_dialogue()
	elif source.has_method("is_dialogue_source_valid") and not source.is_dialogue_source_valid():
		end_dialogue()


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

	var source := get_dialogue_source()
	if is_instance_valid(source) and source.tree_exiting.is_connected(end_dialogue):
		source.tree_exiting.disconnect(end_dialogue)
	_source = null
	is_active = false
	finished_frame = Engine.get_process_frames()
	current_dialogue = null
	current_index = 0

	dialogue_finished.emit()
