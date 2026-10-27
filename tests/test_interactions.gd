extends Node

class CountingRequirement:
	extends InteractionRequirement
	var calls: int = 0
	func is_met(_actor: Node2D) -> bool:
		calls += 1
		return true

class ProbeEffect:
	extends InteractionEffect
	var callback: Callable
	func execute(actor: Node2D, source: Node2D) -> bool:
		callback.call(actor, source)
		return true

const DEMO: String = "res://scenes/levels/interaction_demo.tscn"
var checks: int = 0
var failures: int = 0
var success_count: int = 0
var denied_count: int = 0
var manager: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("INTERACTION TEST: " + label)


func settle() -> void:
	for frame in range(60):
		await get_tree().process_frame
		if not manager.is_loading():
			await get_tree().process_frame
			return
	check(false, "transição terminou")


func _run() -> void:
	manager = load("res://systems/save/save_manager.gd").new()
	var directory: String = "user://interaction_tests_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "diretório isolado")
	manager.save_path = directory.path_join("save.json")
	manager.temp_path = directory.path_join("save.tmp")
	manager.backup_path = directory.path_join("save.bak")
	manager.backup_temp_path = directory.path_join("backup.tmp")
	add_child(manager)
	check(manager.new_game(DEMO), "demo válida")
	await settle()
	var scene: Node = get_tree().current_scene
	var player: Node2D = scene.get_node("Player")
	player.set_physics_process(false)
	var door: FlagDoor = scene.get_node("Door")
	var lever: FlagLever = scene.get_node("Lever")
	var interactor: Interactor = player.get_node("Interactor")
	var prompt: InteractionPrompt = player.get_node("InteractionPrompt")
	interactor.set_physics_process(false)
	interactor.nearby_interactables.assign([door])
	interactor.interaction_performed.connect(func(_target: Interactable): success_count += 1)
	door.interaction_denied.connect(func(_actor: Node2D, _reason: String): denied_count += 1)
	interactor._update_target()
	check(prompt.action_label.text == "Ative a alavanca primeiro.", "prompt bloqueado")
	interactor.try_interact()
	check(success_count == 0 and denied_count == 1, "bloqueio não emite sucesso")
	check(not GameState.get_flag(door.state_flag) and not door.has_interacted, "bloqueio não altera mundo")
	door.show_when_locked = false
	interactor._update_target()
	check(interactor.current_target == null and not prompt.visible, "ocultar bloqueado")
	door.show_when_locked = true
	interactor._update_target()
	check(lever.interact(player), "alavanca executa")
	check(GameState.get_flag(lever.state_flag) and not lever.can_select(player), "alavanca persistente não selecionável")
	check(prompt.action_label.text == "Abrir porta", "prompt atualiza sem sair da área")
	check(not lever.interact(player), "alavanca não repete")
	interactor.try_interact()
	await get_tree().process_frame
	check(success_count == 1 and door.activated, "porta emite sucesso")
	check(not door.get_node("DoorVisual").visible, "sprite oculto")
	check(door.get_node("DoorBody/CollisionShape2D").disabled, "colisão adiada desativada")
	check(not prompt.visible, "prompt some ao concluir")
	check(manager.save_game(), "salvar puzzle")
	check(manager.new_game(DEMO), "nova partida")
	await settle()
	scene = get_tree().current_scene
	check(not scene.get_node("Door").activated and not scene.get_node("Lever").activated, "novo jogo restaura objetos")
	check(not scene.get_node("Door/DoorBody/CollisionShape2D").disabled, "nova partida restaura colisão")
	check(manager.continue_game(), "continuar")
	await settle()
	scene = get_tree().current_scene
	check(scene.get_node("Door").activated and scene.get_node("Lever").activated, "save restaura ambos")
	check(scene.get_node("Door/DoorBody/CollisionShape2D").disabled, "save restaura colisão")
	player = scene.get_node("Player")
	player.set_physics_process(false)
	await _test_resources(player)
	await _test_selection_and_input(player)
	await _test_lifecycle(player)
	for path in [manager.save_path, manager.temp_path, manager.backup_path, manager.backup_temp_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("Interaction tests: %d verificações, %d falhas." % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _test_resources(player: Node2D) -> void:
	var target: Interactable = Interactable.new()
	add_child(target)
	var flag: FlagRequirement = FlagRequirement.new()
	flag.expected_value = false
	for id in ["", " bad", "bad\n", "bad\t"]:
		flag.flag_id = id
		check(not flag.is_met(player), "ID inválido não satisfaz false")
	flag.flag_id = "tests/unset"
	check(flag.is_met(player), "flag ausente válida equivale a false")
	var item: ItemRequirement = ItemRequirement.new()
	item.item_id = "tests/key"
	var event: EventRequirement = EventRequirement.new()
	event.event_id = "tests/story"
	target.requirements.assign([flag, item, event])
	check(not target.interact(player), "AND bloqueia")
	var collect: CollectItemEffect = CollectItemEffect.new()
	collect.item_id = item.item_id
	var complete: CompleteEventEffect = CompleteEventEffect.new()
	complete.event_id = event.event_id
	check(collect.execute(player, target) and complete.execute(player, target), "efeitos item e evento")
	check(target.interact(player), "AND libera")
	var counter: CountingRequirement = CountingRequirement.new()
	target.requirements.assign([counter])
	target.invalidate_requirements()
	for index in range(20):
		target.can_interact(player)
	check(counter.calls == 1, "cache evita consultas por frame")
	GameState.set_flag("tests/cache", true)
	target.can_interact(player)
	check(counter.calls == 2, "progresso invalida cache")
	var valid: SetFlagEffect = SetFlagEffect.new()
	valid.flag_id = "tests/preflight"
	var invalid: SetFlagEffect = SetFlagEffect.new()
	target.effects.assign([valid, invalid])
	check(not target.interact(player) and not GameState.get_flag(valid.flag_id), "preflight antes de qualquer efeito")
	target.effects.assign([valid, valid])
	var notifications: Array[int] = [0]
	var listener: Callable = func(): notifications[0] += 1
	GameState.progress_changed.connect(listener)
	check(target.interact(player) and notifications[0] == 1, "efeitos de progresso idempotentes")
	GameState.progress_changed.disconnect(listener)
	SaveManager.set("_loading", true)
	check(not target.interact(player), "interação bloqueada durante carga")
	SaveManager.set("_loading", false)
	var first: ProbeEffect = ProbeEffect.new()
	var second: ProbeEffect = ProbeEffect.new()
	var order: Array[int] = []
	first.callback = func(_actor: Node2D, _source: Node2D): order.append(1)
	second.callback = func(_actor: Node2D, _source: Node2D): order.append(2)
	target.effects.assign([first, second])
	check(target.interact(player) and order == [1, 2], "ordem dos efeitos")
	target.free()
	await get_tree().process_frame


func _test_selection_and_input(player: Node2D) -> void:
	var interactor: Interactor = player.get_node("Interactor")
	interactor.set_physics_process(false)
	var a: Interactable = Interactable.new()
	var b: Interactable = Interactable.new()
	add_child(a)
	add_child(b)
	a.global_position = player.global_position + Vector2(20, 0)
	b.global_position = player.global_position + Vector2(-20, 0)
	interactor.nearby_interactables.assign([a, b])
	interactor.facing_direction = 1
	interactor._update_target()
	check(interactor.current_target == a, "direção favorece alvo à frente")
	b.selection_priority = 5
	interactor._update_target()
	check(interactor.current_target == b, "prioridade preservada")
	b.selection_priority = 0
	interactor._update_target()
	check(interactor.current_target == b, "margem estabiliza foco")
	interactor.nearby_interactables.assign([a])
	var count: Array[int] = [0]
	a.interacted.connect(func(_actor: Node2D): count[0] += 1)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	interactor._unhandled_input(key)
	var joy: InputEventJoypadButton = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_Y
	joy.pressed = true
	interactor._unhandled_input(joy)
	check(count[0] == 2, "teclado e controle via Input Map")
	for layout in ["xbox", "playstation"]:
		check(InputGlyphResolver.resolve(&"interact", "controller", layout).get("texture") != null, "ícone " + layout)
	check(InputGlyphResolver.resolve(&"interact", "controller", "nintendo").get("text") == "X", "fallback Nintendo existente")
	check(InputGlyphResolver.resolve(&"interact", "keyboard").get("texture") != null, "ícone teclado")
	a.enabled = false
	interactor._update_target()
	check(interactor.current_target == null, "desabilitado perde foco")
	a.enabled = true
	interactor._update_target()
	a.free()
	interactor._update_target()
	check(interactor.current_target == null, "alvo liberado perde foco sem referência inválida")
	b.free()
	await get_tree().process_frame


func _test_lifecycle(player: Node2D) -> void:
	var target: Interactable = Interactable.new()
	add_child(target)
	var effect: ProbeEffect = ProbeEffect.new()
	var nested: Array[bool] = []
	effect.callback = func(actor: Node2D, source: Node2D): nested.append(source.interact(actor))
	target.effects.assign([effect])
	check(target.interact(player) and nested == [false], "reentrância bloqueada")
	effect.callback = func(_actor: Node2D, source: Node2D): source.queue_free()
	check(not target.interact(player), "remoção durante efeito interrompe sucesso")
	await get_tree().process_frame
	target = Interactable.new()
	add_child(target)
	effect = ProbeEffect.new()
	var disposable_actor: Node2D = Node2D.new()
	add_child(disposable_actor)
	effect.callback = func(actor: Node2D, _source: Node2D): actor.free()
	target.effects.assign([effect])
	check(not target.interact(disposable_actor), "personagem removido durante efeito")
	target.free()
	var scene: Node = get_tree().current_scene
	var door: FlagDoor = scene.get_node("Door")
	GameState.reset_progress()
	GameState.set_flag(door.state_flag, true)
	GameState.reset_progress()
	await get_tree().process_frame
	check(not door.activated and not door.get_node("DoorBody/CollisionShape2D").disabled, "último estado do frame prevalece")
	var original_id: String = door.persistent_id
	door.persistent_id = scene.get_node("Lever").persistent_id
	check(not manager._validate_scene(scene), "IDs duplicados rejeitados")
	door.persistent_id = original_id
	door.state_flag = ""
	check(not manager._validate_scene(scene) and not door.can_select(player), "flag persistente inválida rejeitada")
