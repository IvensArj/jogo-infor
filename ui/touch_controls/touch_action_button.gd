class_name TouchActionButton
extends TouchScreenButton

@export var caption: String = ""
@export var base_diameter: float = 80.0
@export_range(0.0, 24.0, 1.0) var touch_padding: float = 8.0
var available: bool = true
var input_action: StringName
var finger_index: int = -1
var finger_device: int = 0
var _source := TouchActionSource.new()
var _input_router: Node


func _ready() -> void:
	# Preserva action no Inspector. Em runtime, substitui o emissor nativo
	# (action_press/release + push_input) por um único evento por fonte.
	input_action = StringName(action)
	action = ""
	passby_press = false
	visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	shape_visible = false
	var circle := CircleShape2D.new()
	circle.radius = base_diameter * 0.5 + touch_padding
	shape = circle
	shape_centered = false
	pressed.connect(_on_pressed)
	released.connect(_on_released)
	queue_redraw()


func _draw() -> void:
	var radius := base_diameter * 0.5
	var fill := Color(0.08, 0.13, 0.20, 0.75)
	if is_pressed():
		fill = Color(0.25, 0.65, 0.90, 0.95)
	if not available:
		fill.a = 0.25
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius - 2.0, 0.0, TAU, 48, Color(0.85, 0.95, 1.0, 0.8), 2.0, true)
	var font := ThemeDB.fallback_font
	var font_size := 17
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(-text_size.x * 0.5, font_size * 0.32), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


func set_available(value: bool) -> void:
	if available == value:
		return
	available = value
	# Ocultar um TouchScreenButton libera o dedo e a ação nativamente.
	visible = value
	queue_redraw()


func release_touch() -> void:
	finger_index = -1
	finger_device = 0
	var was_visible := visible
	hide()
	visible = was_visible
	_source.release_all()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_PAUSED]:
		if is_inside_tree():
			release_touch()


func _on_pressed() -> void:
	# O teste geométrico nativo não conhece a posse atribuída pelo HUD.
	# Shapes sobrepostas podem emitir pressed para componentes não autorizados.
	if is_instance_valid(_input_router) and not _input_router.owns_touch(self, finger_index, finger_device):
		release_touch()
		return
	_source.set_strength(input_action, 1.0)
	queue_redraw()


func set_input_router(router: Node) -> void:
	_input_router = router


func _on_released() -> void:
	finger_index = -1
	finger_device = 0
	_source.release_all()
	queue_redraw()


func _exit_tree() -> void:
	_source.release_all()


func contains_point(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return local.length() <= base_diameter * 0.5 + touch_padding
