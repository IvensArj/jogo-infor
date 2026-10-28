extends Node

# Captura gráfica reproduzível, sem controlar janelas ou usar saves da campanha.
func _ready() -> void:
	get_tree().current_scene = null
	_run.call_deferred()


func _wait_frames(count: int) -> void:
	for frame in range(count):
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Falha ao gravar captura de teste: " + path)
		get_tree().quit(1)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Informe um diretório existente para as capturas após --.")
		get_tree().quit(1)
		return
	get_tree().change_scene_to_file(SystemsTestSession.ENTRY)
	await _wait_frames(40)
	await _capture(args[0].path_join("laboratorio.png"))
	if InputDeviceManager.touch_test_mode:
		var hud: CanvasLayer = InputDeviceManager.touch_controls
		var press := InputEventScreenTouch.new()
		press.index = 77
		press.pressed = true
		press.position = hud.joystick.get_global_transform_with_canvas() * (Vector2(1, 1).normalized() * hud.joystick.max_radius)
		get_viewport().push_input(press, true)
		await _wait_frames(12)
		await _capture(args[0].path_join("joystick_360.png"))
		var release := InputEventScreenTouch.new()
		release.index = 77
		release.position = press.position
		get_viewport().push_input(release, true)
		await _wait_frames(2)
		if Input.is_action_pressed("move_right") or Input.is_action_pressed("crouch"):
			push_error("Captura visual deixou joystick pressionado.")
			get_tree().quit(1)
			return
	var actor: CharacterBody2D = get_tree().current_scene.get_node("Player")
	actor.set_physics_process(false)
	get_tree().current_scene.get_node("AreaA/LongDocument").interact(actor)
	await _wait_frames(5)
	await _capture(args[0].path_join("inspecao.png"))
	DialogueManager.end_inspection()
	await _wait_frames(3)
	actor.position = Vector2(2860, 420)
	get_tree().current_scene.get_node("Camera").smooth_follow = false
	for id in get_tree().current_scene.get_node("AreaD/Puzzle").ordered_switch_ids:
		get_tree().current_scene.get_node("AreaD/Puzzle").submit_switch(id, actor)
	await _wait_frames(70)
	await _capture(args[0].path_join("puzzle.png"))
	SystemsTestSession.current(get_tree()).finish()
	get_tree().quit()
