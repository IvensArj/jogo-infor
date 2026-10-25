extends Node

# Contrato: durante is_loading(), callbacks de ciclo de vida, suas chamadas
# adiadas e a restauração de objetos devem realizar apenas operações locais
# e reversíveis. Efeitos externos começam após transition_finished(true).
# O rollback cobre GameState, pausa, pendências e a instância da cena anterior;
# não desfaz IO, outros singletons ou objetos criados fora da cena.

signal game_saved(success: bool)
signal game_loaded
signal save_failed(message: String)
signal transition_finished(success: bool)

const SAVE_PATH := "user://savegame.json"
const TEMP_PATH := "user://savegame.tmp"
const BACKUP_PATH := "user://savegame.bak"
const SAVE_VERSION := 2

# Configuráveis para os testes; os padrões preservam os saves existentes.
var save_path: String = SAVE_PATH
var temp_path: String = TEMP_PATH
var backup_path: String = BACKUP_PATH
var backup_temp_path: String = "user://savegame.bak.tmp"
var pending_save: Dictionary = {}
var _loading := false
var _saving := false


func is_loading() -> bool:
	return _loading


func _build_save_data() -> Dictionary:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.is_empty() or not _validate_scene(scene):
		return {}
	var player := _find_player(scene)
	return _normalize_save({
		"version": SAVE_VERSION,
		"scene": scene.scene_file_path,
		"player": {"position": {"x": player.global_position.x, "y": player.global_position.y}},
		"world": GameState.export_data(),
		"meta": {"saved_at": Time.get_datetime_string_from_system()}
	})


func save_game() -> bool:
	if _loading or _saving:
		return false
	_saving = true
	var data := _build_save_data()
	if data.is_empty():
		return _finish_save(false, "Cena, Player ou IDs persistentes inválidos.")
	if not _write_validated(temp_path, data):
		return _finish_save(false, "Falha ao gravar e validar o temporário.")

	# Nunca rotaciona um principal corrompido sobre um backup válido.
	var previous := _normalize_save(_read_json_file(save_path))
	if not previous.is_empty():
		if not _write_validated(backup_temp_path, previous):
			return _finish_save(false, "Falha ao preparar o backup.")
		if _replace_file(backup_temp_path, backup_path) != OK:
			return _finish_save(false, "Falha ao substituir o backup.")

	# O backend pode remover o destino antes de falhar (Windows).
	# O backup válido é concluído antes de promover o principal.
	if _replace_file(temp_path, save_path) != OK:
		return _finish_save(false, "Falha ao substituir o arquivo principal.")
	return _finish_save(true)


