
extends Node

signal game_saved(success: bool)
signal game_loaded
signal save_failed(message: String)

const SAVE_PATH := "user://savegame.json"
const TEMP_PATH := "user://savegame.tmp"
const BACKUP_PATH := "user://savegame.bak"

const SAVE_VERSION := 2

var pending_save: Dictionary = {}


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)


# ==========================================
# NOVA PARTIDA
# ==========================================

func new_game(first_level_path: String) -> bool:
	if not ResourceLoader.exists(first_level_path):
		push_error("[SAVE] Fase inicial inválida.")
		return false

	GameState.reset_progress()
	pending_save.clear()
	get_tree().paused = false

	# O arquivo anterior permanece no disco
	# até que a nova partida seja salva.
	var result := get_tree().change_scene_to_file(
		first_level_path
	)

	return result == OK


# ==========================================
# CRIAR OS DADOS DE SAVE
# ==========================================

func _build_save_data() -> Dictionary:
	var scene := get_tree().current_scene
	var player := _find_player(scene)

	if scene == null or player == null:
		return {}

	if scene.scene_file_path.is_empty():
		return {}

	var position := player.global_position

	return {
		"version": SAVE_VERSION,
		"scene": scene.scene_file_path,
		"player": {
			"position": {
				"x": position.x,
				"y": position.y
			}
		},
		"world": GameState.export_data(),
		"meta": {
			"saved_at": Time.get_datetime_string_from_system()
		}
	}


# ==========================================
# SALVAR NO DISCO
# ==========================================

func save_game() -> bool:
	var data := _build_save_data()

	if data.is_empty():
		_report_error("Fase ou Player não encontrado.")
		game_saved.emit(false)
		return false

	var file := FileAccess.open(
		TEMP_PATH,
		FileAccess.WRITE
	)

	if file == null:
		_report_error("Não foi possível criar o arquivo temporário.")
		game_saved.emit(false)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.flush()

	var write_error := file.get_error()
	file.close()

	if write_error != OK:
		_report_error("Falha durante a gravação.")
		game_saved.emit(false)
		return false

	# Confere se o arquivo escrito pode ser interpretado.
	if _normalize_save(_read_json_file(TEMP_PATH)).is_empty():
		_report_error("O arquivo temporário é inválido.")
		game_saved.emit(false)
		return false

	var main_path := ProjectSettings.globalize_path(SAVE_PATH)
	var temp_path := ProjectSettings.globalize_path(TEMP_PATH)
	var backup_path := ProjectSettings.globalize_path(BACKUP_PATH)

	# Preserva uma cópia do último save existente.
	if FileAccess.file_exists(SAVE_PATH):
		var backup_error := DirAccess.copy_absolute(
			main_path,
			backup_path
		)

		if backup_error != OK:
			_report_error("Não foi possível criar o backup.")
			game_saved.emit(false)
			return false

		# Remove o arquivo antigo apenas após o backup.
		var remove_error := DirAccess.remove_absolute(main_path)

		if remove_error != OK:
			_report_error("Não foi possível substituir o save antigo.")
			game_saved.emit(false)
			return false

	var rename_error := DirAccess.rename_absolute(
		temp_path,
		main_path
	)

	if rename_error != OK:
		# Tenta recuperar o arquivo principal do backup.
		if FileAccess.file_exists(BACKUP_PATH):
			var restore_error := DirAccess.copy_absolute(
				backup_path,
				main_path
			)

			if restore_error != OK:
				push_error("[SAVE] Falha ao restaurar backup.")

		_report_error("Não foi possível finalizar o salvamento.")
		game_saved.emit(false)
		return false

	print("[SAVE] Jogo salvo: ", data["scene"])
	print("[SAVE] Posição: ", data["player"]["position"])

	game_saved.emit(true)
	return true


# ==========================================
# LEITURA E VALIDAÇÃO
# ==========================================

func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		return {}

	var content := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)

	if parsed is Dictionary:
		return parsed

	return {}


