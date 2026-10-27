
extends Node2D

@export var dialogue: DialogueData

@onready var interaction_area: Area2D = $InteractionArea

var player_nearby: bool = false


func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_nearby = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_nearby = false


func _unhandled_input(event: InputEvent) -> void:
	if not player_nearby:
		return

	if DialogueManager.is_active:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		if DialogueManager.start_dialogue(dialogue):
			get_viewport().set_input_as_handled()