func _finish_save(success: bool, message: String = "") -> bool:
	for path in [temp_path, backup_temp_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_saving = false
	if not message.is_empty():
		_report_error(message)
	game_saved.emit(success)
	return success


func _replace_file(from: String, to: String) -> Error:
	var source := ProjectSettings.globalize_path(from).simplify_path()
	var destination := ProjectSettings.globalize_path(to).simplify_path()
	if source == destination or source.get_base_dir() != destination.get_base_dir():
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(source):
		return ERR_FILE_NOT_FOUND
	# Não implica atomicidade ou durabilidade em todas as plataformas.
	return DirAccess.rename_absolute(source, destination)


func _write_validated(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and not _normalize_save(_read_json_file(path)).is_empty()


func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	var error := file.get_error()
	file.close()
	if error != OK and error != ERR_FILE_EOF:
		return {}
	var json := JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		return {}
	return json.data


func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _normalize_save(data: Dictionary) -> Dictionary:
	var version: Variant = data.get("version")
	if not _is_number(version) or (version != 1 and version != SAVE_VERSION):
		return {}
	var scene: Variant = data.get("scene")
	if not scene is String:
		return {}
	if not scene.begins_with("res://") or not scene.ends_with(".tscn"):
		return {}
	if not ResourceLoader.exists(scene, "PackedScene"):
		return {}
	var player: Variant = data.get("player")
	if not player is Dictionary:
		return {}
	var position: Variant = player if version == 1 else player.get("position")
	if not position is Dictionary:
		return {}
	if not _is_number(position.get("x")) or not _is_number(position.get("y")):
		return {}
	if not Vector2(float(position["x"]), float(position["y"])).is_finite():
		return {}
	var raw_world: Variant = {} if version == 1 else data.get("world")
	if version == SAVE_VERSION:
		if not raw_world is Dictionary:
			return {}
		for field in ["collected_items", "completed_events", "flags"]:
			if not raw_world.has(field):
				return {}
	var world := GameState.normalize_data(raw_world)
	if world.is_empty():
		return {}
	var meta: Variant = data.get("meta", {})
	return {
		"version": SAVE_VERSION,
		"scene": scene,
		"player": {"position": {"x": float(position["x"]), "y": float(position["y"])}},
		"world": world,
		"meta": meta.duplicate(true) if meta is Dictionary else {}
	}


func read_save() -> Dictionary:
	for path in [save_path, backup_path]:
		var data := _normalize_save(_read_json_file(path))
		if not data.is_empty():
			return data
	return {}


func has_save() -> bool:
	return not read_save().is_empty()


# true significa solicitação aceita. A conclusão chega pelos sinais.
func continue_game() -> bool:
	if _loading or _saving:
		return false
	var data := read_save()
	if data.is_empty():
		_report_error("Nenhum save válido encontrado.")
		return false
	return _request_transition(data, true)


func new_game(first_level_path: String) -> bool:
	if _loading or _saving:
		return false
	return _request_transition({"scene": first_level_path, "world": {}}, false)


func _instantiate_scene(path: String) -> Node:
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var packed := ResourceLoader.load(path) as PackedScene
	return packed.instantiate() if packed != null and packed.can_instantiate() else null


func _request_transition(data: Dictionary, restore_position: bool) -> bool:
	# Snapshot antes de carregar/instanciar: _init() também pode alterar estado.
	var snapshot := {
		"world": GameState.export_data(),
		"paused": get_tree().paused,
		"pending": pending_save.duplicate(true),
		"scene": get_tree().current_scene,
		"focus": get_viewport().gui_get_focus_owner()
	}
	_loading = true
	get_tree().paused = true
	var candidate := _instantiate_scene(data["scene"])
	if candidate == null or not _validate_scene(candidate):
		_abort_transition(candidate, snapshot, "Cena inválida: Player ou IDs persistentes ausentes/duplicados.")
		return false
	pending_save = data.duplicate(true)
	_perform_transition.call_deferred(candidate, data.duplicate(true), snapshot, restore_position)
	return true


func _perform_transition(candidate: Variant, data: Dictionary, snapshot: Dictionary, restore_position: bool) -> void:
	var tree := get_tree()
	var previous: Variant = snapshot["scene"]
	if not is_instance_valid(candidate) or tree.current_scene != previous:
		_abort_transition(candidate, snapshot)
		return
	if previous != null and not is_instance_valid(previous):
		_abort_transition(candidate, snapshot)
		return

	# Mantém a instância anterior viva para poder desfazer a transição.
	if previous != null:
		tree.root.remove_child(previous)
	tree.current_scene = null
	GameState.import_data(data["world"], false)
	tree.root.add_child(candidate)
	if not _candidate_is_valid(candidate):
		_abort_transition(candidate, snapshot)
		return
	tree.current_scene = candidate
	_apply_objects(candidate)
	# Deixa as atualizações adiadas por _ready() e pelos objetos terminarem.
	_complete_transition.call_deferred(candidate, data, snapshot, restore_position)


func _candidate_is_valid(candidate: Variant) -> bool:
	return (
		is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and candidate.get_parent() == get_tree().root
		and _validate_scene(candidate)
	)


func _complete_transition(candidate: Variant, data: Dictionary, snapshot: Dictionary, restore_position: bool) -> void:
	var tree := get_tree()
	if not _candidate_is_valid(candidate) or tree.current_scene != candidate:
		_abort_transition(candidate, snapshot)
		return
	if candidate.scene_file_path != data["scene"]:
		_abort_transition(candidate, snapshot)
		return

	var player := _find_player(candidate)
	if restore_position:
		var position: Dictionary = data["player"]["position"]
		player.global_position = Vector2(position["x"], position["y"])
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()

	var previous: Variant = snapshot["scene"]
	if is_instance_valid(previous):
		previous.free()
	pending_save.clear()
	GameState.progress_changed.emit()
	tree.paused = false
	_loading = false
	tree.scene_changed.emit()
	if restore_position:
		game_loaded.emit()
	transition_finished.emit(true)


func _abort_transition(candidate: Variant, snapshot: Dictionary, message: String = "Carregamento cancelado; estado anterior restaurado.") -> void:
	var tree := get_tree()
	if is_instance_valid(candidate):
		if tree.current_scene == candidate:
			tree.current_scene = null
		var parent: Node = candidate.get_parent()
		if parent != null:
			parent.remove_child(candidate)
		candidate.free()
	GameState.import_data(snapshot["world"], false)
	var previous: Variant = snapshot["scene"]
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		if previous.get_parent() == null:
			tree.root.add_child(previous)
		tree.current_scene = previous
	_rollback_state(snapshot, message)


func _rollback_state(snapshot: Dictionary, message: String) -> void:
	GameState.import_data(snapshot["world"], false)
	pending_save = snapshot["pending"].duplicate(true)
	GameState.progress_changed.emit()
	get_tree().paused = snapshot["paused"]
	var previous_focus: Variant = snapshot.get("focus")
	if is_instance_valid(previous_focus) and previous_focus.is_inside_tree():
		if previous_focus.is_visible_in_tree() and previous_focus.focus_mode != Control.FOCUS_NONE:
			previous_focus.grab_focus()
	_loading = false
	_report_error(message)
	transition_finished.emit(false)


func _nodes(root: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	if not is_instance_valid(root) or root.is_queued_for_deletion():
		return nodes
	nodes.append(root)
	for child in root.get_children():
		nodes.append_array(_nodes(child))
	return nodes


func _find_player(scene: Node) -> Node2D:
	if scene == null:
		return null
	var player: Node2D = null
	for node in _nodes(scene):
		if node.is_in_group("Player"):
			if not node is Node2D or player != null or node.is_queued_for_deletion():
				return null
			player = node
	return player


func _validate_scene(scene: Node) -> bool:
	if _find_player(scene) == null:
		return false
	var ids: Dictionary = {}
	for node in _nodes(scene):
		if not node.has_method("get_persistent_id"):
			continue
		if node.has_method("uses_persistence") and not node.uses_persistence():
			continue
		var id: Variant = node.get_persistent_id()
		if not GameState.is_valid_id(id) or ids.has(id) or not node.has_method("apply_persistent_state"):
			return false
		ids[id] = true
	return true


func _can_apply_state(node: Variant, scene: Variant) -> bool:
	if not is_instance_valid(node) or not is_instance_valid(scene):
		return false
	var ancestor: Node = node
	while is_instance_valid(ancestor):
		if ancestor.is_queued_for_deletion():
			return false
		if ancestor == scene:
			return true
		ancestor = ancestor.get_parent()
	return false


func _apply_objects(scene: Node) -> void:
	for node in _nodes(scene):
		# Revalida: uma aplicação anterior pode ter removido outro nó.
		if not _can_apply_state(node, scene):
			continue
		if node.has_method("apply_persistent_state"):
			node.apply_persistent_state()


func _report_error(message: String) -> void:
	push_error("[SAVE] " + message)
	save_failed.emit(message)
