class_name FlagLever
extends FlagInteractable


func _apply_visual_state() -> void:
	var visual: Polygon2D = get_node_or_null("LeverVisual") as Polygon2D
	if visual != null:
		visual.color = Color(0.25, 0.85, 0.45) if activated else Color(0.9, 0.55, 0.2)
		visual.rotation = 0.6 if activated else -0.6
