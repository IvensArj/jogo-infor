
extends CanvasLayer

@export_group("Digitação")
@export var characters_per_second: float = 45.0

@onready var panel: PanelContainer = $DialoguePanel
@onready var speaker_name: Label = $DialoguePanel/MarginContainer/VBoxContainer/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialoguePanel/MarginContainer/VBoxContainer/DialogueText
@onready var continue_indicator: Label = $DialoguePanel/MarginContainer/VBoxContainer/ContinueIndicator

var is_typing: bool = false
var character_progress: float = 0.0


func _ready() -> void:
	panel.hide()

	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.line_changed.connect(_on_line_changed)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)


func _process(delta: float) -> void:
	if not is_typing:
		return

	character_progress += characters_per_second * delta

	var total := dialogue_text.get_total_character_count()
	var visible_count := mini(
		int(character_progress),
		total
	)

	dialogue_text.visible_characters = visible_count

	if visible_count >= total:
		_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not DialogueManager.is_active:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		
		if Engine.get_process_frames() == DialogueManager.started_frame:
			get_viewport().set_input_as_handled()
			return
		
		if is_typing:
			_finish_typing()
		else:
			DialogueManager.next_line()


func _on_dialogue_started() -> void:
	panel.show()


func _on_line_changed(line: DialogueLine) -> void:
	speaker_name.text = line.speaker
	dialogue_text.text = line.text

	dialogue_text.visible_characters = 0
	character_progress = 0.0
	is_typing = true

	continue_indicator.hide()


func _finish_typing() -> void:
	is_typing = false
	dialogue_text.visible_characters = -1
	continue_indicator.show()


func _on_dialogue_finished() -> void:
	is_typing = false
	character_progress = 0.0

	panel.hide()
