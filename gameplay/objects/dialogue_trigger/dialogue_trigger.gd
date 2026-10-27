extends Area2D

@export_group("Diálogo")
@export var dialogue: DialogueData
@export_group("Persistência")
@export var one_shot := true
@export var persistent_id: String = ""
var already_triggered := false


func uses_persistence() -> bool:
	return one_shot


func get_persistent_id() -> String:
	return persistent_id


func _ready() -> void:
	GameState.progress_changed.connect(apply_persistent_state)
	body_entered.connect(_on_body_entered)
	apply_persistent_state()


func apply_persistent_state() -> void:
	# Este método também recebe progress_changed diretamente.
	if not is_inside_tree():
		return
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return
		ancestor = ancestor.get_parent()
	already_triggered = one_shot and GameState.is_event_complete(persistent_id)


func _on_body_entered(body: Node2D) -> void:
	if SaveManager.is_loading():
		return
	if not body.is_in_group("Player") or (one_shot and already_triggered):
		return
	if one_shot and not GameState.is_valid_id(persistent_id):
		return
	if DialogueManager.is_active or not DialogueManager.start_dialogue(dialogue):
		return
	if one_shot:
		GameState.complete_event(persistent_id)
