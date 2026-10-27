
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
var current_interactor: Node2D = null


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
	if not Interactable.is_live(current_interactor) or not Interactable.is_live(current_target) or not current_target.can_select(current_interactor):
		hide_prompt()
		return

	_update_position()


func show_target(target: Interactable, interactor: Node2D = null) -> void:
	if not is_instance_valid(target):
		hide_prompt()
		return

	hide_prompt()
	current_target = target
	current_interactor = interactor if interactor != null else get_parent() as Node2D
	current_target.availability_changed.connect(_refresh_text)
	_refresh_text()
	if current_target == null:
		return

	refresh_binding()

	visible = true
	set_process(true)

	_update_position()


func hide_prompt() -> void:
	if is_instance_valid(current_target) and current_target.availability_changed.is_connected(_refresh_text):
		current_target.availability_changed.disconnect(_refresh_text)
	current_target = null
	current_interactor = null

	visible = false
	set_process(false)


func _refresh_text() -> void:
	if not Interactable.is_live(current_interactor) or not Interactable.is_live(current_target) or not current_target.can_select(current_interactor):
		hide_prompt()
		return
	action_label.text = current_target.get_prompt_text(current_interactor)
	panel.reset_size()


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
