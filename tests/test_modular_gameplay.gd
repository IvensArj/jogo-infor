extends Node

class WallProbe:
	extends "res://gameplay/player/player.gd"
	var test_wall_side: int = 0
	func _get_wall_side() -> int:
		return test_wall_side

class FailingEffect:
	extends InteractionEffect
	func execute(_actor: Node2D, _source: Node2D) -> bool:
		return false

var checks: int = 0
var failures: int = 0
var fixture: Node2D
var player: CharacterBody2D
var inspection_ui: InspectionUI
var first_reads: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("SISTEMAS MODULARES: " + label)


func frames(count: int = 2) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func send_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func send_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func click_control(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	get_viewport().push_input(event, true)
	Input.flush_buffered_events()


func make_dialogue() -> DialogueData:
	var data := DialogueData.new()
	var line := DialogueLine.new()
	line.text = "Diálogo temporário de teste."
	data.lines.append(line)
	return data


func _run() -> void:
	var original := GameState.export_data()
	fixture = Node2D.new()
	fixture.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fixture)
	player = load("res://gameplay/player/player.tscn").instantiate()
	fixture.add_child(player)
	player.position = Vector2(0, -200)
	player.set_physics_process(false)
	inspection_ui = load("res://ui/inspection/inspection_ui.tscn").instantiate()
	fixture.add_child(inspection_ui)
	await _test_inspection()
	_test_abilities()
	_test_conditions()
	await _test_actions()
	await _test_triggers_and_puzzle()
	fixture.free()
	GameState.import_data(original)
	print("Modular tests: %d verificações, %d falhas." % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _test_inspection() -> void:
	var previous_button := Button.new()
	previous_button.text = "Foco anterior de teste"
	fixture.add_child(previous_button)
	previous_button.grab_focus()
	var document: Inspectable = load("res://gameplay/objects/inspectable/inspectable.tscn").instantiate()
	document.persistent_id = "modular_tests/document"
	document.first_read_event_id = "modular_tests/first_read"
	document.content = InspectionData.new()
	document.content.title = "Carta de teste"
	document.content.body = "Texto longo de verificação.\n".repeat(120)
	document.position = Vector2(65, -200)
	document.first_read.connect(func(_actor: Node2D): first_reads += 1)
	fixture.add_child(document)
	await frames()
	send_key(KEY_E)
	check(DialogueManager.inspection_active and inspection_ui.panel.visible, "E abre inspeção pelo Interactor")
	check(inspection_ui.title_label.text == document.content.title and inspection_ui.body_label.text == document.content.body, "conteúdo compartilhado carregado sem truncamento")
	check(not inspection_ui.image_view.visible and inspection_ui.scroll.has_focus(), "imagem opcional oculta e foco nativo recebido")
	send_key(KEY_E)
	check(DialogueManager.inspection_active, "entrada de abertura não fecha no mesmo quadro")
	check(not DialogueManager.start_dialogue(make_dialogue()), "diálogo bloqueado durante inspeção")
	var menu: CanvasLayer = load("res://ui/pause_menu/pause_menu.tscn").instantiate()
	fixture.add_child(menu)
	menu.open_menu()
	check(not menu.is_open and not get_tree().paused, "inspeção não permite pausa concorrente")
	player.velocity = Vector2(100, 120)
	Input.action_press("move_right")
	Input.action_press("jump")
	player._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	Input.action_release("jump")
	check(player.velocity.y > 120 and player.velocity.x < 100, "inspeção preserva gravidade e atrito sem comandos")
	await frames(3)
	send_button(JOY_BUTTON_DPAD_DOWN)
	check(inspection_ui.scroll.scroll_vertical > 0, "controle rola documento longo")
	var previous_scroll := inspection_ui.scroll.scroll_vertical
	send_key(KEY_DOWN)
	check(inspection_ui.scroll.scroll_vertical > previous_scroll, "teclado rola documento longo")
	send_button(JOY_BUTTON_B)
	check(not DialogueManager.inspection_active and not inspection_ui.panel.visible, "B fecha inspeção")
	check(previous_button.has_focus(), "fechamento restaura foco anterior")
	check(GameState.is_event_complete(document.persistent_id) and GameState.is_event_complete(document.first_read_event_id), "primeira abertura registra leitura e evento")
	await frames()
	check(document.interact(player), "reabrir documento é permitido")
	check(first_reads == 1, "primeira leitura não repete sinal")
	await frames()
	click_control(inspection_ui.close_button)
	check(not DialogueManager.inspection_active, "mouse aciona botão Fechar")
	await frames()
	check(document.interact(player), "documento reabre após fechar pelo mouse")
	await frames()
	send_key(KEY_ESCAPE)
	check(not DialogueManager.inspection_active, "Esc fecha inspeção")
	await frames()
	DialogueManager.start_dialogue(make_dialogue())
	check(not document.interact(player), "inspeção bloqueada durante diálogo")
	DialogueManager.end_dialogue()
	await frames()
	var blocking_effect := StartDialogueEffect.new()
	blocking_effect.dialogue = make_dialogue()
	document.effects.assign([blocking_effect])
	check(not document.interact(player) and not DialogueManager.inspection_active, "falha ao abrir inspeção após efeito conflitante é propagada")
	document.effects.clear()
	DialogueManager.end_dialogue()
	await frames()
	check(document.interact(player), "inspeção reabre após diálogo")
	document.enabled = false
	DialogueManager._process(0.0)
	check(not DialogueManager.inspection_active, "desabilitar fonte fecha interface")
	document.enabled = true
	await frames()
	check(document.interact(player), "fonte reabilitada volta a abrir")
	document.queue_free()
	await frames()
	check(not DialogueManager.inspection_active and not inspection_ui.panel.visible, "fonte excluída fecha inspeção")
	menu.free()
	previous_button.free()


func _test_abilities() -> void:
	var profile := AbilityProfile.new()
	profile.dash = false
	profile.double_jump = false
	profile.wall_jump = false
	GameState.apply_ability_profile(profile)
	check(not GameState.has_ability("dash") and not GameState.has_ability("double_jump") and not GameState.has_ability("wall_jump"), "perfil bloqueia as três habilidades")
	Input.action_press("dash")
	player._try_start_dash(1.0)
	Input.action_release("dash")
	check(not player.is_dashing, "dash bloqueado não inicia")
	player.floor_jump_available = false
	player.air_jumps_left = 1
	player.jump_buffer_timer = 1.0
	check(not player._try_jump(false), "segundo pulo bloqueado")
	player.floor_jump_available = true
	check(player._try_jump(true), "pulo normal continua disponível com habilidades bloqueadas")
	var probe := WallProbe.new()
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = RectangleShape2D.new()
	probe.add_child(collision)
	fixture.add_child(probe)
	probe.set_physics_process(false)
	probe.floor_jump_available = false
	probe.air_jumps_left = 0
	probe.test_wall_side = 1
	probe.jump_buffer_timer = 1.0
	check(not probe._try_jump(false), "pulo de parede bloqueado")
	var unlocks: Array[String] = []
	var on_unlock := func(id: String): unlocks.append(id)
	GameState.ability_unlocked.connect(on_unlock)
	for id in GameState.ABILITY_IDS:
		check(GameState.unlock_ability(id) and not GameState.unlock_ability(id), "desbloqueio único: " + id)
	check(unlocks.size() == 3 and not GameState.unlock_ability("inexistente"), "sinal não repete e ID desconhecido é rejeitado")
	Input.action_press("dash")
	player._try_start_dash(1.0)
	Input.action_release("dash")
	check(player.is_dashing, "dash desbloqueado funciona")
	player._finish_dash()
	player.jump_buffer_timer = 1.0
	check(player._try_jump(false) and player.velocity.y < 0.0, "segundo pulo desbloqueado funciona")
	check(probe._try_jump(false), "pulo de parede desbloqueado funciona")
	probe.jump_buffer_timer = 1.0
	check(not probe._try_jump(false), "mesma parede não permite escalada infinita")
	probe.test_wall_side = -1
	check(probe._try_jump(false) and probe.velocity.x < 0.0, "parede oposta permite pulo")
	probe.test_wall_side = 1
	probe.velocity.y = 180.0
	probe._update_wall_slide(1.0 / 60.0, -1.0)
	check(probe.velocity.y == probe.wall_slide_speed, "deslize de parede mantém limite existente")
	var saved := GameState.export_data()
	GameState.reset_progress()
	check(GameState.has_ability("dash") and GameState.has_ability("double_jump") and GameState.has_ability("wall_jump"), "nova partida preserva perfil legado completo")
	GameState.import_data(saved)
	check(unlocks.size() == 3 and GameState.has_ability("dash"), "restauração não repete desbloqueios")
	GameState.ability_unlocked.disconnect(on_unlock)
	probe.free()
	player.velocity = Vector2.ZERO
	player.jump_buffer_timer = 0.0


func _test_conditions() -> void:
	check(InteractionRequirement.new().is_met(player), "condição sempre verdadeira")
	var flag := FlagRequirement.new()
	flag.flag_id = "modular_tests/missing"
	flag.expected_value = false
	check(flag.is_met(player), "flag válida ausente vale false")
	flag.flag_id = " "
	check(not flag.is_met(player), "ID inválido não satisfaz flag false")
	flag.flag_id = "modular_tests/flag"
	flag.expected_value = true
	GameState.set_flag(flag.flag_id, true)
	check(flag.is_met(player), "flag verdadeira")
	var item := ItemRequirement.new()
	item.item_id = "modular_tests/item"
	check(not item.is_met(player), "item ausente bloqueia")
	GameState.collect_item(item.item_id)
	check(item.is_met(player), "item coletado permite")
	var event := EventRequirement.new()
	event.event_id = "modular_tests/event"
	GameState.complete_event(event.event_id)
	check(event.is_met(player), "evento completo")
	var ability := AbilityRequirement.new()
	ability.ability_id = "dash"
	check(ability.is_met(player), "condição de habilidade")
	var all := ConditionGroup.new()
	var any := ConditionGroup.new()
	any.mode = ConditionGroup.Mode.ANY
	check(all.is_met(player) and not any.is_met(player), "ALL vazio true e ANY vazio false")
	any.conditions.assign([flag, item])
	all.conditions.assign([any, event, ability])
	var before := GameState.export_data()
	check(all.is_met(player) and any.is_met(player), "grupos ALL/ANY aninhados")
	check(GameState.export_data() == before, "avaliação não modifica estado")
	any.conditions.append(all)
	check(not all.is_met(player), "ciclo indireto interrompe avaliação inteira")
	any.conditions.clear()
	all.conditions.clear()
	all.conditions.append(null)
	check(not all.is_met(player), "condição ausente é rejeitada")
	all.conditions.clear()
	all.conditions.append(all)
	check(not all.is_met(player), "ciclo direto é rejeitado")
	all.conditions.clear()
	check(ConditionGroup.new().is_met(player), "avaliação posterior é independente do ciclo anterior")


func _test_actions() -> void:
	var source := Interactable.new()
	fixture.add_child(source)
	var flag := SetFlagEffect.new()
	flag.flag_id = "modular_tests/action_flag"
	var item := CollectItemEffect.new()
	item.item_id = "modular_tests/action_item"
	var event := CompleteEventEffect.new()
	event.event_id = "modular_tests/action_event"
	var unlock := UnlockAbilityEffect.new()
	unlock.ability_id = "dash"
	source.effects.assign([flag, item, event, unlock])
	check(source.interact(player), "ações existentes e desbloqueio executam em sequência")
	var before := GameState.export_data()
	check(source.interact(player) and GameState.export_data() == before, "recompensas repetidas são idempotentes")
	var invalid := CollectItemEffect.new()
	source.effects.assign([flag, invalid])
	GameState.set_flag(flag.flag_id, false)
	check(not source.interact(player) and not GameState.get_flag(flag.flag_id), "preflight inválido impede primeira ação")
	source.effects.assign([flag, FailingEffect.new()])
	check(not source.interact(player) and GameState.get_flag(flag.flag_id), "falha parcial é reportada sem alegar rollback")
	var door: FlagDoor = load("res://gameplay/objects/door/flag_door.tscn").instantiate()
	door.name = "ActionDoor"
	door.persistent_id = "modular_tests/action_door"
	door.state_flag = "modular_tests/action_door_open"
	fixture.add_child(door)
	var activate := ActivateMechanismEffect.new()
	activate.target_path = source.get_path_to(door)
	check(activate.validate_context(player, source) and activate.execute(player, source), "mecanismo é ativado pela interface tipada")
	await frames()
	check(door.activated and door.get_node("DoorBody/CollisionShape2D").disabled, "mecanismo atualiza visual e colisão")
	activate.target_path = NodePath("ausente")
	check(not activate.execute(player, source), "alvo ausente falha com segurança")
	var start := StartDialogueEffect.new()
	start.dialogue = make_dialogue()
	check(start.execute(player, source) and not start.execute(player, source), "ação de diálogo respeita interface bloqueante")
	DialogueManager.end_dialogue()
	await frames()
	source.free()
	door.free()


func _test_triggers_and_puzzle() -> void:
	var trigger: GameplayEventTrigger = load("res://gameplay/objects/event_trigger/event_trigger.tscn").instantiate()
	trigger.position = Vector2(1000, 0)
	trigger.persistent_completion = true
	trigger.event_id = "modular_tests/trigger"
	var condition := FlagRequirement.new()
	condition.flag_id = "modular_tests/permission"
	condition.failure_message = "Leia a carta primeiro."
	trigger.condition = condition
	var reward := CollectItemEffect.new()
	reward.item_id = "modular_tests/reward"
	trigger.effects.assign([reward])
	fixture.add_child(trigger)
	check(not trigger.interact(player) and not GameState.has_item(reward.item_id), "gatilho bloqueado não recompensa")
	check(trigger.get_block_reason(player) == condition.failure_message, "gatilho mostra mensagem de condição")
	GameState.set_flag(condition.flag_id, true)
	trigger.effects.assign([FailingEffect.new()])
	check(not trigger.interact(player) and not GameState.is_event_complete(trigger.event_id), "ação com falha não conclui evento")
	trigger.effects.assign([reward])
	check(trigger.interact(player) and GameState.is_event_complete(trigger.event_id), "gatilho interativo conclui após recompensa")
	check(not trigger.interact(player), "gatilho persistente não repete")
	var saved := GameState.export_data()
	GameState.reset_progress()
	GameState.import_data(saved)
	check(trigger.has_interacted and GameState.has_item(reward.item_id), "estado persistente reaplicado sem recompensa")
	trigger.free()
	var area: GameplayEventTrigger = load("res://gameplay/objects/event_trigger/event_trigger.tscn").instantiate()
	area.position = Vector2(1000, 0)
	area.activation_mode = GameplayEventTrigger.ActivationMode.AREA_ENTRY
	area.one_shot = true
	var flag := SetFlagEffect.new()
	flag.flag_id = "modular_tests/area"
	area.effects.assign([flag])
	fixture.add_child(area)
	SaveManager.set("_loading", true)
	area.body_entered.emit(player)
	SaveManager.set("_loading", false)
	check(not GameState.get_flag(flag.flag_id), "entrada em área durante carga ignora ações")
	area.position = player.position
	await frames(3)
	check(GameState.get_flag(flag.flag_id) and area.has_interacted, "entrada física real ativa gatilho de área")
	check(not area.can_select(player) and not area.interact(player), "área não oferece prompt e one-shot não repete")
	area.free()
