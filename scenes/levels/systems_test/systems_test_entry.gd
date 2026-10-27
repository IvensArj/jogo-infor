extends Node


func _ready() -> void:
	var session := SystemsTestSession.begin(get_tree())
	if session != null and not session.restart_progress():
		session.finish()
		push_error("Não foi possível abrir o laboratório de sistemas.")
