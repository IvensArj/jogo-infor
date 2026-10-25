
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


func _ready() -> void:
	if OS.has_feature("mobile"):
		current_device = "mobile"

	Input.joy_connection_changed.connect(
		_on_joy_connection_changed
	)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			_set_device("keyboard")

	elif event is InputEventMouseButton:
		if event.pressed:
			_set_device("keyboard")

	elif event is InputEventJoypadButton:
		if event.pressed:
			_use_controller(event.device)

	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.65:
			_use_controller(event.device)

	elif event is InputEventScreenTouch:
		if event.pressed:
			_set_device("mobile")


func _set_device(device: String) -> void:
	if current_device == device:
		return

	current_device = device
	presentation_changed.emit()


func _use_controller(device_id: int) -> void:
	var changed := current_device != "controller"

	if controller_id != device_id:
		controller_id = device_id
		detected_layout = _detect_layout(device_id)
		changed = true

	current_device = "controller"

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

	if OS.has_feature("mobile"):
		fallback = "mobile"

	current_device = fallback
	presentation_changed.emit()
