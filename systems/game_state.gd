
extends Node

signal progress_changed

var collected_items: Dictionary = {}
var completed_events: Dictionary = {}
var flags: Dictionary = {}


func reset_progress() -> void:
	collected_items.clear()
	completed_events.clear()
	flags.clear()
	progress_changed.emit()


# ==========================================
# COLETÁVEIS
# ==========================================

func collect_item(item_id: String) -> void:
	if item_id.is_empty():
		push_warning("Item sem ID persistente.")
		return

	if collected_items.has(item_id):
		return

	collected_items[item_id] = true
	progress_changed.emit()


func has_item(item_id: String) -> bool:
	return collected_items.has(item_id)


# ==========================================
# EVENTOS
# ==========================================

func complete_event(event_id: String) -> void:
	if event_id.is_empty():
		push_warning("Evento sem ID persistente.")
		return

	if completed_events.has(event_id):
		return

	completed_events[event_id] = true
	progress_changed.emit()


func is_event_complete(event_id: String) -> bool:
	return completed_events.has(event_id)


# ==========================================
# FLAGS
# ==========================================

func set_flag(flag_id: String, value: bool) -> void:
	if flag_id.is_empty():
		return

	flags[flag_id] = value
	progress_changed.emit()


func get_flag(flag_id: String) -> bool:
	return bool(flags.get(flag_id, false))


# ==========================================
# EXPORTAR / IMPORTAR
# ==========================================

func export_data() -> Dictionary:
	return {
		"collected_items": collected_items.keys(),
		"completed_events": completed_events.keys(),
		"flags": flags.duplicate(true)
	}


func import_data(data: Dictionary) -> void:
	reset_progress()

	var saved_items: Variant = data.get("collected_items", [])
	var saved_events: Variant = data.get("completed_events", [])
	var saved_flags: Variant = data.get("flags", {})

	if saved_items is Array:
		for item_id in saved_items:
			if item_id is String and not item_id.is_empty():
				collected_items[item_id] = true

	if saved_events is Array:
		for event_id in saved_events:
			if event_id is String and not event_id.is_empty():
				completed_events[event_id] = true

	if saved_flags is Dictionary:
		for flag_id in saved_flags:
			if flag_id is String and saved_flags[flag_id] is bool:
				flags[flag_id] = saved_flags[flag_id]

	progress_changed.emit()
