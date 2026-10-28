class_name TouchActionSource
extends RefCounted

## Uma fonte virtual possui suas forças; nunca libera o estado global da ação.
static var _next_device: int = 10000
var device_id: int
var _strengths: Dictionary = {}


func _init() -> void:
	device_id = _next_device
	_next_device += 1


func set_strength(action: StringName, strength: float) -> void:
	var value := clampf(strength, 0.0, 1.0)
	var previous: float = _strengths.get(action, 0.0)
	if is_equal_approx(previous, value):
		return
	if not InputMap.has_action(action):
		push_warning("[TOUCH] Ação não cadastrada: " + str(action))
		return
	# Atualiza antes de despachar: uma interação pode ocultar o HUD neste callback.
	if value == 0.0:
		_strengths.erase(action)
	else:
		_strengths[action] = value
	var event := InputEventAction.new()
	event.action = action
	event.event_index = -1
	event.device = device_id
	event.pressed = value > 0.0
	event.strength = value
	Input.parse_input_event(event)
	# A engine drena a fila na fase normal de entrada. Fazer flush aqui, dentro
	# de _input/pressed, pode reentrar na distribuição de eventos de toque e
	# consumir releases enquanto os grupos de entrada ainda estão bloqueados.


func release_all() -> void:
	for action: StringName in _strengths.keys():
		set_strength(action, 0.0)
