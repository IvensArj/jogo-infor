class_name FlagInteractable
extends Interactable

@export_group("Persistência")
@export var persistent_id: String = ""
@export var state_flag: String = ""

var activated: bool = false


func _ready() -> void:
	super._ready()
	GameState.progress_changed.connect(apply_persistent_state)
	apply_persistent_state()


func uses_persistence() -> bool:
	return true


func get_persistent_id() -> String:
	# Faz a validação existente rejeitar também uma flag mal configurada.
	return persistent_id if GameState.is_valid_id(state_flag) else ""


func is_available(interactor: Node2D) -> bool:
	return (
		super.is_available(interactor) and not activated
		and GameState.is_valid_id(get_persistent_id())
	)


func apply_persistent_state() -> void:
	if not is_live(self):
		return
	activated = GameState.is_valid_id(state_flag) and GameState.get_flag(state_flag)
	has_interacted = activated
	_apply_visual_state()
	invalidate_requirements()


func _apply_visual_state() -> void:
	pass


# Interface tipada para ações; restauração continua usando apply_persistent_state.
func activate() -> bool:
	if not is_live(self) or not enabled or SaveManager.is_loading():
		return false
	if not GameState.is_valid_id(get_persistent_id()):
		return false
	GameState.set_flag(state_flag, true)
	return activated
