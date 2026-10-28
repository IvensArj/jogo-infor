extends CanvasLayer

@export_group("Layout em unidades da viewport")
@export_range(56.0, 140.0, 1.0) var button_size: float = 84.0
@export_range(1.0, 1.5, 0.05) var jump_size_multiplier: float = 1.2
@export_range(0.6, 1.5, 0.05) var joystick_scale: float = 1.0
@export_range(0.2, 1.0, 0.05) var opacity: float = 0.8
@export_range(8.0, 64.0, 1.0) var margin: float = 24.0
@export_range(16.0, 48.0, 1.0) var spacing: float = 24.0
@export var joystick_offset: Vector2 = Vector2.ZERO
@export var actions_offset: Vector2 = Vector2.ZERO
@export var pause_offset: Vector2 = Vector2.ZERO
@export var respect_safe_area: bool = true
@export_group("Desenvolvimento")
@export var show_debug_values: bool = true

@onready var buttons_root: Node2D = $Controls
@onready var joystick: TouchVirtualJoystick = $Controls/JoystickContainer/VirtualJoystick
var buttons: Dictionary = {}
var _actor: Node2D
var _interactor: Interactor
var _scene: Node
var _active: bool = false
var _focused: bool = true
var _captures: Dictionary = {}
var _mouse_captured: bool = false
var _last_active_frame: int = -1
var _last_layout: Rect2
var _layout_settings: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	buttons_root.hide()
	for button: TouchActionButton in $Controls/ActionButtons.get_children():
		buttons[button.input_action] = button
		button.set_input_router(self)
	var pause_button: TouchActionButton = $Controls/PauseButton
	buttons[pause_button.input_action] = pause_button
	pause_button.set_input_router(self)
	joystick.set_input_router(self)
	InputDeviceManager.presentation_changed.connect(refresh_context)
	DialogueManager.dialogue_started.connect(refresh_context)
	DialogueManager.dialogue_finished.connect(refresh_context)
	DialogueManager.inspection_started.connect(refresh_context)
	DialogueManager.inspection_finished.connect(refresh_context)
	get_tree().scene_changed.connect(refresh_context)
	get_viewport().size_changed.connect(_layout)
	visibility_changed.connect(refresh_context)
	_layout()
	refresh_context()


func _process(_delta: float) -> void:
	refresh_context()
	if _safe_rect() != _last_layout or _settings() != _layout_settings:
		_layout()
	$Controls/Diagnostics.visible = _active and show_debug_values and InputDeviceManager.touch_test_mode
	if $Controls/Diagnostics.visible:
		$Controls/Diagnostics.text = "X %+.2f  Y %+.2f | agachar %s | dedo %d" % [joystick.output.x, joystick.output.y, "sim" if Input.is_action_pressed("crouch") else "não", joystick.finger_index]


func refresh_context() -> void:
	if not is_node_ready():
		return
	var scene := get_tree().current_scene
	var actor := get_tree().get_first_node_in_group("Player") as Node2D
	if not GameplayContext.is_live(actor) or scene == null or not (actor == scene or scene.is_ancestor_of(actor)):
		actor = null
	if actor != _actor or scene != _scene:
		release_all()
		_bind_actor(actor)
		_scene = scene
	var should_show := (
		visible and _focused and actor != null and InputDeviceManager.wants_touch_controls()
		and not get_tree().paused and not SaveManager.is_loading()
		and not DialogueManager.blocks_interaction()
	)
	if should_show != _active:
		if not should_show:
			release_all()
		_active = should_show
		buttons_root.visible = _active
	if _active:
		_last_active_frame = Engine.get_process_frames()
		_update_interaction()


func _bind_actor(actor: Node2D) -> void:
	if is_instance_valid(_interactor) and _interactor.target_changed.is_connected(_on_target_changed):
		_interactor.target_changed.disconnect(_on_target_changed)
	if is_instance_valid(_actor) and _actor.tree_exiting.is_connected(_on_actor_exiting):
		_actor.tree_exiting.disconnect(_on_actor_exiting)
	_actor = actor
	_interactor = null
	if actor == null:
		return
	_actor.tree_exiting.connect(_on_actor_exiting)
	for candidate in get_tree().get_nodes_in_group("input_interactors"):
		if actor.is_ancestor_of(candidate):
			_interactor = candidate as Interactor
			_interactor.target_changed.connect(_on_target_changed)
			break


func _on_actor_exiting() -> void:
	release_all()
	buttons_root.hide()
	_active = false


func _on_target_changed(_target: Interactable) -> void:
	_update_interaction()


func _update_interaction() -> void:
	var has_target := is_instance_valid(_interactor) and _interactor.interaction_enabled and GameplayContext.is_live(_interactor.current_target)
	buttons[&"interact"].set_available(has_target)


func release_all() -> void:
	# Mantém a posse de contatos antigos apenas para consumir seus arrastes.
	# Um novo press com o mesmo índice inicia outra vida de toque.
	for contact: Vector2i in _captures:
		_captures[contact] = null
	if is_instance_valid(joystick):
		joystick.release_touch()
	for button: TouchActionButton in buttons.values():
		if is_instance_valid(button):
			button.release_touch()


func _release_finger(index: int, device: int = 0) -> void:
	var key := Vector2i(device, index)
	var component: Variant = _captures.get(key)
	_captures.erase(key)
	if is_instance_valid(component):
		component.release_touch()


