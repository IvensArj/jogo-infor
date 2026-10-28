
extends Node

signal presentation_changed

const VALID_LAYOUTS := [
	"auto",
	"xbox",
	"playstation",
	"nintendo"
]

var current_device: String = "keyboard"
var controller_id: int = -1

var detected_layout: String = "xbox"
var layout_override: String = "auto"

# A apresentação não desativa outros métodos físicos de entrada.
var last_used_device: String = "keyboard"
var touchscreen_available: bool = false
var touch_test_mode: bool = false
var touch_controls: CanvasLayer
var _mouse_touch_emulation_before_test: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touchscreen_available = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if OS.has_feature("mobile"):
		current_device = "mobile"
		last_used_device = "mobile"

	Input.joy_connection_changed.connect(
		_on_joy_connection_changed
	)
	_mouse_touch_emulation_before_test = Input.is_emulating_touch_from_mouse()
	if OS.is_debug_build() and "--touch-controls" in OS.get_cmdline_user_args():
		set_touch_test_mode(true)
	_create_touch_controls.call_deferred()


func _create_touch_controls() -> void:
	if is_instance_valid(touch_controls):
		return
	touch_controls = preload("res://ui/touch_controls/touch_controls.tscn").instantiate()
	add_child(touch_controls)


func wants_touch_controls() -> bool:
	return touch_test_mode or (touchscreen_available and current_device == "mobile")


func set_touch_test_mode(enabled: bool) -> void:
	# Opção somente de desenvolvimento; nunca persiste no save ou Input Map.
	if enabled and not OS.is_debug_build():
		return
	touch_test_mode = enabled
	Input.set_emulate_touch_from_mouse(enabled or _mouse_touch_emulation_before_test)
	_set_device("mobile" if enabled or touchscreen_available else "keyboard")
	presentation_changed.emit()


func refresh_touch_controls() -> void:
	if is_instance_valid(touch_controls):
		touch_controls.refresh_context()


func _input(event: InputEvent) -> void:
	# Ações sintéticas do HUD não representam teclado ou gamepad.
	if event is InputEventAction:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			_use_keyboard()

	elif event is InputEventMouseButton:
		if event.pressed:
			_use_keyboard()

	elif event is InputEventMouseMotion:
		if event.relative.length_squared() > 4.0:
			_use_keyboard()

	elif event is InputEventJoypadButton:
		if event.pressed:
			_use_controller(event.device)

	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.65:
			_use_controller(event.device)

	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			use_touch(event.device == InputEvent.DEVICE_ID_EMULATION)


func use_touch(emulated: bool = false) -> void:
	if emulated and not touch_test_mode:
		return
	if not touch_test_mode and not emulated:
		touchscreen_available = true
	_set_device("mobile")
	last_used_device = "mobile"


func _use_keyboard() -> void:
	# Em celular/híbrido, teclado físico mantém touch disponível; no teste também.
	_set_device("mobile" if touch_test_mode or (OS.has_feature("mobile") and touchscreen_available) else "keyboard")
	last_used_device = "keyboard"


func _set_device(device: String) -> void:
	if current_device == device:
		return

	current_device = device
	last_used_device = device
	presentation_changed.emit()


func _use_controller(device_id: int) -> void:
	var changed := current_device != "controller"

	if controller_id != device_id:
		controller_id = device_id
		detected_layout = _detect_layout(device_id)
		changed = true

	current_device = "controller"
	last_used_device = "controller"

	if changed:
		presentation_changed.emit()


func _detect_layout(device_id: int) -> String:
	var joy_name := Input.get_joy_name(device_id)
	var joy_info := Input.get_joy_info(device_id)

	var raw_name := str(
		joy_info.get("raw_name", "")
	)

	var full_name := (
		joy_name + " " + raw_name
	).to_lower()

	if (
		"playstation" in full_name
		or "dualshock" in full_name
		or "dualsense" in full_name
		or "ps4 controller" in full_name
		or "ps5 controller" in full_name
	):
		return "playstation"

	if (
		"nintendo" in full_name
		or "switch" in full_name
		or "joy-con" in full_name
	):
		return "nintendo"

	return "xbox"


func get_controller_layout() -> String:
	if layout_override != "auto":
		return layout_override

	return detected_layout


func set_layout_override(layout: String) -> void:
	if layout not in VALID_LAYOUTS:
		push_warning("[INPUT] Layout inválido: " + layout)
		return

	if layout_override == layout:
		return

	layout_override = layout
	presentation_changed.emit()


func _on_joy_connection_changed(
	device_id: int,
	connected: bool
) -> void:
	if connected:
		return

	if device_id != controller_id:
		return

	controller_id = -1
	detected_layout = "xbox"

	var fallback := "keyboard"

	if touchscreen_available or touch_test_mode:
		fallback = "mobile"

	current_device = fallback
	last_used_device = fallback
	presentation_changed.emit()
