
class_name InputGlyphResolver
extends RefCounted

const ICONS_ROOT := "res://assets/ui/input_prompts/"

const BUTTON_NAMES := {
	JOY_BUTTON_A: {
		"xbox": "a",
		"playstation": "cross",
		"nintendo": "b"
	},
	JOY_BUTTON_B: {
		"xbox": "b",
		"playstation": "circle",
		"nintendo": "a"
	},
	JOY_BUTTON_X: {
		"xbox": "x",
		"playstation": "square",
		"nintendo": "y"
	},
	JOY_BUTTON_Y: {
		"xbox": "y",
		"playstation": "triangle",
		"nintendo": "x"
	},
	JOY_BUTTON_LEFT_SHOULDER: {
		"xbox": "lb",
		"playstation": "l1",
		"nintendo": "l"
	},
	JOY_BUTTON_RIGHT_SHOULDER: {
		"xbox": "rb",
		"playstation": "r1",
		"nintendo": "r"
	},
	JOY_BUTTON_START: {
		"xbox": "start",
		"playstation": "options",
		"nintendo": "plus"
	},
	JOY_BUTTON_LEFT_STICK: {
		"xbox": "ls",
		"playstation": "l3",
		"nintendo": "ls"
	},
	JOY_BUTTON_RIGHT_STICK: {
		"xbox": "rs",
		"playstation": "r3",
		"nintendo": "rs"
	}
}


static func resolve(
	action: StringName,
	device: String,
	layout: String = "xbox"
) -> Dictionary:
	if device == "mobile":
		return _make_glyph("Toque", "")

	if not InputMap.has_action(action):
		return _make_glyph("?", "")

	var events := InputMap.action_get_events(action)

	for event in events:
		if device == "keyboard":
			if event is InputEventKey:
				return _from_keyboard(event)

			if event is InputEventMouseButton:
				return _from_mouse(event)

		elif device == "controller":
			if event is InputEventJoypadButton:
				return _from_controller(event, layout)

			if event is InputEventJoypadMotion:
				return _from_axis(event, layout)

	return _make_glyph("Sem atalho", "")


static func _from_keyboard(event: InputEventKey) -> Dictionary:
	var key_code := event.physical_keycode

	if key_code == KEY_NONE:
		key_code = event.keycode

	if key_code == KEY_NONE:
		key_code = event.key_label

	var key_name := OS.get_keycode_string(key_code)

	if key_name.is_empty():
		key_name = event.as_text()

	var file_name := key_name.to_lower().replace(" ", "_")

	return _make_glyph(
		key_name,
		"keyboard/" + file_name
	)


static func _from_mouse(event: InputEventMouseButton) -> Dictionary:
	var button_name := ""

	match event.button_index:
		MOUSE_BUTTON_LEFT:
			button_name = "mouse_left"
		MOUSE_BUTTON_RIGHT:
			button_name = "mouse_right"
		MOUSE_BUTTON_MIDDLE:
			button_name = "mouse_middle"

	if button_name.is_empty():
		return _make_glyph(
			"Mouse " + str(event.button_index),
			""
		)

	return _make_glyph(
		button_name.replace("_", " ").capitalize(),
		"keyboard/" + button_name
	)


static func _from_controller(
	event: InputEventJoypadButton,
	layout: String
) -> Dictionary:
	if not BUTTON_NAMES.has(event.button_index):
		return _make_glyph(
			"Botão " + str(event.button_index),
			""
		)

	var names: Dictionary = BUTTON_NAMES[event.button_index]

	var button_name: String = names.get(
		layout,
		names["xbox"]
	)

	var label := button_name.to_upper()

	match button_name:
		"cross":
			label = "✕"
		"circle":
			label = "○"
		"square":
			label = "□"
		"triangle":
			label = "△"

	return _make_glyph(
		label,
		layout + "/" + button_name
	)


static func _from_axis(
	event: InputEventJoypadMotion,
	layout: String
) -> Dictionary:
	var button_name := ""

	match event.axis:
		JOY_AXIS_TRIGGER_LEFT:
			match layout:
				"playstation":
					button_name = "l2"
				"nintendo":
					button_name = "zl"
				_:
					button_name = "lt"

		JOY_AXIS_TRIGGER_RIGHT:
			match layout:
				"playstation":
					button_name = "r2"
				"nintendo":
					button_name = "zr"
				_:
					button_name = "rt"

	if button_name.is_empty():
		return _make_glyph(
			"Eixo " + str(event.axis),
			""
		)

	return _make_glyph(
		button_name.to_upper(),
		layout + "/" + button_name
	)


static func _make_glyph(
	label: String,
	relative_path: String
) -> Dictionary:
	var texture: Texture2D = null

	if not relative_path.is_empty():
		var path := ICONS_ROOT + relative_path + ".png"

		if ResourceLoader.exists(path, "Texture2D"):
			texture = ResourceLoader.load(
				path,
				"Texture2D"
			) as Texture2D

	return {
		"text": label,
		"texture": texture
	}
