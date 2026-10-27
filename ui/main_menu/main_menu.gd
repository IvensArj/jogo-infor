
extends Control

@export_group("Cenas")
@export_file("*.tscn") var first_level_path: String

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

var menu_buttons: Array[Button] = []


func _ready() -> void:
	get_tree().paused = false

	# Conecta os botões.
	new_game_button.pressed.connect(_on_new_game)
	continue_button.pressed.connect(_on_continue)
	exit_button.pressed.connect(_on_exit)

	# Verifica a existência de um save.
	continue_button.disabled = not SaveManager.has_save()

	menu_buttons = [
		new_game_button,
		continue_button,
		exit_button
	]

	_setup_navigation()

	# Aplica o foco depois que a interface estiver pronta.
	_focus_first_button.call_deferred()


# ==========================================
# NAVEGAÇÃO
# ==========================================

func _setup_navigation() -> void:
	for button in menu_buttons:
		button.focus_mode = Control.FOCUS_ALL

	# Define os vizinhos de foco explicitamente.
	# Botões desabilitados são ignorados.
	var available_buttons: Array[Button] = []

	for button in menu_buttons:
		if not button.disabled:
			available_buttons.append(button)

	if available_buttons.is_empty():
		return

	for i in range(available_buttons.size()):
		var button := available_buttons[i]

		var previous := available_buttons[
			(i - 1 + available_buttons.size())
			% available_buttons.size()
		]

		var next := available_buttons[
			(i + 1) % available_buttons.size()
		]

		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)


func _focus_first_button() -> void:
	for button in menu_buttons:
		if not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			return


# ==========================================
# BOTÕES
# ==========================================


func _on_new_game() -> void:
	if first_level_path.is_empty():
		push_error("Configure a fase inicial no Inspector.")
		return

	if not SaveManager.new_game(first_level_path):
		push_error("Não foi possível iniciar uma nova partida.")


func _on_continue() -> void:
	if not SaveManager.continue_game():
		push_error("Não foi possível carregar o save.")


func _on_exit() -> void:
	get_tree().quit()
