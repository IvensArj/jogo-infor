extends Node

class Probe:
	extends Node
	var applied := 0
	var target: Node
	var free_target := false

	func apply_persistent_state() -> void:
		applied += 1
		if is_instance_valid(target):
			if free_target:
				target.free()
			else:
				target.queue_free()


const Manager = preload("res://tests/failing_manager.gd")
const LEVEL := "res://tests/level.tscn"
const OTHER := "res://tests/other.tscn"
const RENAMED := "res://tests/renamed.tscn"
const BROKEN := "res://tests/broken_ready.tscn"
const ITEM_ID := "test_level/coin_001"
const EVENT_ID := "test_level/intro"

var manager: Node
var checks := 0
var failures := 0
var signals := {"saved": [], "loaded": 0, "failed": 0, "finished": []}
var directory: String
var expected := {"position": Vector2(8, 9), "collected": false, "event": false}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# O runner fica vivo enquanto as cenas de teste são substituídas.
	get_tree().current_scene = null
	_run.call_deferred()


func _run() -> void:
	# A instância real de SaveManager deve permanecer ociosa e seus arquivos
	# não podem ser alterados pela instância com falhas injetadas.
	var original_pending := SaveManager.pending_save.duplicate(true)
	var original_signals := [0]
	SaveManager.game_saved.connect(func(_ok: bool): original_signals[0] += 1)
	SaveManager.game_loaded.connect(func(): original_signals[0] += 1)
	SaveManager.transition_finished.connect(func(_ok: bool): original_signals[0] += 1)
	var original_files: Dictionary = {}
	for path in [SaveManager.save_path, SaveManager.temp_path, SaveManager.backup_path, SaveManager.backup_temp_path]:
		original_files[path] = _file_fingerprint(path)

	directory = "user://save_tests_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "diretório isolado")
	manager = Manager.new()
	manager.save_path = directory.path_join("savegame.json")
	manager.temp_path = directory.path_join("savegame.tmp")
	manager.backup_path = directory.path_join("savegame.bak")
	manager.backup_temp_path = directory.path_join("savegame.bak.tmp")
	manager.game_saved.connect(func(ok: bool): signals.saved.append(ok))
	manager.game_loaded.connect(_on_loaded)
	manager.save_failed.connect(func(_message: String): signals.failed += 1)
	manager.transition_finished.connect(func(ok: bool): signals.finished.append(ok))
	add_child(manager)
	await _test_reading()
	_test_world_validation()
	_test_skipped_objects()
	await _test_real_object_guards()
	await _test_disk()
	await _test_restore_cycle()
	await _test_rollback()
	await _test_ids()
	_check(original_signals[0] == 0, "autoload original não executa transições ou saves dos testes")
	_check(not SaveManager.is_loading() and SaveManager.pending_save == original_pending, "autoload original preserva pendência e estado de transição")
	for path in original_files:
		_check(_file_fingerprint(path) == original_files[path], "save real preservado: " + path)
	get_tree().paused = false
	_clear_files()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("Save tests: %d verificações, %d falhas." % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TESTE: " + label)


func _on_loaded() -> void:
	signals.loaded += 1
	var scene := get_tree().current_scene
	_check(scene.get_node("Player").global_position == expected.position, "posição pronta em game_loaded")
	var coin := scene.find_child("Coin", true, false)
	var trigger := scene.find_child("Trigger", true, false)
	if coin == null:
		coin = scene.get_node("Container/RenamedCoin")
		trigger = scene.get_node("Container/RenamedTrigger")
	_check(coin.visible == not expected.collected and coin.monitoring == not expected.collected, "coletável pronto em game_loaded")
	_check(trigger.already_triggered == expected.event, "evento pronto em game_loaded")


func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "abrir fixture: " + path)
	if file == null:
		return
	file.store_string(value if value is String else JSON.stringify(value))
	file.close()


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _file_fingerprint(path: String) -> Dictionary:
	var exists := FileAccess.file_exists(path)
	return {"exists": exists, "sha256": FileAccess.get_sha256(path) if exists else ""}


