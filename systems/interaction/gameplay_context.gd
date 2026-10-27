class_name GameplayContext
extends RefCounted

# Validação compartilhada sem dependência de efeitos em Interactable.
static func is_live(node: Variant) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return false
	var ancestor: Node = node
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	return true
