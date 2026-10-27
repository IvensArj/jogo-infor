extends Node

const PLAYER: PackedScene = preload("res://gameplay/player/player.tscn")
const NPC: PackedScene = preload("res://gameplay/npc/npc.tscn")
const DELTA: float = 1.0 / 60.0

var checks: int = 0
var failures: int = 0
var fixture: Node2D
var player: CharacterBody2D
var ui: CanvasLayer
var dialogue: DialogueData
var finished_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FÍSICA/DIÁLOGO: " + label)


func tick(frames: int = 1) -> void:
	for frame in range(frames):
		await get_tree().physics_frame
		player._physics_process(DELTA)
		await get_tree().process_frame


func reset_player(position: Vector2 = Vector2(0, -200)) -> void:
	player.position = position
	player.velocity = Vector2.ZERO
	player.is_dashing = false
	player.dash_timer = 0.0
	player.dash_cooldown_timer = 0.0
	player.jump_buffer_timer = 0.0
	player.wall_jump_lock = 0.0
	player.air_dash_available = true
	player.move_and_slide()


func start_dash(direction: float = 1.0) -> void:
	Input.action_press("dash")
	player._try_start_dash(direction)
	Input.action_release("dash")


func make_body(position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	fixture.add_child(body)
	return body


func _run() -> void:
	fixture = Node2D.new()
	fixture.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fixture)
	player = PLAYER.instantiate()
	fixture.add_child(player)
	player.set_physics_process(false)
	ui = load("res://ui/dialogue/dialogue_ui.tscn").instantiate()
	fixture.add_child(ui)
	dialogue = DialogueData.new()
	var line := DialogueLine.new()
	line.text = "Conversa de teste."
	dialogue.lines.append(line)
	DialogueManager.dialogue_finished.connect(func(): finished_count += 1)
	make_body(Vector2(0, 10), Vector2(2000, 20))
	await tick()
	await _test_dash()
	await _test_dialogue_physics()
	await _test_control_inputs()
	await _test_npc()
	await _test_pause()
	DialogueManager.end_dialogue()
	fixture.free()
	print("Physics/dialogue tests: %d verificações, %d falhas." % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _test_dash() -> void:
	for vertical_speed in [250.0, -250.0]:
		reset_player(Vector2(0, -1000))
		player.velocity.y = vertical_speed
		start_dash()
		check(player.is_dashing and player.velocity.y == 0.0, "dash zera subida/queda no início")
		var origin := player.position
		await tick(5)
		check(is_equal_approx(player.position.y, origin.y), "dash mantém altura sem gravidade")
		check(is_equal_approx(player.velocity.x, player.dash_speed), "velocidade do dash preservada")
		check(player.position.x > origin.x, "dash desloca horizontalmente")
		while player.is_dashing:
			await tick()
		check(player.velocity.y > 0.0, "gravidade retorna ao expirar o dash")
		check(is_equal_approx(player.velocity.x, player.max_speed * player.dash_exit_speed), "velocidade de saída preservada")
		start_dash()
		check(not player.is_dashing, "cooldown impede repetição")
		await tick(35)
		start_dash()
		check(not player.is_dashing, "carga aérea não retorna com o cooldown")
		await tick(100)
		check(player.is_on_floor() and player.air_dash_available, "pouso restaura dash aéreo")
		start_dash(-1.0)
		check(player.is_dashing and player.dash_direction == -1.0, "novo dash após pouso e cooldown mantém direção")
		player._finish_dash()
	reset_player()
	var wall := make_body(Vector2(100, -200), Vector2(20, 500))
	await tick()
	start_dash()
	await tick(12)
	check(not player.is_dashing and player.position.x < 90.0, "parede interrompe dash sem atravessar colisão")
	check(player.dash_cooldown_timer > 0.0, "parede preserva cooldown")
	wall.free()


func _test_dialogue_physics() -> void:
	reset_player()
	player.velocity = Vector2(200, 150)
	player.jump_buffer_timer = player.jump_buffer_time
	check(DialogueManager.start_dialogue(dialogue), "diálogo automático compatível")
	check(player.velocity.y == 150.0 and player.jump_buffer_timer == 0.0, "início preserva queda e limpa pulo pendente")
	check(ui.panel.visible, "UI abre pelo sinal existente")
	for action in ["move_right", "jump", "dash", "crouch"]:
		Input.action_press(action)
	await tick(12)
	check(player.velocity.y > 150.0 and player.position.y > -200.0, "diálogo mantém gravidade e queda")
	check(is_zero_approx(player.velocity.x), "atrito existente freia durante diálogo")
	check(not player.is_dashing and not player.is_crouching and player.jump_buffer_timer == 0.0, "comandos bloqueados não geram estados temporários")
	await tick(80)
	check(player.is_on_floor() and player.air_dash_available, "diálogo mantém pouso e restauração de recursos")
	DialogueManager.end_dialogue()
	for action in ["move_right", "jump", "dash", "crouch"]:
		Input.action_release(action)
	await tick(2)
	check(player.is_on_floor() and player.jump_buffer_timer == 0.0, "fim do diálogo não provoca pulo acumulado")
	check(not ui.panel.visible, "UI fecha pelo sinal existente")
	Input.action_press("move_right")
	await tick(3)
	check(player.velocity.x > 0.0, "movimento retorna após diálogo")
	Input.action_release("move_right")
	reset_player()
	player.velocity.y = -200.0
	DialogueManager.start_dialogue(dialogue)
	await tick()
	check(player.velocity.y < 0.0 and player.velocity.y > -200.0, "diálogo durante subida preserva impulso com gravidade")
	DialogueManager.end_dialogue()
	await tick(2)
	reset_player()
	start_dash()
	var cooldown: float = player.dash_cooldown_timer
	DialogueManager.start_dialogue(dialogue)
	check(not player.is_dashing and player.dash_cooldown_timer == cooldown, "diálogo cancela dash sem eliminar cooldown")
	await tick()
	check(player.velocity.y > 0.0, "cancelar dash devolve gravidade")
	DialogueManager.end_dialogue()
	await tick(2)


func _interaction_event(controller: bool, pressed: bool) -> void:
	var event: InputEvent
	if controller:
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_Y
		button.pressed = pressed
		event = button
	else:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.pressed = pressed
		event = key
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _control_events(controller: bool, pressed: bool) -> void:
	for action in ["move_right", "jump", "dash", "crouch"]:
		for binding in InputMap.action_get_events(action):
			if (controller and binding is InputEventJoypadButton) or (not controller and binding is InputEventKey):
				var event: InputEvent = binding.duplicate()
				event.pressed = pressed
				Input.parse_input_event(event)
				break
	Input.flush_buffered_events()


func _test_control_inputs() -> void:
	for controller in [false, true]:
		reset_player(Vector2(0, -60))
		await tick(30)
		DialogueManager.start_dialogue(dialogue)
		_control_events(controller, true)
		await tick(3)
		check(player.is_on_floor() and is_zero_approx(player.velocity.x), "teclado/controle não move nem pula durante conversa no chão")
		check(not player.is_dashing and not player.is_crouching, "teclado/controle não inicia dash nem agachamento")
		DialogueManager.end_dialogue()
		await tick(2)
		check(player.velocity.y >= 0.0 and player.jump_buffer_timer == 0.0, "pulo segurado durante diálogo não dispara ao terminar")
		_control_events(controller, false)
		await tick(2)
		Input.action_press("crouch")
		await tick()
		check(player.is_crouching, "agachamento volta após conversa")
		Input.action_release("crouch")
		await tick()
		Input.action_press("jump")
		player._physics_process(DELTA)
		Input.action_release("jump")
		check(player.velocity.y < 0.0, "novo pulo funciona após conversa")
		await tick(2)


func _test_npc() -> void:
	for controller in [false, true]:
		reset_player(Vector2(0, -200))
		var npc: Interactable = NPC.instantiate()
		npc.dialogue = dialogue
		npc.position = Vector2(65, -200)
		fixture.add_child(npc)
		await tick(2)
		var interactor: Interactor = player.get_node("Interactor")
		var prompt: InteractionPrompt = player.get_node("InteractionPrompt")
		check(interactor.current_target == npc and prompt.visible, "NPC selecionado e indicador visível")
		_interaction_event(controller, true)
		_interaction_event(controller, false)
		check(DialogueManager.is_active and DialogueManager.get_dialogue_source() == npc, "E/Y inicia diálogo pelo Interactor e identifica NPC")
		check(not prompt.visible, "indicador oculto durante conversa")
		var starts_at: int = DialogueManager.started_frame
		interactor.try_interact()
		check(DialogueManager.started_frame == starts_at, "nova interação bloqueada durante diálogo")
		player.position = npc.position + Vector2(npc.dialogue_max_distance + 4.0, 0)
		DialogueManager._process(0.0)
		check(DialogueManager.is_active, "tolerância evita cancelamento perto do limite")
		player.position.x += npc.dialogue_distance_tolerance + 20.0
		DialogueManager._process(0.0)
		check(not DialogueManager.is_active and not ui.panel.visible, "distância encerra diálogo e fecha UI")
		check(DialogueManager.get_dialogue_source() == null, "origem é limpa ao encerrar")
		var before := finished_count
		DialogueManager.end_dialogue()
		check(finished_count == before, "encerramento repetido é seguro")
		player.position = npc.position
		interactor.try_interact()
		check(not DialogueManager.is_active, "quadro de encerramento não reabre conversa")
		npc.free()
		await tick(2)

	for removal in ["remove", "free", "queue_free", "disable"]:
		reset_player()
		var npc: Interactable = NPC.instantiate()
		npc.dialogue = dialogue
		npc.position = Vector2(65, -200)
		fixture.add_child(npc)
		await tick(2)
		player.get_node("Interactor").try_interact()
		check(DialogueManager.is_active, "prepara invalidação de NPC: " + removal)
		match removal:
			"remove": fixture.remove_child(npc)
			"free": npc.free()
			"queue_free": npc.queue_free()
			"disable": npc.enabled = false
		DialogueManager._process(0.0)
		check(not DialogueManager.is_active and not ui.panel.visible, "invalidação encerra conversa: " + removal)
		if is_instance_valid(npc) and not npc.is_queued_for_deletion():
			npc.free()
		await tick(2)

	reset_player()
	var input_npc: Interactable = NPC.instantiate()
	input_npc.dialogue = dialogue
	input_npc.position = Vector2(65, -200)
	fixture.add_child(input_npc)
	await tick(2)
	var input_interactor: Interactor = player.get_node("Interactor")
	input_interactor.try_interact()
	await tick(2)
	ui._finish_typing()
	_interaction_event(false, true)
	_interaction_event(false, false)
	check(not DialogueManager.is_active and not ui.panel.visible, "entrada final da UI encerra sem reabrir NPC")
	input_interactor.try_interact()
	check(not DialogueManager.is_active, "último comando da conversa não permite nova interação no mesmo quadro")
	await tick(2)
	input_interactor.try_interact()
	check(DialogueManager.is_active, "NPC volta a aceitar interação depois do quadro de encerramento")
	DialogueManager.end_dialogue()
	input_npc.free()
	await tick(2)

	check(DialogueManager.start_dialogue(dialogue), "diálogo sem origem continua disponível")
	player.position = Vector2(800, -300)
	await tick(2)
	check(DialogueManager.is_active and DialogueManager.get_dialogue_source() == null, "distância não cancela diálogo automático")
	DialogueManager.end_dialogue()
	await tick(2)
	var trigger: Area2D = load("res://gameplay/objects/dialogue_trigger/dialogue_trigger.tscn").instantiate()
	trigger.one_shot = false
	trigger.dialogue = dialogue
	fixture.add_child(trigger)
	trigger._on_body_entered(player)
	check(DialogueManager.is_active and DialogueManager.get_dialogue_source() == null, "gatilho automático mantém API e ausência de origem")
	trigger.free()
	check(DialogueManager.is_active, "remover gatilho não cancela diálogo automático")
	DialogueManager.end_dialogue()
	await tick(2)


func _test_pause() -> void:
	reset_player()
	# Nesta verificação a árvore, e não o runner, executa a física do jogador.
	player.set_physics_process(true)
	var menu: CanvasLayer = load("res://ui/pause_menu/pause_menu.tscn").instantiate()
	fixture.add_child(menu)
	for controller in [false, true]:
		var event: InputEvent
		if controller:
			var button := InputEventJoypadButton.new()
			button.button_index = JOY_BUTTON_START
			button.pressed = true
			event = button
		else:
			var key := InputEventKey.new()
			key.physical_keycode = KEY_ESCAPE
			key.pressed = true
			event = key
		menu._unhandled_input(event)
		check(get_tree().paused and menu.is_open, "Esc/Start abre pausa real")
		check(menu.resume_button.has_focus(), "pausa mantém foco para navegação")
		var origin := player.position
		for frame in range(5):
			await get_tree().process_frame
		check(player.position == origin, "jogador não cai durante pausa real")
		menu._unhandled_input(event)
		check(not get_tree().paused and not menu.is_open, "Esc/Start retoma jogo")
		for frame in range(3):
			await get_tree().physics_frame
		await get_tree().process_frame
		check(player.position.y > origin.y, "física retorna após pausa")
	player.set_physics_process(false)
	menu.free()
