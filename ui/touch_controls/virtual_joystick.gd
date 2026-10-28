class_name TouchVirtualJoystick
extends Node2D

signal output_changed(value: Vector2)

@export_group("Entrada analógica")
@export var action_left: StringName = &"move_left"
@export var action_right: StringName = &"move_right"
@export var action_crouch: StringName = &"crouch"
@export_range(0.0, 0.8, 0.01) var deadzone: float = 0.15
@export_range(24.0, 120.0, 1.0) var max_radius: float = 64.0
@export_range(64.0, 180.0, 1.0) var touch_radius: float = 112.0
@export_group("Agachamento — histerese na saída Y")
@export_range(0.01, 1.0, 0.01) var crouch_activate_threshold: float = 0.60
@export_range(0.0, 0.99, 0.01) var crouch_release_threshold: float = 0.40
@export_group("Aparência")
@export var base_radius: float = 92.0
@export var knob_radius: float = 26.0
@export_range(1.0, 40.0, 1.0) var visual_return_speed: float = 24.0

var finger_index: int = -1
var finger_device: int = 0
var output: Vector2 = Vector2.ZERO
# Mantém a consulta horizontal usada pelo HUD e ferramentas existentes.
var output_x: float:
	get:
		return output.x
var crouch_held: bool = false
var knob_position: Vector2 = Vector2.ZERO
var _knob_target: Vector2 = Vector2.ZERO
var _source := TouchActionSource.new()
var _input_router: Node


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	queue_redraw()


func contains_point(point: Vector2) -> bool:
	return _local_point(point).length_squared() <= touch_radius * touch_radius


func get_extent() -> float:
	return maxf(touch_radius, maxf(base_radius, max_radius + knob_radius))


func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.canceled:
			if event.index == finger_index and event.device == finger_device:
				release_touch()
				get_viewport().set_input_as_handled()
		elif event.pressed:
			if is_instance_valid(_input_router) and not _input_router.owns_touch(self, event.index, event.device):
				return
			if finger_index == -1 and contains_point(event.position):
				finger_index = event.index
				finger_device = event.device
				_update_output(event.position)
				get_viewport().set_input_as_handled()
		elif event.index == finger_index and event.device == finger_device:
			release_touch()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger_index and event.device == finger_device:
		_update_output(event.position)
		get_viewport().set_input_as_handled()


func set_input_router(router: Node) -> void:
	_input_router = router


func _update_output(point: Vector2) -> void:
	var radius := maxf(max_radius, 1.0)
	var displacement := _local_point(point).limit_length(radius)
	_knob_target = displacement
	var normalized := displacement / radius
	var length := normalized.length()
	var value := Vector2.ZERO
	if length > deadzone:
		value = normalized.normalized() * clampf((length - deadzone) / maxf(1.0 - deadzone, 0.001), 0.0, 1.0)
	_set_output(value)


func _set_output(value: Vector2) -> void:
	var activate := clampf(crouch_activate_threshold, 0.01, 1.0)
	var deactivate := clampf(crouch_release_threshold, 0.0, activate - 0.01)
	var next_crouch := crouch_held
	if value.y >= activate or is_equal_approx(value.y, activate):
		next_crouch = true
	elif value.y <= deactivate or is_equal_approx(value.y, deactivate):
		next_crouch = false
	if output.is_equal_approx(value) and next_crouch == crouch_held:
		return
	output = value
	crouch_held = next_crouch
	_source.set_strength(action_left, maxf(-value.x, 0.0))
	_source.set_strength(action_right, maxf(value.x, 0.0))
	_source.set_strength(action_crouch, 1.0 if next_crouch else 0.0)
	output_changed.emit(value)


func release_touch() -> void:
	finger_index = -1
	finger_device = 0
	_knob_target = Vector2.ZERO
	_set_output(Vector2.ZERO)
	_source.release_all()


func _process(delta: float) -> void:
	knob_position = knob_position.lerp(_knob_target, 1.0 - exp(-visual_return_speed * delta))
	if knob_position.distance_squared_to(_knob_target) < 0.01:
		knob_position = _knob_target
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, base_radius, Color(0.06, 0.10, 0.17, 0.65))
	draw_arc(Vector2.ZERO, base_radius, 0.0, TAU, 64, Color(0.8, 0.92, 1.0, 0.7), 2.0, true)
	draw_arc(Vector2.ZERO, max_radius, 0.0, TAU, 64, Color(0.8, 0.92, 1.0, 0.2), 1.0, true)
	draw_circle(Vector2.ZERO, max_radius * deadzone, Color(0.8, 0.92, 1.0, 0.12))
	var color := Color(0.35, 0.70, 0.90, 0.9) if finger_index >= 0 else Color(0.65, 0.80, 0.90, 0.75)
	draw_circle(knob_position, knob_radius, color)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		release_touch()
		knob_position = Vector2.ZERO


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_PAUSED]:
		release_touch()


func _exit_tree() -> void:
	release_touch()
