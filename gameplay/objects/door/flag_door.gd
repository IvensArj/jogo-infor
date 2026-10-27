class_name FlagDoor
extends FlagInteractable


func _apply_visual_state() -> void:
	var visual: Sprite2D = get_node_or_null("DoorVisual") as Sprite2D
	var shape: CollisionShape2D = get_node_or_null("DoorBody/CollisionShape2D") as CollisionShape2D
	if visual != null:
		visual.visible = not activated
	if shape != null:
		# Sempre agenda: abrir e resetar no mesmo frame deve fechar a porta.
		shape.set_deferred("disabled", activated)
