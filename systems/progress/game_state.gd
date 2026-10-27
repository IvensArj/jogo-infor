extends Node

signal progress_changed

var collected_items: Dictionary = {}
var completed_events: Dictionary = {}
var flags: Dictionary = {}


# IDs explícitos e estáveis; novos IDs: "test_level/coin_001".
# IDs legados permanecem exatamente iguais, inclusive maiúsculas.
func is_valid_id(value: Variant) -> bool:
	if not value is String:
		return false
	return (
		not value.is_empty()
		and value == value.strip_edges()
		and not "\n" in value
		and not "\r" in value
		and not "\t" in value
	)


func normalize_data(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var result := {"collected_items": [], "completed_events": [], "flags": {}}
	for field in ["collected_items", "completed_events"]:
		var values: Variant = data.get(field, [])
		if not values is Array:
			return {}
		for id in values:
			if not is_valid_id(id):
				return {}
			if not result[field].has(id):
				result[field].append(id)
	var saved_flags: Variant = data.get("flags", {})
	if not saved_flags is Dictionary:
		return {}
	for id in saved_flags:
		if not is_valid_id(id) or not saved_flags[id] is bool:
			return {}
		result["flags"][id] = saved_flags[id]
	return result


func import_data(data: Dictionary, notify: bool = true) -> bool:
	var normalized := normalize_data(data)
	if normalized.is_empty():
		return false
	var items: Dictionary = {}
	var events: Dictionary = {}
	for id in normalized["collected_items"]:
		items[id] = true
	for id in normalized["completed_events"]:
		events[id] = true
	collected_items = items
	completed_events = events
	flags = normalized["flags"].duplicate(true)
	if notify:
		progress_changed.emit()
	return true


func export_data() -> Dictionary:
	return {
		"collected_items": collected_items.keys(),
		"completed_events": completed_events.keys(),
		"flags": flags.duplicate(true)
	}


func reset_progress() -> void:
	import_data({})


func collect_item(item_id: String) -> void:
	if is_valid_id(item_id) and not collected_items.has(item_id):
		collected_items[item_id] = true
		progress_changed.emit()


func has_item(item_id: String) -> bool:
	return collected_items.has(item_id)


func complete_event(event_id: String) -> void:
	if is_valid_id(event_id) and not completed_events.has(event_id):
		completed_events[event_id] = true
		progress_changed.emit()


func is_event_complete(event_id: String) -> bool:
	return completed_events.has(event_id)


func set_flag(flag_id: String, value: bool) -> void:
	if not is_valid_id(flag_id):
		return
	if flags.has(flag_id) and flags[flag_id] == value:
		return
	flags[flag_id] = value
	progress_changed.emit()


func get_flag(flag_id: String) -> bool:
	return flags.get(flag_id, false) == true