func _normalize_save(data: Dictionary) -> Dictionary:
	var version: Variant = data.get("version", -1)

	if not (version is int or version is float):
		return {}

	if not is_finite(float(version)):
		return {}

	if float(version) != floor(float(version)):
		return {}

	var scene: Variant = data.get("scene", "")

	if not scene is String:
		return {}

	if not scene.begins_with("res://"):
		return {}

	if not scene.ends_with(".tscn"):
		return {}

	if not ResourceLoader.exists(scene):
		return {}

	var raw_player: Variant = data.get("player", {})

	if not raw_player is Dictionary:
		return {}

	var position_data: Dictionary = {}

	match int(version):
		1:
			# Formato anterior:
			# player: {x: ..., y: ...}
			position_data = raw_player

		SAVE_VERSION:
			# Formato atual:
			# player: {position: {x: ..., y: ...}}
			var nested: Variant = raw_player.get(
				"position",
				{}
			)

			if not nested is Dictionary:
				return {}

			position_data = nested

		_:
			return {}

	var x: Variant = position_data.get("x")
	var y: Variant = position_data.get("y")

	if not (x is float or x is int):
		return {}

	if not (y is float or y is int):
		return {}

	if not is_finite(float(x)) or not is_finite(float(y)):
		return {}

	var world_data: Dictionary = {}

	if version == SAVE_VERSION:
		var raw_world: Variant = data.get("world", {})

		if not raw_world is Dictionary:
			return {}

		world_data = raw_world

	var raw_meta: Variant = data.get("meta", {})
	var meta_data: Dictionary = {}

	if raw_meta is Dictionary:
		meta_data = raw_meta

	# Sempre devolve a estrutura atual,
	# mesmo quando o arquivo era da versão 1.
	return {
		"version": SAVE_VERSION,
		"scene": scene,
		"player": {
			"position": {
				"x": float(x),
				"y": float(y)
			}
		},
		"world": world_data,
		"meta": meta_data
	}


func read_save() -> Dictionary:
	var data := _normalize_save(
		_read_json_file(SAVE_PATH)
	)

	if not data.is_empty():
		return data

	# Recupera o backup quando o principal
	# não existe ou não pode ser interpretado.
	return _normalize_save(
		_read_json_file(BACKUP_PATH)
	)


func has_save() -> bool:
	return not read_save().is_empty()


# ==========================================
# CONTINUAR PARTIDA
# ==========================================

func continue_game() -> bool:
	var data := read_save()

	if data.is_empty():
		_report_error("Nenhum save válido encontrado.")
		return false

	pending_save = data.duplicate(true)

	# Carrega o estado ANTES da nova fase.
	# Assim os objetos podem consultá-lo no _ready().
	GameState.import_data(data["world"])

	get_tree().paused = false

	var result := get_tree().change_scene_to_file(
		data["scene"]
	)

	if result != OK:
		pending_save.clear()
		_report_error("Não foi possível abrir a fase salva.")
		return false

	return true


# ==========================================
# RESTAURAR PLAYER
# ==========================================

func _on_scene_changed() -> void:
	if pending_save.is_empty():
		return

	# Restaura após a inicialização da nova cena.
	_restore_pending.call_deferred()


func _restore_pending() -> void:
	if pending_save.is_empty():
		return

	var scene := get_tree().current_scene

	if scene == null:
		return

	if scene.scene_file_path != pending_save.get("scene", ""):
		return

	var player := _find_player(scene)

	if player == null:
		_report_error("Player não encontrado na fase carregada.")
		pending_save.clear()
		return

	var position_data: Dictionary = (
		pending_save["player"]["position"]
	)

	player.global_position = Vector2(
		float(position_data["x"]),
		float(position_data["y"])
	)

	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO
		player.reset_physics_interpolation()

	print("[SAVE] Posição restaurada: ", player.global_position)

	pending_save.clear()
	game_loaded.emit()


# ==========================================
# FUNÇÕES AUXILIARES
# ==========================================

func _find_player(scene: Node) -> Node2D:
	if scene == null:
		return null

	for node in get_tree().get_nodes_in_group("Player"):
		if node is Node2D:
			if node == scene or scene.is_ancestor_of(node):
				return node

	return null


func _report_error(message: String) -> void:
	push_error("[SAVE] " + message)
	save_failed.emit(message)