func _clear_files() -> void:
	for path in [manager.save_path, manager.temp_path, manager.backup_path, manager.backup_temp_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _data(scene: String = LEVEL, x: float = 12.0) -> Dictionary:
	return {
		"version": 2, "scene": scene,
		"player": {"position": {"x": x, "y": 34.0}},
		"world": {"collected_items": [], "completed_events": [], "flags": {}},
		"meta": {}
	}


func _settle() -> void:
	for _frame in range(60):
		await get_tree().process_frame
		if not manager.is_loading():
			await get_tree().process_frame
			return
	_check(false, "transição terminou no limite de frames")


func _new_scene(path: String) -> bool:
	var accepted: bool = manager.new_game(path)
	_check(accepted, "aceitar cena " + path)
	if not accepted:
		return false
	await _settle()
	var scene := get_tree().current_scene
	var ok := scene != null and scene.scene_file_path == path
	_check(ok, "concluir cena " + path)
	return ok


func _test_reading() -> void:
	_clear_files()
	_check(not manager.has_save(), "saves ausentes")
	var before := GameState.export_data()
	get_tree().paused = true
	_check(not manager.continue_game(), "continuar sem save falha")
	_check(GameState.export_data() == before and get_tree().paused, "ausência preserva memória e pausa")
	get_tree().paused = false
	_write(manager.save_path, {"version": 1, "scene": LEVEL, "player": {"x": 8, "y": 9}})
	var old: Dictionary = manager.read_save()
	_check(old.get("version") == 2, "migração v1 para v2")
	_check(old.get("player", {}).get("position", {}) == {"x": 8.0, "y": 9.0}, "posição v1")
	_check(old.get("world", {}).get("collected_items", []).is_empty(), "v1 sem progresso inventado")
	GameState.collect_item(ITEM_ID)
	GameState.complete_event(EVENT_ID)
	GameState.set_flag("stale_flag", true)
	_check(manager.continue_game(), "carregar save v1 efetivamente")
	await _settle()
	_check(GameState.export_data() == GameState.normalize_data({}), "v1 limpa progresso da partida anterior")
	_check(get_tree().current_scene.get_node("Player").global_position == Vector2(8, 9), "v1 restaura posição na cena")
	var valid := _data(LEVEL, 77.0)
	_write(manager.backup_path, valid)
	_write(manager.save_path, "{arquivo truncado")
	_check(manager.read_save().get("player", {}).get("position", {}).get("x") == 77.0, "fallback de principal corrompido")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.save_path))
	_check(manager.has_save(), "fallback de principal ausente")
	_write(manager.save_path, _data(LEVEL, 88.0))
	_check(manager.read_save().get("player", {}).get("position", {}).get("x") == 88.0, "principal válido tem prioridade")
	for text in ["{", "[]", "null", "123"]:
		_write(manager.save_path, text)
		_write(manager.backup_path, text)
		_check(manager.read_save().is_empty(), "JSON inválido: " + text)
	for version in [-1, 1.5, 3, "2", true]:
		var data := _data()
		data.version = version
		_check(manager._normalize_save(data).is_empty(), "versão rejeitada: " + str(version))
	for value in ["10", null, true, INF, NAN, 1e300]:
		var data := _data()
		data.player.position.x = value
		_check(manager._normalize_save(data).is_empty(), "posição inválida: " + str(value))
	_clear_files()


func _test_world_validation() -> void:
	var missing := _data()
	missing.erase("world")
	_check(manager._normalize_save(missing).is_empty(), "v2 exige world")
	for field in ["collected_items", "completed_events", "flags"]:
		missing = _data()
		missing.world.erase(field)
		_check(manager._normalize_save(missing).is_empty(), "v2 exige campo " + field)
	for world in [[], {"collected_items": "coin"}, {"collected_items": [42]}, {"completed_events": [""]}, {"flags": {"gate": "false"}}]:
		var data := _data()
		if world is Dictionary:
			data.world.merge(world, true)
		else:
			data.world = world
		_check(manager._normalize_save(data).is_empty(), "mundo malformado rejeitado")
	GameState.set_flag("before", true)
	var before := GameState.export_data()
	_check(not GameState.import_data({"flags": {"gate": 1}}), "import inválido falha")
	_check(GameState.export_data() == before, "import inválido é atômico")
	var events := [0]
	var callback := func(): events[0] += 1
	GameState.progress_changed.connect(callback)
	_check(GameState.import_data({"flags": {"false_flag": false, "true_flag": true}}), "import válido")
	_check(events[0] == 1, "import emite uma única notificação")
	GameState.progress_changed.disconnect(callback)
	_check(not GameState.get_flag("false_flag") and GameState.get_flag("true_flag"), "flags booleanas preservadas")


