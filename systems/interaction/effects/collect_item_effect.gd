class_name CollectItemEffect
extends InteractionEffect

@export var item_id: String = ""


func is_valid() -> bool:
	return GameState.is_valid_id(item_id)


func execute(_interactor: Node2D, _source: Node2D) -> bool:
	if not is_valid() or SaveManager.is_loading():
		return false
	GameState.collect_item(item_id)
	return true
