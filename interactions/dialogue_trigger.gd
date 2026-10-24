
extends Area2D

@export_group("Diálogo")
@export var dialogue: DialogueData

@export_group("Persistência")
@export var one_shot: bool = true
@export var persistent_id: String = ""

var already_triggered: bool = false


func _ready() -> void:
	if one_shot and not persistent_id.is_empty():
		already_triggered = GameState.is_event_complete(
			persistent_id
		)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return

	if one_shot and already_triggered:
		return

	if DialogueManager.is_active:
		return

	var started := DialogueManager.start_dialogue(dialogue)

	if not started:
		return

	if one_shot:
		already_triggered = true

		if not persistent_id.is_empty():
			GameState.complete_event(persistent_id)
