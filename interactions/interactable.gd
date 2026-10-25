
class_name Interactable
extends Area2D

signal interacted(interactor: Node2D)

@export_group("Interação")
@export var interaction_name: String = "Objeto"
@export var action_text: String = "Interagir"
@export var enabled: bool = true
@export var one_shot: bool = false

@export_group("Seleção")
@export_range(0, 100, 1) var selection_priority: int = 0

@export_group("Indicador")
@export var prompt_offset: Vector2 = Vector2(0, -40)

@onready var prompt_anchor: Marker2D = get_node_or_null(
	"PromptAnchor"
) as Marker2D


var has_interacted: bool = false


func can_interact(interactor: Node2D) -> bool:
	if not enabled:
		return false

	if one_shot and has_interacted:
		return false

	return is_instance_valid(interactor)



func get_prompt_position() -> Vector2:
	if is_instance_valid(prompt_anchor):
		return prompt_anchor.global_position

	return global_position + prompt_offset


func interact(interactor: Node2D) -> void:
	if not can_interact(interactor):
		return

	has_interacted = true
	interacted.emit(interactor)
	_on_interact(interactor)


func _on_interact(_interactor: Node2D) -> void:
	pass


func get_interaction_text() -> String:
	return action_text
