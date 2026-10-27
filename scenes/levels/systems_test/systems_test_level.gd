extends Node2D

var session: SystemsTestSession
@onready var puzzle: SequencePuzzle = $AreaD/Puzzle
@onready var status: Label = $TestHUD/Panel/Column/Status


func _enter_tree() -> void:
	session = SystemsTestSession.begin(get_tree())
	if session != null:
		session.prepare_level()
	else:
		# Não permite que o botão Salvar use o slot normal em caso de falha.
		get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menu.tscn")


func _ready() -> void:
	$TestHUD/Panel/Column/Buttons/Save.pressed.connect(_save_test)
	$TestHUD/Panel/Column/Buttons/Reload.pressed.connect(_reload_test)
	$TestHUD/Panel/Column/Buttons/Attempt.pressed.connect(puzzle.reset_attempt)
	$TestHUD/Panel/Column/Buttons/Reset.pressed.connect(_reset_progress)
	$TestHUD/Panel/Column/Buttons/Exit.pressed.connect(_exit_test)
	puzzle.incorrect_input.connect(_on_incorrect_input)
	puzzle.correct_input.connect(_on_correct_input)
	puzzle.completed.connect(_on_completed)


func _process(_delta: float) -> void:
	status.text = "Dash: %s | Pulo duplo: %s | Parede: %s | Sequência: %d/3 | Concluído: %s" % [
		"liberado" if GameState.has_ability("dash") else "bloqueado",
		"liberado" if GameState.has_ability("double_jump") else "bloqueado",
		"liberado" if GameState.has_ability("wall_jump") else "bloqueado",
		puzzle.current_step, "sim" if puzzle.is_completed else "não"]


func _save_test() -> void:
	if is_instance_valid(session):
		$TestHUD/Panel/Column/Feedback.text = "Teste salvo." if SaveManager.save_game() else "Não foi possível salvar o teste."


func _reload_test() -> void:
	if is_instance_valid(session) and not SaveManager.continue_game():
		$TestHUD/Panel/Column/Feedback.text = "Salve este teste antes de recarregar."


func _reset_progress() -> void:
	if is_instance_valid(session):
		session.restart_progress()


func _exit_test() -> void:
	if not SaveManager.is_loading():
		get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")


func _on_incorrect_input(_switch_id: String) -> void:
	$TestHUD/Panel/Column/Feedback.text = "Ordem incorreta. Tentativa reiniciada."


func _on_correct_input(_switch_id: String) -> void:
	$TestHUD/Panel/Column/Feedback.text = "Entrada correta."


func _on_completed() -> void:
	$TestHUD/Panel/Column/Feedback.text = "Sequência concluída. Porta aberta."