func _test_disk() -> void:
	if not await _new_scene(LEVEL):
		return
	_clear_files()
	var player: CharacterBody2D = get_tree().current_scene.get_node("Player")
	player.global_position = Vector2(1, 2)
	_check(manager.save_game(), "primeiro save")
	var first := _text(manager.save_path)
	player.global_position = Vector2(3, 4)
	_check(manager.save_game(), "substituir principal")
	_check(_text(manager.backup_path) == first, "backup contém principal anterior")
	var backup := _text(manager.backup_path)
	_write(manager.save_path, "{corrompido")
	_check(manager.save_game(), "salvar após corrupção")
	_check(_text(manager.backup_path) == backup, "principal corrompido não contamina backup")
	var main := _text(manager.save_path)
	manager.fail_target = manager.backup_path
	_check(not manager.save_game(), "falha ao promover backup")
	_check(_text(manager.save_path) == main and _text(manager.backup_path) == backup, "falha de backup preserva arquivos")
	manager.fail_target = manager.save_path
	var saved_count: int = signals.saved.size()
	_check(not manager.save_game(), "falha ao promover principal")
	_check(_text(manager.save_path) == main, "falha de promoção preserva principal")
	_check(not manager._normalize_save(manager._read_json_file(manager.backup_path)).is_empty(), "backup continua válido")
	_check(signals.saved.size() == saved_count + 1 and signals.saved.back() == false, "uma notificação de falha no save")
	manager.fail_target = ""
	backup = _text(manager.backup_path)
	manager.fail_write = true
	_check(not manager.save_game(), "falha ao gravar temporário")
	_check(_text(manager.save_path) == main and _text(manager.backup_path) == backup, "falha de escrita preserva arquivos")
	manager.fail_write = false
	manager.fail_target = manager.save_path
	manager.remove_target_before_failure = true
	var last_valid: Dictionary = manager.read_save()
	_check(not manager.save_game(), "backend remove destino e falha")
	_check(not FileAccess.file_exists(manager.save_path), "principal removido pelo backend simulado")
	_check(manager.read_save() == last_valid, "backup recupera último save válido")
	manager.fail_target = ""
	manager.remove_target_before_failure = false


func _test_restore_cycle() -> void:
	if not await _new_scene(LEVEL):
		return
	_clear_files()
	var scene := get_tree().current_scene
	var player: CharacterBody2D = scene.get_node("Player")
	player.global_position = Vector2(73, 92)
	player.velocity = Vector2(12, 15)
	scene.get_node("Coin").body_entered.emit(player)
	_check(GameState.has_item(ITEM_ID), "coleta real pelo body_entered")
	GameState.complete_event(EVENT_ID)
	GameState.set_flag("gate_open", true)
	GameState.set_flag("boss_dead", false)
	_check(manager.save_game(), "salvar ciclo integrado")
	if not await _new_scene(OTHER):
		return
	expected = {"position": Vector2(73, 92), "collected": true, "event": true}
	var loaded: int = signals.loaded
	get_tree().paused = true
	_check(manager.continue_game(), "aceitar restauração")
	_check(signals.loaded == loaded, "sucesso aguarda restauração completa")
	await _settle()
	scene = get_tree().current_scene
	_check(scene.scene_file_path == LEVEL, "cena restaurada")
	player = scene.get_node("Player")
	_check(player.global_position == Vector2(73, 92), "posição global restaurada")
	_check(player.velocity == Vector2.ZERO, "velocidade zerada")
	_check(not scene.get_node("Coin").visible and not scene.get_node("Coin").monitoring, "coletável restaurado")
	_check(scene.get_node("Trigger").already_triggered, "evento restaurado no objeto")
	_check(GameState.get_flag("gate_open") and not GameState.get_flag("boss_dead"), "flags restauradas")
	_check(signals.loaded == loaded + 1 and manager.pending_save.is_empty() and not get_tree().paused, "commit finaliza uma vez")
	_check(manager.continue_game(), "restaurar novamente a mesma cena")
	await _settle()
	_check(not get_tree().current_scene.get_node("Coin").visible, "coletável permanece coletado ao reentrar")
	var renamed: Dictionary = manager.read_save()
	renamed.scene = RENAMED
	_write(manager.save_path, renamed)
	_check(manager.continue_game(), "restaurar objetos renomeados")
	await _settle()
	scene = get_tree().current_scene
	_check(not scene.get_node("Container/RenamedCoin").visible, "ID independe do nome e parent")
	_check(scene.get_node("Container/RenamedTrigger").already_triggered, "ID legado do evento preservado")


