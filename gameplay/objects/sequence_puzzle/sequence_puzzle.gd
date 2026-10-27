class_name SequencePuzzle
extends Node2D

signal attempt_changed(step: int)
signal correct_input(switch_id: String)
signal incorrect_input(switch_id: String)
signal completed
signal completion_failed

@export var ordered_switch_ids: Array[String] = []
@export var success_actions: Array[InteractionEffect] = []
@export var permanent: bool = true
@export var persistent_id: String = ""

var current_step: int = 0
var is_completed: bool = false
var _completing: bool = false


func _ready() -> void:
	GameState.progress_changed.connect(apply_persistent_state)
	apply_persistent_state()


func uses_persistence() -> bool:
	return permanent


func get_persistent_id() -> String:
	return persistent_id


func apply_persistent_state() -> void:
	if not Interactable.is_live(self) or _completing:
		return
	if permanent:
		var restored := GameState.is_event_complete(persistent_id)
		if restored != is_completed:
			current_step = 0
		is_completed = restored


func reset_attempt() -> void:
	current_step = 0
	attempt_changed.emit(current_step)


func is_configured() -> bool:
	if ordered_switch_ids.is_empty() or (permanent and not GameState.is_valid_id(persistent_id)):
		return false
	for id in ordered_switch_ids:
		if not GameState.is_valid_id(id):
			return false
	return true


func submit_switch(switch_id: String, actor: Node2D) -> bool:
	if _completing or is_completed or not is_configured() or not GameState.is_valid_id(switch_id):
		return false
	if SaveManager.is_loading() or DialogueManager.blocks_interaction() or get_tree().paused:
		return false
	if not Interactable.is_live(self) or not Interactable.is_live(actor):
		return false
	if ordered_switch_ids[current_step] != switch_id:
		reset_attempt()
		incorrect_input.emit(switch_id)
		return false
	current_step += 1
	correct_input.emit(switch_id)
	attempt_changed.emit(current_step)
	if not Interactable.is_live(self) or not Interactable.is_live(actor):
		return false
	if current_step < ordered_switch_ids.size():
		return true
	_completing = true
	var success := InteractionEffect.execute_sequence(success_actions, actor, self)
	if not is_instance_valid(self):
		return false
	_completing = false
	if not success:
		reset_attempt()
		completion_failed.emit()
		return false
	is_completed = true
	if permanent:
		GameState.complete_event(persistent_id)
	completed.emit()
	return true
