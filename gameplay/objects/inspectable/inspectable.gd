class_name Inspectable
extends Interactable

signal first_read(actor: Node2D)

@export var content: InspectionData
@export var persistent_id: String = ""
@export var persistent_read: bool = true
@export var first_read_event_id: String = ""

var has_read: bool = false


func _ready() -> void:
	super._ready()
	GameState.progress_changed.connect(apply_persistent_state)
	apply_persistent_state()


func uses_persistence() -> bool:
	return persistent_read


func get_persistent_id() -> String:
	return persistent_id


func apply_persistent_state() -> void:
	if is_live(self) and persistent_read:
		has_read = GameState.is_event_complete(persistent_id)


func can_interact(actor: Node2D) -> bool:
	if not is_live(self):
		return false
	var ui := get_tree().get_first_node_in_group("InspectionUI") as InspectionUI
	return (
		super.can_interact(actor) and not DialogueManager.blocks_interaction() and not get_tree().paused
		and content != null and not content.title.is_empty()
		and (not persistent_read or GameState.is_valid_id(persistent_id))
		and (first_read_event_id.is_empty() or GameState.is_valid_id(first_read_event_id))
		and is_live(ui)
	)


func _complete_interaction(actor: Node2D) -> bool:
	var ui := get_tree().get_first_node_in_group("InspectionUI") as InspectionUI
	if ui == null or not ui.open_content(content, self):
		return false
	if has_read:
		return true
	has_read = true
	if persistent_read:
		GameState.complete_event(persistent_id)
	if not first_read_event_id.is_empty():
		GameState.complete_event(first_read_event_id)
	first_read.emit(actor)
	return true
