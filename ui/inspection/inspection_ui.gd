class_name InspectionUI
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/Column/Title
@onready var scroll: ScrollContainer = $Panel/Margin/Column/Scroll
@onready var body_label: RichTextLabel = $Panel/Margin/Column/Scroll/Contents/Body
@onready var image_view: TextureRect = $Panel/Margin/Column/Scroll/Contents/Image
@onready var close_button: Button = $Panel/Margin/Column/Close

var opened_frame: int = -1
var _previous_focus: WeakRef
var _owns_modal: bool = false


func _ready() -> void:
	add_to_group("InspectionUI")
	panel.hide()
	close_button.pressed.connect(close)
	DialogueManager.inspection_finished.connect(_on_closed)


func _process(_delta: float) -> void:
	if _owns_modal:
		SafeAreaLayout.fit_control(panel)


func open_content(data: InspectionData, source: Node) -> bool:
	if data == null or not DialogueManager.begin_inspection(source, self):
		return false
	_owns_modal = true
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	opened_frame = Engine.get_process_frames()
	title_label.text = data.title
	body_label.text = data.body
	image_view.texture = data.image
	image_view.visible = data.image != null
	scroll.scroll_vertical = 0
	panel.show()
	scroll.grab_focus()
	return true


func _input(event: InputEvent) -> void:
	if not _owns_modal or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if Engine.get_process_frames() != opened_frame:
			close()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var direction := 1 if event.is_action_pressed("ui_down") else -1
		scroll.scroll_vertical += direction * 90
		get_viewport().set_input_as_handled()


func close() -> void:
	if _owns_modal:
		DialogueManager.end_inspection()


func _on_closed() -> void:
	if not _owns_modal:
		return
	_owns_modal = false
	panel.hide()
	var focus := _previous_focus.get_ref() as Control if _previous_focus != null else null
	_previous_focus = null
	if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree():
		focus.grab_focus()


func _exit_tree() -> void:
	close()
