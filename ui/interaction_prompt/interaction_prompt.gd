
class_name InteractionPrompt
extends Control

@export_group("Configuração")
@export var input_action: StringName = &"interact"

@export_group("Posicionamento")
@export var world_offset: Vector2 = Vector2(0, -55)

@onready var panel: PanelContainer = $PanelContainer
@onready var key_icon: TextureRect = $PanelContainer/HBoxContainer/KeyIcon
@onready var key_label: Label = $PanelContainer/HBoxContainer/KeyLabel
@onready var action_label: Label = $PanelContainer/HBoxContainer/ActionLabel

var current_target: Interactable = null


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	visible = false
	set_process(false)

	InputDeviceManager.presentation_changed.connect(
		refresh_binding
	)

	refresh_binding()


func _process(_delta: float) -> void:
	if not is_instance_valid(current_target):
		hide_prompt()
		return

	_update_position()


func show_target(target: Interactable) -> void:
	if not is_instance_valid(target):
		hide_prompt()
		return

	current_target = target

	action_label.text = target.get_interaction_text()

	refresh_binding()

	visible = true
	set_process(true)

	_update_position()


func hide_prompt() -> void:
	current_target = null

	visible = false
	set_process(false)


func set_input_action(action: StringName) -> void:
	input_action = action
	refresh_binding()


func refresh_binding() -> void:
	if not is_node_ready():
		return

	var glyph := InputGlyphResolver.resolve(
		input_action,
		InputDeviceManager.current_device,
		InputDeviceManager.get_controller_layout()
	)

	var texture := glyph.get("texture") as Texture2D
	var fallback_text := str(glyph.get("text", "?"))

	key_icon.texture = texture
	key_icon.visible = texture != null

	key_label.text = fallback_text
	key_label.visible = texture == null

	panel.reset_size()

	if visible:
		_update_position()



func _update_position() -> void:
	if not is_instance_valid(current_target):
		return

	var target_position := current_target.get_prompt_position()
	var panel_size := panel.size

	global_position = (
		target_position
		+ world_offset
		- Vector2(panel_size.x / 2.0, panel_size.y)
	)
