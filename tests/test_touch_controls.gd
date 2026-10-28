extends Node

var checks: int = 0
var failures: int = 0
var hud: CanvasLayer
var player: CharacterBody2D
var interactor: Interactor
var target: Interactable
var interaction_count: int = 0
var action_count: int = 0
var dialogue_ui: CanvasLayer
var crouch_presses: int = 0
var crouch_releases: int = 0
var press_counts: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("TOUCH: " + message)


func _input(event: InputEvent) -> void:
	if event is InputEventAction and event.pressed:
		press_counts[event.action] = int(press_counts.get(event.action, 0)) + 1
	if event is InputEventAction and event.is_action_pressed("interact"):
		action_count += 1
	if event is InputEventAction and event.action == &"crouch":
		if event.pressed:
			crouch_presses += 1
		else:
			crouch_releases += 1


func touch(action: StringName, finger: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.pressed = pressed
	if action in [&"move_left", &"move_right"]:
		var side := -1.0 if action == &"move_left" else 1.0
		event.position = hud.joystick.get_global_transform_with_canvas() * Vector2(side * hud.joystick.max_radius, 0.0)
	else:
		var button: TouchActionButton = hud.buttons[action]
		event.position = button.get_global_transform_with_canvas() * Vector2.ZERO
	get_viewport().push_input(event, true)
	# Drenagem de teste após retornar da árvore; nunca dentro dos callbacks.
	Input.flush_buffered_events()


func settle(frames: int = 2) -> void:
	for frame in range(frames):
		await get_tree().process_frame


func stick_drag(finger: int, normalized: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = hud.joystick.get_global_transform_with_canvas() * (normalized * hud.joystick.max_radius)
	get_viewport().push_input(event, true)
	# Drenagem de teste após retornar da árvore; nunca dentro dos callbacks.
	Input.flush_buffered_events()


func stick_press(finger: int, normalized: Vector2, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.pressed = true
	event.canceled = canceled
	event.position = hud.joystick.get_global_transform_with_canvas() * (normalized * hud.joystick.max_radius)
	get_viewport().push_input(event, true)
	# Drenagem de teste após retornar da árvore; nunca dentro dos callbacks.
	Input.flush_buffered_events()


func tap_control(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	motion.position = control.get_global_rect().get_center()
	get_viewport().push_input(motion, true)
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 31
		event.position = get_viewport().get_screen_transform() * control.get_global_rect().get_center()
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _run() -> void:
	await settle()
	hud = InputDeviceManager.touch_controls
	check(hud != null and not hud.buttons_root.visible, "desktop começa sem HUD")
	player = preload("res://gameplay/player/player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	interactor = player.get_node("Interactor")
	interactor.set_physics_process(false)
	target = Interactable.new()
	add_child(target)
	target.interacted.connect(func(_actor: Node2D): interaction_count += 1)
	interactor.nearby_interactables.assign([target])
	interactor._update_target()
	InputDeviceManager.set_touch_test_mode(true)
	await settle()
	check(hud.buttons_root.visible, "modo de teste mostra HUD em gameplay")
	check(hud.buttons[&"interact"].visible, "alvo habilita interação contextual")
	_test_buffered_multitouch()
	_test_overlapping_controls()
	_test_duplicate_and_emulated_contacts()
	await _test_joystick()
	await _test_360_crouch()
	await _test_release_permutations()
	var event_count_before := action_count
	var interactions_before := interaction_count
	touch(&"interact", 2, true)
	touch(&"interact", 2, false)
	check(interaction_count == interactions_before + 1 and action_count == event_count_before + 1, "um toque produz uma única ação e interação pela árvore")
	touch(&"move_right", 0, true)
	touch(&"jump", 1, true)
	check(Input.get_axis("move_left", "move_right") == 1.0 and Input.is_action_pressed("jump"), "dois dedos mantêm direção e pulo")
	player._update_jump_buffer(0.0)
	check(player.jump_buffer_timer > 0.0, "toque alimenta jump buffer original")
	player.floor_jump_available = true
	player.coyote_timer = player.coyote_time
	check(player._try_jump(false) and player.velocity.y < 0.0, "pulo touch usa coyote time original")
	var jump_velocity: float = player.velocity.y
	touch(&"jump", 1, false)
	player._apply_jump_cut()
	check(is_equal_approx(player.velocity.y, jump_velocity * player.jump_cut), "soltar toque mantém altura variável")
	check(Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"), "soltar um dedo preserva o outro")
	touch(&"dash", 3, true)
	player._try_start_dash(Input.get_axis("move_left", "move_right"))
	check(player.is_dashing, "direção e dash multitouch usam habilidade original")
	touch(&"dash", 3, false)
	player._finish_dash()
	touch(&"move_right", 0, false)
	check(not Input.is_action_pressed("move_right"), "soltar direção limpa ação")
	touch(&"crouch", 4, true)
	player._update_crouch(true)
	check(player.is_crouching, "agachamento touch usa colisão existente")
	touch(&"crouch", 4, false)
	player._update_crouch(true)
	check(not player.is_crouching, "soltar agachamento permite levantar")
	await settle()
	touch(&"jump", 1, true)
	touch(&"jump", 1, false)
	player._update_jump_buffer(0.0)
	check(player.jump_buffer_timer > 0.0 and not Input.is_action_pressed("jump"), "toque rápido preserva buffer após soltar")

	# Inverter o joystick não depende de passby_press de botões antigos.
	touch(&"move_left", 0, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = hud.joystick.get_global_transform_with_canvas() * Vector2(hud.joystick.max_radius, 0)
	get_viewport().push_input(drag, true)
	Input.flush_buffered_events()
	check(not Input.is_action_pressed("move_left") and Input.is_action_pressed("move_right"), "arrastar troca direção")
	touch(&"move_right", 0, false)

	# Ocultar, foco e pausa devem limpar também o dedo nativo.
	for reason in ["hide", "focus", "pause"]:
		touch(&"move_left", 0, true)
		if reason == "hide":
			hud.hide()
		elif reason == "focus":
			hud._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		else:
			get_tree().paused = true
			hud.refresh_context()
		Input.flush_buffered_events()
		check(not Input.is_action_pressed("move_left") and hud.joystick.finger_index == -1, "limpeza após " + reason)
		touch(&"move_left", 0, false)
		get_tree().paused = false
		hud.show()
		hud._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		await settle()

	await _test_modals()
	await _test_layout_and_lifecycle()
	await _test_shared_physical_action()
	await _test_devices()
	# Substituir Player/cena não cria HUD adicional nem preserva comandos.
	touch(&"move_right", 0, true)
	player.free()
	await settle()
	check(not Input.is_action_pressed("move_right") and not hud.buttons_root.visible, "remoção do Player limpa HUD e entrada")
	InputDeviceManager._create_touch_controls()
	check(InputDeviceManager.touch_controls == hud and InputDeviceManager.get_child_count() == 1, "HUD único por sessão")
	await _test_scene_transitions()
	await _test_hud_teardown()
	InputDeviceManager.set_touch_test_mode(false)
	print("Touch tests: %d verificações, %d falhas." % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func queue_touch(action: StringName, finger: int, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.pressed = down
	var point: Vector2
	if action == &"move_right":
		point = hud.joystick.get_global_transform_with_canvas() * Vector2(hud.joystick.max_radius, 0)
	else:
		point = hud.buttons[action].get_global_transform_with_canvas() * Vector2.ZERO
	event.position = get_viewport().get_screen_transform() * point
	Input.parse_input_event(event)


func _test_buffered_multitouch() -> void:
	var actions: Array[StringName] = [&"move_right", &"jump", &"dash"]
	for order in [[0, 1, 2], [2, 1, 0], [1, 0, 2]]:
		for index in range(3):
			queue_touch(actions[index], index + 40, true)
		for index: int in order:
			queue_touch(actions[index], index + 40, false)
		Input.flush_buffered_events()
		check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump") and not Input.is_action_pressed("dash"), "lote multitoque termina neutro na ordem " + str(order))
		check(hud.joystick.finger_index == -1 and not hud.buttons[&"jump"].is_pressed() and not hud.buttons[&"dash"].is_pressed(), "componentes do lote também ficam neutros " + str(order))
		hud.release_all()


func _test_overlapping_controls() -> void:
	var jump: TouchActionButton = hud.buttons[&"jump"]
	var crouch: TouchActionButton = hud.buttons[&"crouch"]
	var original := crouch.position
	crouch.position = jump.position
	touch(&"jump", 50, true)
	check(not (Input.is_action_pressed("jump") and Input.is_action_pressed("crouch")), "um contato sobre shapes sobrepostas tem um único dono")
	touch(&"jump", 50, false)
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("crouch"), "release do contato sobreposto não deixa fonte órfã")
	hud.release_all()
	crouch.position = original
	var jump_original := jump.position
	jump.position = hud.joystick.position
	touch(&"jump", 50, true)
	check(Input.is_action_pressed("jump") and hud.joystick.output == Vector2.ZERO and hud.joystick.finger_index == -1, "botão sobre joystick tem uma única captura autorizada")
	touch(&"jump", 50, false)
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("move_right"), "sobreposição joystick/botão termina neutra")
	jump.position = jump_original
	touch(&"crouch", 51, true)
	jump.position = crouch.position
	touch(&"jump", 52, true)
	touch(&"jump", 52, false)
	check(Input.is_action_pressed("crouch") and not Input.is_action_pressed("jump"), "sobreposição não solta componente que pertence a outro dedo")
	touch(&"crouch", 51, false)
	jump.position = jump_original


func _test_duplicate_and_emulated_contacts() -> void:
	var before: int = press_counts.get(&"jump", 0)
	touch(&"jump", 90, true)
	touch(&"jump", 90, true)
	check(Input.is_action_pressed("jump") and int(press_counts.get(&"jump", 0)) == before + 1, "press duplicado do mesmo contato não repete pulo")
	touch(&"jump", 90, false)
	for release_emulated_first in [true, false]:
		stick_press(90, Vector2.RIGHT)
		var emulated := InputEventScreenTouch.new()
		emulated.index = 90
		emulated.device = InputEvent.DEVICE_ID_EMULATION
		emulated.pressed = true
		emulated.position = hud.buttons[&"jump"].position
		get_viewport().push_input(emulated, true)
		Input.flush_buffered_events()
		check(Input.is_action_pressed("move_right") and Input.is_action_pressed("jump"), "índices iguais de touchscreen e mouse emulado têm origens distintas")
		var foreign_drag := InputEventScreenDrag.new()
		foreign_drag.index = 90
		foreign_drag.device = InputEvent.DEVICE_ID_EMULATION
		foreign_drag.position = hud.joystick.position - Vector2(hud.joystick.max_radius, 0)
		get_viewport().push_input(foreign_drag, true)
		Input.flush_buffered_events()
		check(hud.joystick.output_x == 1.0, "arraste emulado não move joystick físico de mesmo índice")
		emulated = emulated.duplicate()
		emulated.pressed = false
		if release_emulated_first:
			get_viewport().push_input(emulated, true)
			Input.flush_buffered_events()
		else:
			touch(&"move_right", 90, false)
		check(Input.is_action_pressed("move_right") == release_emulated_first and Input.is_action_pressed("jump") != release_emulated_first, "liberar uma origem não solta a outra origem de índice igual")
		if release_emulated_first:
			touch(&"move_right", 90, false)
		else:
			get_viewport().push_input(emulated, true)
			Input.flush_buffered_events()
	_assert_neutral("origens e press duplicado")


func _test_joystick() -> void:
	stick_press(10, Vector2.ZERO)
	check(hud.joystick.finger_index == 10 and Input.get_axis("move_left", "move_right") == 0.0, "joystick captura no centro sem mover")
	stick_drag(10, Vector2(0.05, 0.05))
	check(hud.joystick.output == Vector2.ZERO and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("crouch"), "deadzone radial ignora deslocamento pequeno nos dois eixos")
	stick_drag(10, Vector2(0.5, 0.0))
	var expected: float = (0.5 - hud.joystick.deadzone) / (1.0 - hud.joystick.deadzone)
	check(is_equal_approx(Input.get_axis("move_left", "move_right"), expected), "força analógica remapeada após deadzone")
	player.velocity = Vector2.ZERO
	player._apply_horizontal_movement(1.0, expected, true, false)
	check(is_equal_approx(player.velocity.x, player.max_speed * expected), "Player preservado usa velocidade horizontal progressiva")
	stick_press(11, Vector2(-1.0, 0.0))
	stick_drag(11, Vector2(-3.0, 0.0))
	check(hud.joystick.finger_index == 10 and is_equal_approx(hud.joystick.output_x, expected), "segundo dedo não rouba nem move joystick")
	touch(&"move_left", 11, false)
	check(hud.joystick.finger_index == 10, "soltar outro dedo não libera dono")
	stick_drag(10, Vector2(-5.0, 5.0))
	check(is_equal_approx(Input.get_axis("move_left", "move_right"), -sqrt(0.5)) and Input.is_action_pressed("crouch"), "diagonal inferior esquerda limitada ao círculo move e agacha")
	stick_drag(10, Vector2(5.0, -5.0))
	check(is_equal_approx(Input.get_axis("move_left", "move_right"), sqrt(0.5)), "diagonal superior direita preserva força e limite circular")
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("crouch"), "eixo Y negativo não ativa pulo ou agachamento")
	stick_drag(10, Vector2.RIGHT)
	touch(&"jump", 12, true)
	touch(&"dash", 13, true)
	check(hud.joystick.finger_index == 10 and Input.is_action_pressed("jump") and Input.is_action_pressed("dash"), "três dedos mantêm joystick, pulo e dash simultaneamente")
	touch(&"jump", 12, false)
	touch(&"dash", 13, false)
	check(Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump") and not Input.is_action_pressed("dash"), "soltar botões de outros dedos preserva joystick")
	touch(&"crouch", 12, true)
	player._update_crouch(true)
	check(player.is_crouching and Input.get_axis("move_left", "move_right") == 1.0, "joystick e agachamento coexistem em dedos distintos")
	touch(&"crouch", 12, false)
	player._update_crouch(true)
	touch(&"move_right", 10, false)
	hud.joystick._process(1.0)
	check(hud.joystick.finger_index == -1 and hud.joystick.knob_position == Vector2.ZERO and Input.get_axis("move_left", "move_right") == 0.0, "soltar zera entrada e retorna visual ao centro")
	stick_press(10, Vector2.RIGHT, true)
	check(hud.joystick.finger_index == -1 and hud.joystick.output_x == 0.0, "cancelamento sem captura não vira novo movimento")
	stick_press(10, Vector2.RIGHT)
	stick_press(10, Vector2.RIGHT, true)
	check(hud.joystick.finger_index == -1 and not Input.is_action_pressed("move_right"), "cancelamento pressionado libera fonte e dono")
	stick_press(10, Vector2.RIGHT)
	check(hud.joystick.output_x == 1.0, "novo contato com índice cancelado funciona no primeiro toque")
	hud.hide()
	hud.show()
	stick_drag(10, Vector2.LEFT)
	check(hud.joystick.output_x == 0.0, "arraste de contato antigo não reativa após ocultar")
	stick_press(10, Vector2.LEFT)
	check(hud.joystick.output_x == -1.0, "novo press substitui contato antigo sem exigir toque extra")
	touch(&"move_left", 10, false)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	stick_press(10, Vector2(0.5, 0))
	await settle()
	touch(&"move_right", 10, false)
	check(Input.get_axis("move_left", "move_right") == 1.0 and not Input.is_action_just_pressed("move_right"), "liberar joystick preserva tecla física sem nova borda")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(Input.get_axis("move_left", "move_right") == 0.0, "soltar última fonte física encerra movimento")
	stick_press(10, Vector2(0.5, 0))
	key = key.duplicate()
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(is_equal_approx(Input.get_axis("move_left", "move_right"), expected), "liberar tecla física preserva força parcial do joystick")
	touch(&"move_right", 10, false)
	var isolated: TouchVirtualJoystick = preload("res://ui/touch_controls/virtual_joystick.tscn").instantiate()
	add_child(isolated)
	isolated.position = get_viewport().get_visible_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.index = 22
	press.pressed = true
	press.position = isolated.position + Vector2(isolated.max_radius, 0)
	get_viewport().push_input(press, true)
	Input.flush_buffered_events()
	check(isolated.finger_index == 22 and Input.is_action_pressed("move_right"), "joystick reutilizável funciona fora do HUD")
	isolated.free()
	Input.flush_buffered_events()
	check(not Input.is_action_pressed("move_right"), "destruir joystick isolado libera somente sua fonte")
	var canceled_button := InputEventScreenTouch.new()
	canceled_button.index = 23
	canceled_button.pressed = true
	canceled_button.canceled = true
	canceled_button.position = hud.buttons[&"jump"].position
	get_viewport().push_input(canceled_button, true)
	check(not Input.is_action_pressed("jump"), "cancelamento não capturado sobre botão não cria pulo fantasma")
	player.velocity = Vector2.ZERO
	await settle()


func _assert_neutral(label: String) -> void:
	Input.flush_buffered_events()
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"crouch", &"interact", &"pause"]:
		check(not Input.is_action_pressed(action), label + ": " + str(action) + " neutro")
	check(hud.joystick.finger_index == -1, label + ": joystick sem dono")
	for button: TouchActionButton in hud.buttons.values():
		check(button.finger_index == -1 and not button.is_pressed(), label + ": botão " + str(button.input_action) + " neutro")


func _drag_output_y(finger: int, value: float) -> void:
	var raw: float = signf(value) * (hud.joystick.deadzone + absf(value) * (1.0 - hud.joystick.deadzone)) if value != 0.0 else 0.0
	stick_drag(finger, Vector2(0, raw))


func _test_360_crouch() -> void:
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2(-1, 1), Vector2(1, 1), Vector2.UP, Vector2.ZERO, Vector2(0.05, 0.05)]:
		stick_press(60, direction.limit_length() * 0.9)
		# Arraste também para testar direção fora da área e clamp circular.
		stick_drag(60, direction * 3.0 if direction.length() > 0.2 else direction)
		var expected_crouch: bool = direction.y > 0.5
		var axis: float = Input.get_axis("move_left", "move_right")
		check(hud.joystick.output.length() <= 1.00001 and ((axis < 0.0) if direction.x < -0.2 else ((axis > 0.0) if direction.x > 0.2 else is_zero_approx(axis))), "360° normaliza e mapeia X em " + str(direction))
		check(Input.is_action_pressed("crouch") == expected_crouch and not Input.is_action_pressed("jump"), "360° baixo agacha e cima não pula: " + str(direction))
		player._update_crouch(true)
		check(player.is_crouching == expected_crouch, "colisão e estado de agachar continuam no Player: " + str(direction))
		player.velocity = Vector2.ZERO
		player._apply_horizontal_movement(1.0, axis, true, false)
		var speed: float = player.max_speed * (player.crouch_speed_multiplier if expected_crouch else 1.0)
		check(is_equal_approx(player.velocity.x, axis * speed), "diagonal usa velocidade reduzida original: " + str(direction))
		touch(&"move_right", 60, false)
		player._update_crouch(true)
	_assert_neutral("tabela 360°")
	stick_press(60, Vector2.ZERO)
	var presses_before := crouch_presses
	var releases_before := crouch_releases
	for value in [0.45, 0.55, 0.45, 0.55]:
		_drag_output_y(60, value)
		check(not Input.is_action_pressed("crouch"), "histerese inativa não liga com Y " + str(value))
	_drag_output_y(60, 0.60)
	check(Input.is_action_pressed("crouch"), "Y exatamente 0,60 ativa")
	for value in [0.55, 0.45, 0.55, 0.45]:
		_drag_output_y(60, value)
		check(Input.is_action_pressed("crouch"), "histerese ativa não desliga com Y " + str(value))
	_drag_output_y(60, 0.40)
	check(not Input.is_action_pressed("crouch") and crouch_presses == presses_before + 1 and crouch_releases == releases_before + 1, "Y exatamente 0,40 desliga sem alternâncias intermediárias")
	hud.joystick.crouch_activate_threshold = 0.8
	hud.joystick.crouch_release_threshold = 0.2
	_drag_output_y(60, 0.7)
	check(not Input.is_action_pressed("crouch"), "limiar ajustável 0,80 respeitado")
	_drag_output_y(60, 0.85)
	_drag_output_y(60, 0.3)
	check(Input.is_action_pressed("crouch"), "limiar ajustável 0,20 mantém estado")
	_drag_output_y(60, 0.2)
	check(not Input.is_action_pressed("crouch"), "limiar ajustável 0,20 libera")
	hud.joystick.crouch_activate_threshold = 0.6
	hud.joystick.crouch_release_threshold = 0.4
	stick_drag(60, Vector2.DOWN)
	player._update_crouch(true)
	touch(&"jump", 61, true)
	player._update_jump_buffer(0.0)
	check(player.is_crouching and player.jump_buffer_timer == 0.0 and not player._try_jump(true), "baixo + pulo respeita restrição de agachar do Player")
	touch(&"jump", 61, false)
	touch(&"move_right", 60, false)
	player._update_crouch(true)
	# As duas ordens de liberação de joystick e botão alternativo.
	for release_joystick_first in [true, false]:
		stick_press(60, Vector2.DOWN)
		touch(&"crouch", 61, true)
		await settle()
		if release_joystick_first:
			stick_drag(60, Vector2.ZERO)
		else:
			touch(&"crouch", 61, false)
		check(Input.is_action_pressed("crouch") and not Input.is_action_just_released("crouch"), "liberar primeira fonte crouch preserva outra sem borda falsa")
		if release_joystick_first:
			touch(&"crouch", 61, false)
		else:
			stick_drag(60, Vector2.ZERO)
		check(not Input.is_action_pressed("crouch"), "liberar última fonte crouch encerra estado")
		touch(&"move_right", 60, false)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_S
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	stick_press(60, Vector2.DOWN)
	touch(&"crouch", 61, true)
	await settle()
	hud.release_all()
	hud.release_all()
	Input.flush_buffered_events()
	check(Input.is_action_pressed("crouch") and not Input.is_action_just_released("crouch") and not Input.is_action_just_pressed("crouch"), "limpeza idempotente de fontes crouch não altera bordas da tecla S")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	touch(&"move_right", 60, false)
	touch(&"crouch", 61, false)
	_assert_neutral("fontes de agachamento")
	player.velocity = Vector2.ZERO
	await settle()


func _test_release_permutations() -> void:
	var actions: Array[StringName] = [&"move_right", &"jump", &"dash"]
	for order in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		for index in range(3):
			touch(actions[index], 70 + index, true)
		var held := [true, true, true]
		for index: int in order:
			touch(actions[index], 70 + index, false)
			held[index] = false
			for other in range(3):
				check(Input.is_action_pressed(actions[other]) == held[other], "release " + str(order) + " preserva estado de " + str(actions[other]))
		_assert_neutral("fim da ordem " + str(order))
	for iteration in range(20):
		queue_touch(&"jump", 70, true)
		queue_touch(&"dash", 71, true)
		queue_touch(&"jump", 70, false)
		queue_touch(&"dash", 71, false)
	Input.flush_buffered_events()
	_assert_neutral("20 pares rápidos no mesmo lote")
	touch(&"jump", 70, true)
	touch(&"dash", 71, true)
	var canceled := InputEventScreenTouch.new()
	canceled.index = 70
	canceled.canceled = true
	canceled.position = Vector2(-1000, -1000)
	get_viewport().push_input(canceled, true)
	Input.flush_buffered_events()
	check(not Input.is_action_pressed("jump") and Input.is_action_pressed("dash"), "cancelar pulo fora da área preserva dash do outro dedo")
	touch(&"dash", 71, false)
	for action in [&"jump", &"dash", &"crouch", &"interact"]:
		touch(action, 70, true)
		hud.hide()
		_assert_neutral("ocultar HUD segurando " + str(action))
		hud.show()
		touch(action, 70, false)
		check(not Input.is_action_pressed(action), "reabrir não restaura " + str(action))
	touch(&"jump", 70, true)
	hud.buttons[&"jump"].set_available(false)
	Input.flush_buffered_events()
	check(not Input.is_action_pressed("jump"), "desabilitar botão libera sua fonte")
	hud.buttons[&"jump"].set_available(true)
	touch(&"jump", 70, false)
	_assert_neutral("cancelamento e disponibilidade")
	await settle()


func _test_modals() -> void:
	dialogue_ui = preload("res://ui/dialogue/dialogue_ui.tscn").instantiate()
	add_child(dialogue_ui)
	var data := DialogueData.new()
	var line := DialogueLine.new()
	line.text = "Teste de diálogo touch."
	data.lines.append(line)
	touch(&"move_left", 0, true)
	touch(&"jump", 1, true)
	check(DialogueManager.start_dialogue(data), "diálogo abre")
	Input.flush_buffered_events()
	check(not hud.buttons_root.visible and not Input.is_action_pressed("move_left"), "diálogo oculta gameplay e solta movimento imediatamente")
	_assert_neutral("diálogo com dois dedos")
	touch(&"jump", 1, false)
	await settle()
	check(dialogue_ui.advance_button.visible, "diálogo oferece botão de toque")
	tap_control(dialogue_ui.advance_button)
	check(not dialogue_ui.is_typing and DialogueManager.is_active, "toque completa digitação")
	tap_control(dialogue_ui.advance_button)
	check(not DialogueManager.is_active and DialogueManager.blocks_interaction(), "toque final bloqueia interação no mesmo frame")
	await settle()
	var cancelled_drag := InputEventScreenDrag.new()
	cancelled_drag.index = 0
	cancelled_drag.position = hud.joystick.position
	get_viewport().push_input(cancelled_drag, true)
	check(not Input.is_action_pressed("move_left"), "dedo mantido durante diálogo não reativa movimento ao retornar")
	touch(&"move_left", 0, false)
	var inspection: InspectionUI = preload("res://ui/inspection/inspection_ui.tscn").instantiate()
	add_child(inspection)
	var content := InspectionData.new()
	content.title = "Teste"
	content.body = "Texto longo\n".repeat(200)
	check(inspection.open_content(content, target), "inspeção abre")
	check(not hud.buttons_root.visible and inspection.close_button.visible, "inspeção oferece fechamento e esconde gameplay")
	await settle()
	tap_control(inspection.close_button)
	check(not DialogueManager.inspection_active and DialogueManager.blocks_interaction(), "fechar inspeção bloqueia mesma entrada")
	await settle()
	var pause: CanvasLayer = preload("res://ui/pause_menu/pause_menu.tscn").instantiate()
	add_child(pause)
	touch(&"move_left", 0, true)
	touch(&"jump", 1, true)
	touch(&"crouch", 2, true)
	touch(&"pause", 5, true)
	check(get_tree().paused and pause.is_open and not hud.buttons_root.visible, "ação touch abre pausa existente")
	check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("pause"), "pausa solta todos os comandos")
	_assert_neutral("pausa com quatro contatos")
	touch(&"move_left", 0, false)
	touch(&"jump", 1, false)
	touch(&"crouch", 2, false)
	touch(&"pause", 5, false)
	await settle(4)
	tap_control(pause.resume_button)
	check(not get_tree().paused, "botão de UI retoma por toque")
	await settle()
	check(hud.buttons_root.visible, "HUD retorna após pausa")
	queue_touch(&"move_right", 0, true)
	queue_touch(&"jump", 1, true)
	queue_touch(&"pause", 5, true)
	queue_touch(&"pause", 5, false)
	queue_touch(&"jump", 1, false)
	queue_touch(&"move_right", 0, false)
	Input.flush_buffered_events()
	check(pause.is_open and get_tree().paused, "pause em lote abre uma vez sem fechar instantaneamente")
	_assert_neutral("pause e release no mesmo lote")
	await settle(4)
	tap_control(pause.resume_button)
	await settle()
	check(not get_tree().paused and hud.buttons_root.visible, "retomar lote de pause não restaura toques antigos")
	pause.free()
	inspection.free()
	dialogue_ui.free()


func _test_layout_and_lifecycle() -> void:
	for resolution in [Vector2i(640, 360), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(648, 1152)]:
		get_window().size = resolution
		await settle()
		hud._layout()
		var area: Rect2 = hud._safe_rect()
		var fits := true
		var distinct := true
		var list: Array = hud.buttons.values()
		for index in range(list.size()):
			var button: TouchActionButton = list[index]
			var radius: float = (button.base_diameter * 0.5 + button.touch_padding) * button.scale.x
			fits = fits and area.encloses(Rect2(button.position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
			for other: TouchActionButton in list.slice(index + 1):
				distinct = distinct and button.position.distance_to(other.position) > radius + (other.base_diameter * 0.5 + other.touch_padding) * other.scale.x
		var joystick_extent: float = hud.joystick.get_extent() * hud.joystick.scale.x
		fits = fits and area.encloses(Rect2(hud.joystick.position - Vector2.ONE * joystick_extent, Vector2.ONE * joystick_extent * 2.0))
		for button: TouchActionButton in list:
			var radius: float = (button.base_diameter * 0.5 + button.touch_padding) * button.scale.x
			distinct = distinct and button.position.distance_to(hud.joystick.position) > radius + joystick_extent
		check(fits and distinct, "botões dentro da viewport e separados em " + str(resolution))
		touch(&"move_right", 0, true)
		hud._layout()
		Input.flush_buffered_events()
		check(not Input.is_action_pressed("move_right") and hud.joystick.finger_index == -1, "recalcular layout não conserva deslocamento em " + str(resolution))
		touch(&"move_right", 0, false)
	get_window().size = Vector2i(1152, 648)
	await settle()
	touch(&"move_right", 0, true)
	check(Input.is_action_pressed("move_right"), "prepara entrada para troca de cena")
	var previous := get_tree().current_scene
	get_tree().current_scene = null
	hud.refresh_context()
	Input.flush_buffered_events()
	check(not Input.is_action_pressed("move_right") and not hud.buttons_root.visible, "intervalo entre cenas oculta HUD e limpa ação")
	get_tree().current_scene = previous
	touch(&"move_right", 0, false)
	await settle()
	interactor.nearby_interactables.clear()
	interactor._update_target()
	check(not hud.buttons[&"interact"].visible, "sem alvo botão contextual fica oculto")
	interactor.nearby_interactables.assign([target])
	interactor._update_target()
	# Remapeamento altera prompts físicos e mantém botão touch na ação original.
	var mappings := InputMap.action_get_events("jump")
	InputMap.action_erase_events("jump")
	touch(&"jump", 1, true)
	check(Input.is_action_pressed("jump"), "touch independe de atalhos físicos cadastrados")
	touch(&"jump", 1, false)
	for mapping in mappings:
		InputMap.action_add_event("jump", mapping)
	var behind_layer := CanvasLayer.new()
	var behind := Button.new()
	behind_layer.add_child(behind)
	add_child(behind_layer)
	behind.size = Vector2(100, 100)
	behind.position = hud.buttons[&"jump"].position - behind.size * 0.5
	var clicks: Array[int] = [0]
	behind.pressed.connect(func(): clicks[0] += 1)
	await settle()
	tap_control(behind)
	check(clicks[0] == 0 and not Input.is_action_pressed("jump"), "toque sobre gameplay não aciona Button atrás nem prende pulo")
	behind_layer.free()
	var requirement := FlagRequirement.new()
	requirement.flag_id = "touch_tests/locked"
	requirement.failure_message = "Precisa da chave"
	target.requirements.assign([requirement])
	target.invalidate_requirements()
	interactor._update_target()
	var before := interaction_count
	touch(&"interact", 2, true)
	touch(&"interact", 2, false)
	check(interaction_count == before and player.get_node("InteractionPrompt").action_label.text == "Precisa da chave", "interação touch bloqueada preserva requisito sem executar efeitos")
	target.requirements.clear()
	target.invalidate_requirements()


func _test_shared_physical_action() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	touch(&"jump", 1, true)
	await settle()
	touch(&"jump", 1, false)
	check(Input.is_action_pressed("jump"), "soltar touch preserva tecla física da mesma ação")
	check(not Input.is_action_just_pressed("jump"), "soltar touch não cria novo pulo com tecla física segurada")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(not Input.is_action_pressed("jump"), "última fonte física solta ação compartilhada")
	await settle()
	touch(&"jump", 1, true)
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await settle()
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(Input.is_action_pressed("jump"), "soltar tecla física preserva dedo da mesma ação")
	touch(&"jump", 1, false)
	check(not Input.is_action_pressed("jump"), "último dedo solta ação compartilhada")


func _test_devices() -> void:
	InputDeviceManager.set_touch_test_mode(false)
	check(not InputDeviceManager.touch_test_mode and not hud.buttons_root.visible and not Input.is_emulating_touch_from_mouse(), "desativar teste restaura desktop e emulação original")
	InputDeviceManager._use_controller(99)
	var motion := InputEventJoypadMotion.new()
	motion.axis_value = 0.1
	InputDeviceManager._input(motion)
	check(InputDeviceManager.controller_id == 99, "ruído de eixo não troca controle ativo")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(10, 0)
	InputDeviceManager._input(mouse)
	check(InputDeviceManager.current_device == "keyboard", "mouse físico restaura apresentação desktop")
	check(InputGlyphResolver.resolve(&"interact", "keyboard").texture != null, "atalho físico continua com ícone")
	InputDeviceManager.touchscreen_available = true
	InputDeviceManager._set_device("mobile")
	hud.refresh_context()
	check(hud.buttons_root.visible, "touch disponível sem controle")
	var bindings := InputMap.action_get_events("interact")
	stick_press(15, Vector2.RIGHT)
	touch(&"jump", 16, true)
	var joy := InputEventJoypadMotion.new()
	joy.device = 0
	joy.axis = JOY_AXIS_LEFT_X
	joy.axis_value = -0.8
	Input.parse_input_event(joy)
	Input.flush_buffered_events()
	check(not hud.buttons_root.visible and hud.joystick.finger_index == -1 and Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"), "usar gamepad solta joystick e botão preservando somente entrada física")
	joy = joy.duplicate()
	joy.axis_value = 0.0
	Input.parse_input_event(joy)
	Input.flush_buffered_events()
	InputDeviceManager.use_touch()
	touch(&"move_right", 15, false)
	touch(&"jump", 16, false)
	InputDeviceManager._use_controller(99)
	check(not hud.buttons_root.visible and InputDeviceManager.current_device == "controller", "gamepad em uso oculta HUD")
	InputDeviceManager.set_layout_override("nintendo")
	check(InputDeviceManager.get_controller_layout() == "nintendo", "layout manual preservado")
	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION
	emulated_mouse.pressed = true
	InputDeviceManager._input(emulated_mouse)
	check(InputDeviceManager.current_device == "controller", "mouse emulado não muda dispositivo")
	var screen := InputEventScreenTouch.new()
	screen.pressed = true
	InputDeviceManager._input(screen)
	check(hud.buttons_root.visible and InputDeviceManager.current_device == "mobile", "novo toque restaura HUD")
	InputDeviceManager._use_controller(99)
	InputDeviceManager._on_joy_connection_changed(99, false)
	check(hud.buttons_root.visible, "desconectar controle restaura touch")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_A
	InputDeviceManager._input(key)
	check(InputDeviceManager.current_device == "keyboard" and not hud.buttons_root.visible, "teclado físico no desktop recupera apresentação após touch")
	check(InputGlyphResolver.resolve(&"interact", "mobile").text == "Toque", "glyph touch preservado")
	check(InputMap.action_get_events("interact") == bindings, "alternância não altera Input Map")
	InputDeviceManager.set_layout_override("auto")
	InputDeviceManager.use_touch()


func _test_scene_transitions() -> void:
	# O runner permanece na raiz durante transições reais, sem gravar saves.
	get_tree().current_scene = null
	check(SaveManager.new_game("res://scenes/levels/interaction_demo.tscn"), "transição real aceita pela arquitetura de save")
	await settle(6)
	check(not SaveManager.is_loading() and hud.buttons_root.visible, "HUD acompanha nova fase após carregamento")
	touch(&"move_right", 0, true)
	touch(&"jump", 1, true)
	touch(&"crouch", 2, true)
	check(SaveManager.new_game("res://scenes/levels/interaction_demo.tscn"), "recarga real aceita")
	await settle(6)
	check(not Input.is_action_pressed("move_right") and InputDeviceManager.touch_controls == hud, "recarga solta entrada e reutiliza HUD")
	_assert_neutral("troca de cena com três contatos")
	touch(&"move_right", 0, false)
	touch(&"jump", 1, false)
	touch(&"crouch", 2, false)
	check(get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn") == OK, "menu principal carrega")
	await settle(6)
	check(not hud.buttons_root.visible, "menu principal oculta HUD após transição")
	var menu := get_tree().current_scene
	tap_control(menu.new_game_button)
	await settle(6)
	check(get_tree().current_scene != menu and not SaveManager.is_loading() and hud.buttons_root.visible, "novo jogo pelo menu funciona com toque em Button nativo")


func _test_hud_teardown() -> void:
	touch(&"move_right", 0, true)
	touch(&"jump", 1, true)
	touch(&"crouch", 2, true)
	hud.free()
	Input.flush_buffered_events()
	for action in [&"move_left", &"move_right", &"jump", &"dash", &"crouch", &"interact", &"pause"]:
		check(not Input.is_action_pressed(action), "destruir HUD encerra fonte " + str(action))
	InputDeviceManager._create_touch_controls()
	hud = InputDeviceManager.touch_controls
	await settle()
	check(InputDeviceManager.get_child_count() == 1 and hud.buttons_root.visible, "nova sessão do HUD é única e disponível")
	_assert_neutral("HUD reconstruído sem pressionamentos anteriores")