func owns_touch(component: Node, index: int, device: int = 0) -> bool:
	return _active and index >= 0 and _captures.get(Vector2i(device, index)) == component


func guard_input(event: InputEvent) -> void:
	# Último filho executa antes dos componentes. Só captura/cancela contatos;
	# os componentes e TouchActionSource são os únicos emissores de ações.
	if event is InputEventScreenTouch:
		var key := Vector2i(event.device, event.index)
		if event.canceled:
			if _captures.has(key):
				_release_finger(event.index, event.device)
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			var existing: Variant = _captures.get(key)
			if is_instance_valid(existing) and existing.finger_index == event.index:
				# Press duplicado na mesma vida de contato não recria a ação.
				get_viewport().set_input_as_handled()
				return
			_release_finger(event.index, event.device)
			InputDeviceManager.use_touch(event.device == InputEvent.DEVICE_ID_EMULATION)
			refresh_context()
			if not _active:
				return
			var component := _component_at(event.position)
			if component == null:
				return
			if component.finger_index != -1:
				_captures[key] = null
				get_viewport().set_input_as_handled()
			else:
				_captures[key] = component
				if component is TouchActionButton:
					component.finger_index = event.index
					component.finger_device = event.device
		elif _captures.has(key):
			_release_finger(event.index, event.device)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var key := Vector2i(event.device, event.index)
		if _captures.has(key) and _captures[key] == null:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouse:
		_guard_mouse(event)


func _guard_mouse(event: InputEventMouse) -> void:
	# Não confundir algum dedo capturado com a origem desta sequência de mouse.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_captured = _over_controls(event.position)
		var consume := _mouse_captured
		if not event.pressed:
			_mouse_captured = false
		if consume:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_captured:
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if _captures.has(Vector2i(event.device, event.index)):
			get_viewport().set_input_as_handled()


func _component_at(point: Vector2) -> Node2D:
	for button: TouchActionButton in buttons.values():
		if button.available and button.contains_point(point):
			return button
	if joystick.contains_point(point):
		return joystick
	return null


func _over_controls(point: Vector2) -> bool:
	return (_active or _last_active_frame == Engine.get_process_frames()) and _component_at(point) != null


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_focused = false
		_mouse_captured = false
		if is_node_ready():
			release_all()
			refresh_context()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		_focused = true
		refresh_context()


func _safe_rect() -> Rect2:
	return SafeAreaLayout.viewport_rect(get_viewport()) if respect_safe_area else get_viewport().get_visible_rect()


func _settings() -> Array:
	return [button_size, jump_size_multiplier, joystick_scale, opacity, margin, spacing, joystick_offset, actions_offset, pause_offset, joystick.get_extent()]


func _layout() -> void:
	if not is_node_ready():
		return
	release_all()
	_last_layout = _safe_rect()
	_layout_settings = _settings()
	var touch_extent := joystick.get_extent() * joystick_scale
	var jump_extent: float = (40.0 + buttons[&"jump"].touch_padding) * button_size / 80.0 * jump_size_multiplier
	var step := button_size + spacing
	var required := Vector2(2.0 * margin + 2.0 * touch_extent + 2.0 * jump_extent + 1.2 * step + 80.0, 2.0 * margin + 2.0 * jump_extent + 2.65 * step)
	var factor := minf(1.0, minf(_last_layout.size.x / required.x, _last_layout.size.y / required.y))
	var right: float = _last_layout.end.x - (margin + jump_extent) * factor
	var bottom: float = _last_layout.end.y - (margin + jump_extent) * factor
	var positions := {
		&"jump": Vector2(right, bottom),
		&"crouch": Vector2(right - 1.2 * step * factor, bottom),
		&"dash": Vector2(right - 0.9 * step * factor, bottom - 1.1 * step * factor),
		&"interact": Vector2(right, bottom - 1.85 * step * factor),
		&"pause": Vector2(right, _last_layout.position.y + (margin + jump_extent) * factor)
	}
	for action: StringName in buttons:
		var button: TouchActionButton = buttons[action]
		var multiplier := jump_size_multiplier if action == &"jump" else 1.0
		button.scale = Vector2.ONE * button_size / button.base_diameter * multiplier * factor
		var offset := pause_offset if action == &"pause" else actions_offset
		var extent := (button.base_diameter * 0.5 + button.touch_padding) * button.scale.x
		button.position = _clamp_center(positions[action] + offset * factor, extent)
	joystick.scale = Vector2.ONE * joystick_scale * factor
	var center := Vector2(_last_layout.position.x + (margin + touch_extent) * factor, _last_layout.end.y - (margin + touch_extent) * factor)
	joystick.position = _clamp_center(center + joystick_offset * factor, touch_extent * factor)
	$Controls/Diagnostics.position = Vector2(_last_layout.get_center().x - 220.0, _last_layout.end.y - 44.0)
	$Controls/Diagnostics.size = Vector2(440, 24)
	buttons_root.modulate.a = opacity


func _clamp_center(center: Vector2, extent: float) -> Vector2:
	return center.clamp(_last_layout.position + Vector2.ONE * extent, _last_layout.end - Vector2.ONE * extent)


func _exit_tree() -> void:
	release_all()
