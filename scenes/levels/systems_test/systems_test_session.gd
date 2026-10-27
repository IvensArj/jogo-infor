class_name SystemsTestSession
extends Node

const LEVEL: String = "res://scenes/levels/systems_test_level.tscn"
const ENTRY: String = "res://scenes/levels/systems_test_entry.tscn"
const META: StringName = &"systems_test_session"
const PROFILE: AbilityProfile = preload("res://scenes/levels/systems_test/test_profile.tres")

var directory: String
var _tree: SceneTree
var _original_world: Dictionary
var _original_pending: Dictionary
var _original_paths: Array[String] = []
var _test_paths: Array[String] = []
var _needs_profile: bool = true
var _closed: bool = false


static func current(tree: SceneTree) -> SystemsTestSession:
	return tree.get_meta(META) as SystemsTestSession if tree.has_meta(META) else null


static func begin(tree: SceneTree) -> SystemsTestSession:
	var existing := current(tree)
	if is_instance_valid(existing):
		return existing
	var session := SystemsTestSession.new()
	session._tree = tree
	session._original_world = GameState.export_data()
	session._original_pending = SaveManager.pending_save.duplicate(true)
	session._original_paths.assign([SaveManager.save_path, SaveManager.temp_path, SaveManager.backup_path, SaveManager.backup_temp_path])
	session.directory = "user://systems_lab_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(session.directory) != OK:
		push_error("Não foi possível criar o diretório isolado de testes.")
		session.free()
		return null
	for filename in ["save.json", "save.tmp", "save.bak", "backup.tmp"]:
		session._test_paths.append(session.directory.path_join(filename))
	session._set_paths(session._test_paths)
	GameState.reset_progress()
	tree.set_meta(META, session)
	tree.scene_changed.connect(session._on_scene_changed)
	SaveManager.transition_finished.connect(session._on_transition_finished)
	# A raiz pode estar inserindo a cena; a sessão permanece fora dela nas recargas.
	tree.root.add_child.call_deferred(session)
	return session


func _set_paths(paths: Array[String]) -> void:
	SaveManager.save_path = paths[0]
	SaveManager.temp_path = paths[1]
	SaveManager.backup_path = paths[2]
	SaveManager.backup_temp_path = paths[3]


func prepare_level() -> void:
	if _needs_profile:
		GameState.apply_ability_profile(PROFILE)
		_needs_profile = false


func restart_progress() -> bool:
	if SaveManager.is_loading():
		return false
	_needs_profile = true
	return SaveManager.new_game(LEVEL)


func _on_scene_changed() -> void:
	var scene := _tree.current_scene
	if scene != null and scene.scene_file_path != LEVEL and scene.scene_file_path != ENTRY:
		finish()


func _on_transition_finished(success: bool) -> void:
	if not success and (_tree.current_scene == null or _tree.current_scene.scene_file_path != LEVEL):
		finish()


func finish(release_node: bool = true) -> void:
	if _closed:
		return
	_closed = true
	if _tree.scene_changed.is_connected(_on_scene_changed):
		_tree.scene_changed.disconnect(_on_scene_changed)
	if SaveManager.transition_finished.is_connected(_on_transition_finished):
		SaveManager.transition_finished.disconnect(_on_transition_finished)
	_set_paths(_original_paths)
	GameState.import_data(_original_world)
	SaveManager.pending_save = _original_pending.duplicate(true)
	_tree.remove_meta(META)
	# Remove apenas os quatro arquivos conhecidos criados por esta sessão.
	for path in _test_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	if release_node:
		queue_free()


func _exit_tree() -> void:
	finish(false)
