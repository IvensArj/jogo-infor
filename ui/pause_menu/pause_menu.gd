
extends CanvasLayer

@export_file("*.tscn") var main_menu_path: String

@onready var panel: ColorRect = $PausePanel
@onready var resume_button: Button = $PausePanel/CenterContainer/VBoxContainer/ResumeButton
@onready var save_button: Button = $PausePanel/CenterContainer/VBoxContainer/SaveButton
@onready var main_menu_button: Button = $PausePanel/CenterContainer/VBoxContainer/MainMenuButton
@onready var status_label: Label = $PausePanel/CenterContainer/VBoxContainer/StatusLabel

var is_open: bool = false


func _ready() -> void:
	# Permite receber entradas mesmo com o jogo pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS

	panel.hide()

	resume_button.pressed.connect(close_menu)
	save_button.pressed.connect(_on_save)
	main_menu_button.pressed.connect(_on_main_menu)
	for button: Button in [resume_button, save_button, main_menu_button]:
		button.custom_minimum_size = Vector2(240, 52)
	$PausePanel/CenterContainer/VBoxContainer.add_theme_constant_override("separation", 12)


func _process(_delta: float) -> void:
	if is_open:
		SafeAreaLayout.fit_control($PausePanel/CenterContainer)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return

	if event.is_echo():
		return

	get_viewport().set_input_as_handled()

	if is_open:
		close_menu()
	else:
		# Evita abrir a pausa durante uma conversa.
		if DialogueManager.is_active:
			return

		open_menu()


func open_menu() -> void:
	if is_open or DialogueManager.blocks_interaction() or SaveManager.is_loading():
		return

	is_open = true

	status_label.text = ""
	panel.show()

	get_tree().paused = true
	InputDeviceManager.refresh_touch_controls()

	resume_button.grab_focus()


func close_menu() -> void:
	if not is_open:
		return

	is_open = false

	panel.hide()
	get_tree().paused = false
	InputDeviceManager.refresh_touch_controls()


func _on_save() -> void:
	if SaveManager.save_game():
		status_label.text = "Jogo salvo!"
	else:
		status_label.text = "Erro ao salvar o jogo."


func _on_main_menu() -> void:
	if SaveManager.is_loading():
		return

	if main_menu_path.is_empty():
		push_error("Configure Main Menu Path no Inspector.")
		return

	close_menu()

	get_tree().change_scene_to_file(main_menu_path)