func _test_rollback() -> void:
	var scene := get_tree().current_scene
	var focus_button := Button.new()
	focus_button.focus_mode = Control.FOCUS_ALL
	scene.add_child(focus_button)
	focus_button.grab_focus()
	_check(get_tree().root.gui_get_focus_owner() == focus_button, "foco estabelecido antes da tentativa de carga")
	var before := GameState.export_data()
	manager.pending_save = {"sentinel": {"value": 123}}
	var pending: Dictionary = manager.pending_save.duplicate(true)
	var coin := scene.get_node("Container/RenamedCoin")
	var trigger := scene.get_node("Container/RenamedTrigger")
	var object_state := [coin.visible, coin.monitoring, trigger.already_triggered]
	var loaded: int = signals.loaded
	var data := _data(BROKEN)
	data.world.flags = {"different_world": true}
	_write(manager.save_path, data)
	get_tree().paused = true
	_check(manager.continue_game(), "falha pós-ready é aceita inicialmente")
	await _settle()
	_check(get_tree().current_scene == scene, "rollback restaura cena anterior")
	_check(get_tree().root.gui_get_focus_owner() == focus_button, "rollback restaura foco de teclado e controle")
	_check(GameState.export_data() == before, "rollback restaura GameState")
	_check(get_tree().paused and manager.pending_save == pending, "rollback restaura pausa e pending")
	_check(scene.get_node("Container/RenamedCoin") == coin and scene.get_node("Container/RenamedTrigger") == trigger, "rollback preserva instâncias dos objetos")
	_check([coin.visible, coin.monitoring, trigger.already_triggered] == object_state, "rollback preserva estado dos objetos")
	_check(signals.loaded == loaded and not signals.finished.back(), "rollback não anuncia sucesso")
	_check(manager.new_game(BROKEN), "nova partida falha depois de ready")
	await _settle()
	_check(get_tree().current_scene == scene and GameState.export_data() == before and get_tree().paused, "rollback de nova partida")
	manager.fail_scene = true
	manager.mutate_before_failure = true
	_check(not manager.continue_game(), "falha imediata de instanciação")
	_check(get_tree().current_scene == scene and GameState.export_data() == before and get_tree().paused and manager.pending_save == pending, "falha imediata desfaz efeitos da instanciação")
	manager.fail_scene = false
	manager.mutate_before_failure = false
	_check(not manager.new_game("res://tests/absent.tscn"), "nova partida com arquivo ausente")
	_check(GameState.export_data() == before and get_tree().paused, "arquivo ausente preserva estado")
	_write(manager.save_path, _data(LEVEL))
	manager.fail_root_deferred = true
	_check(manager.continue_game(), "aceitar cena cuja raiz será liberada")
	await _settle()
	_check(get_tree().current_scene == scene and GameState.export_data() == before, "raiz liberada restaura cena e mundo")
	_check(get_tree().paused and manager.pending_save == pending and signals.loaded == loaded, "raiz liberada preserva pausa e pending")
	manager.fail_root_deferred = false
	get_tree().paused = false


func _test_ids() -> void:
	for id in ["", " ", " id", "id ", "line\nbreak", "tab\tid", 42]:
		_check(not GameState.is_valid_id(id), "ID inválido rejeitado: " + str(id))
	_check(GameState.is_valid_id("Legacy_ID_001"), "ID legado não é reescrito")
	var scene := get_tree().current_scene
	for path in ["res://tests/duplicate_ids.tscn", "res://tests/missing_id.tscn"]:
		_check(not manager.new_game(path), "IDs inválidos bloqueiam cena")
		_check(get_tree().current_scene == scene and not manager.is_loading(), "rejeição de ID preserva cena")



func _test_skipped_objects() -> void:
	# Nó já marcado para exclusão.
	var scene := Node.new()
	var doomed := Probe.new()
	scene.add_child(doomed)
	doomed.queue_free()
	manager._apply_objects(scene)
	_check(doomed.applied == 0, "não aplica em nó marcado")
	scene.free()

	# Um callback marca o pai de um objeto que ainda está no snapshot.
	scene = Node.new()
	var actor := Probe.new()
	var parent := Node.new()
	var child := Probe.new()
	scene.add_child(actor)
	scene.add_child(parent)
	parent.add_child(child)
	actor.target = parent
	manager._apply_objects(scene)
	_check(actor.applied == 1 and child.applied == 0, "não aplica em descendente de pai marcado")
	scene.free()

	# Um callback libera imediatamente o próximo objeto do snapshot.
	scene = Node.new()
	actor = Probe.new()
	var victim := Probe.new()
	var survivor := Probe.new()
	scene.add_child(actor)
	scene.add_child(victim)
	scene.add_child(survivor)
	actor.target = victim
	actor.free_target = true
	manager._apply_objects(scene)
	_check(not is_instance_valid(victim) and survivor.applied == 1, "ignora nó liberado sem interromper restauração")
	scene.free()

	# Player dentro de um ramo marcado não pode validar a cena.
	scene = Node.new()
	parent = Node.new()
	var player := Node2D.new()
	player.add_to_group("Player")
	scene.add_child(parent)
	parent.add_child(player)
	parent.queue_free()
	_check(not manager._validate_scene(scene), "Player prestes a ser removido invalida cena")
	scene.free()


