# Anexar a um Area2D com CollisionShape2D.
extends Area2D

@export var persistent_id: String = ""
var collected := false


func uses_persistence() -> bool:
	return true


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
	collected = GameState.has_item(persistent_id)
	visible = not collected
	# Agenda sempre: o estado pode mudar novamente antes do fim do frame.
	set_deferred("monitoring", not collected)


func _on_body_entered(body: Node2D) -> void:
	if SaveManager.is_loading():
		return
	if collected or not body.is_in_group("Player") or not GameState.is_valid_id(persistent_id):
		return
	GameState.collect_item(persistent_id)
