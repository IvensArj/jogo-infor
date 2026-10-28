class_name SafeAreaLayout
extends RefCounted


static func viewport_rect(viewport: Viewport) -> Rect2:
	var full := viewport.get_visible_rect()
	if not OS.has_feature("mobile"):
		return full
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return full
	var window_position := Vector2(DisplayServer.window_get_position())
	var inverse := viewport.get_screen_transform().affine_inverse()
	var begin := inverse * (Vector2(safe.position) - window_position)
	var end := inverse * (Vector2(safe.end) - window_position)
	var result := full.intersection(Rect2(begin, end - begin))
	return result if result.has_area() else full


static func fit_control(control: Control, margin: Vector2 = Vector2(24, 20)) -> void:
	var area := viewport_rect(control.get_viewport()).grow_individual(-margin.x, -margin.y, -margin.x, -margin.y)
	var full := control.get_viewport().get_visible_rect()
	control.offset_left = area.position.x
	control.offset_top = area.position.y
	control.offset_right = area.end.x - full.end.x
	control.offset_bottom = area.end.y - full.end.y