func _test_real_object_guards() -> void:
	var before := GameState.export_data()
	GameState.reset_progress()
	var fixture: Node2D = load(LEVEL).instantiate()
	var coin: Variant = fixture.get_node("Coin")
	var trigger: Variant = fixture.get_node("Trigger")
	coin.collected = true
	coin.visible = false
	trigger.already_triggered = true
	coin.apply_persistent_state()
	trigger.apply_persistent_state()
	_check(coin.collected and not coin.visible and trigger.already_triggered, "restauração direta ignora objetos fora da árvore")
	fixture.free()

	# As conexões de progress_changed ainda existem depois de queue_free().
	fixture = load(LEVEL).instantiate()
	add_child(fixture)
	coin = fixture.get_node("Coin")
	trigger = fixture.get_node("Trigger")
	coin.queue_free()
	trigger.queue_free()
	GameState.collect_item(ITEM_ID)
	GameState.complete_event(EVENT_ID)
	_check(not coin.collected and coin.visible and not trigger.already_triggered, "sinal de progresso ignora objetos reais marcados para exclusão")
	fixture.free()

	GameState.reset_progress()
	fixture = load(LEVEL).instantiate()
	add_child(fixture)
	coin = fixture.get_node("Coin")
	trigger = fixture.get_node("Trigger")
	fixture.queue_free()
	GameState.collect_item(ITEM_ID)
	GameState.complete_event(EVENT_ID)
	_check(not coin.collected and coin.visible and not trigger.already_triggered, "sinal de progresso ignora objetos com ancestral marcado")
	fixture.free()

	# Uma cena preservada fora da árvore continua conectada ao GameState.
	GameState.reset_progress()
	fixture = load(LEVEL).instantiate()
	add_child(fixture)
	coin = fixture.get_node("Coin")
	trigger = fixture.get_node("Trigger")
	remove_child(fixture)
	GameState.collect_item(ITEM_ID)
	GameState.complete_event(EVENT_ID)
	_check(not coin.collected and coin.visible and not trigger.already_triggered, "sinal de progresso preserva cena temporariamente fora da árvore")
	fixture.free()

	# Os sinais de contato não podem iniciar progresso/diálogo na preparação.
	GameState.reset_progress()
	fixture = load(LEVEL).instantiate()
	add_child(fixture)
	coin = fixture.get_node("Coin")
	trigger = fixture.get_node("Trigger")
	var dialogue := DialogueData.new()
	var line := DialogueLine.new()
	line.text = "Diálogo de teste."
	dialogue.lines.append(line)
	trigger.dialogue = dialogue
	var original_loading := SaveManager.is_loading()
	var original_dialogue_active := DialogueManager.is_active
	SaveManager.set("_loading", true)
	coin.body_entered.emit(fixture.get_node("Player"))
	trigger.body_entered.emit(fixture.get_node("Player"))
	SaveManager.set("_loading", original_loading)
	_check(not GameState.has_item(ITEM_ID) and not GameState.is_event_complete(EVENT_ID) and DialogueManager.is_active == original_dialogue_active, "contatos durante carga não coletam item nem iniciam diálogo")
	if not original_dialogue_active and DialogueManager.is_active:
		DialogueManager.end_dialogue()
	fixture.free()

	# A última alteração do mesmo frame deve prevalecer após o flush.
	GameState.reset_progress()
	fixture = load(LEVEL).instantiate()
	add_child(fixture)
	coin = fixture.get_node("Coin")
	await get_tree().process_frame
	GameState.collect_item(ITEM_ID)
	GameState.reset_progress()
	await get_tree().process_frame
	_check(not coin.collected and coin.visible and coin.monitoring, "coleta seguida de reset no mesmo frame restaura monitoring")
	GameState.reset_progress()
	GameState.collect_item(ITEM_ID)
	await get_tree().process_frame
	_check(coin.collected and not coin.visible and not coin.monitoring, "reset seguido de coleta no mesmo frame desativa monitoring")
	fixture.free()
	GameState.import_data(before)

