class_name Interactor
extends Area2D

signal target_changed(target: Interactable)
signal interaction_performed(target: Interactable)

@export_group("Interação")
@export var interaction_action: StringName = &"interact"
@export var interaction_enabled: bool = true

@export_group("Seleção Inteligente")
@export_range(0.0, 50.0, 1.0) var facing_bonus: float = 12.0
@export_range(0.0, 50.0, 1.0) var switch_margin: float = 14.0
@export_range(0.0, 200.0, 1.0) var minimum_direction_speed: float = 30.0

var facing_direction: int = 1

var current_target: Interactable = null
var nearby_interactables: Array[Interactable] = []



func _ready() -> void:
	monitoring = true

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	DialogueManager.dialogue_started.connect(_update_target)
	DialogueManager.dialogue_finished.connect(_update_target)

	print("[DEBUG] Interactor inicializado!")

	var prompt: InteractionPrompt = get_parent().get_node_or_null("InteractionPrompt") as InteractionPrompt


	if prompt != null:
		prompt.set_input_action(interaction_action)
		target_changed.connect(_on_target_changed)
	else:
		push_warning(
			"[INTERACTION] InteractionPrompt não encontrado."
		)



func _on_target_changed(target: Interactable) -> void:
	var prompt: InteractionPrompt = get_parent().get_node_or_null("InteractionPrompt") as InteractionPrompt

	if prompt == null:
		return

	if target == null:
		prompt.hide_prompt()
	else:
		prompt.show_target(target, get_parent() as Node2D)


func _update_facing_direction() -> void:
	var player := get_parent() as CharacterBody2D

	if player == null:
		return

	var horizontal_velocity := player.velocity.x

	if absf(horizontal_velocity) < minimum_direction_speed:
		return

	if horizontal_velocity > 0.0:
		facing_direction = 1
	else:
		facing_direction = -1


func _physics_process(_delta: float) -> void:
	_update_facing_direction()
	_update_target()


func _unhandled_input(event: InputEvent) -> void:
	print("[DEBUG] Botão de interação pressionado!")
	if not interaction_enabled or DialogueManager.blocks_interaction():
		return

	if event.is_echo():
		return

	if event.is_action_pressed(interaction_action):
		try_interact()
		get_viewport().set_input_as_handled()



func try_interact() -> void:
	if not interaction_enabled or DialogueManager.blocks_interaction():
		return

	var player := get_parent() as Node2D

	if player == null:
		return

	_update_target()

	if not _can_target(current_target, player):
		return

	var target := current_target

	var success: bool = target.interact(player)

	if not is_instance_valid(self) or not Interactable.is_live(self):
		return
	if success and Interactable.is_live(target):
		interaction_performed.emit(target)

	if is_instance_valid(self) and Interactable.is_live(self):
		_update_target()




func _update_target() -> void:
	var player := get_parent() as Node2D

	if not interaction_enabled or player == null or DialogueManager.blocks_interaction():
		_set_target(null)
		return

	_cleanup_targets()

	var best_target: Interactable = null
	var best_priority: int = -1
	var best_distance: float = INF

	for target in nearby_interactables:
		if not _can_target(target, player):
			continue

		var target_priority: int = target.selection_priority
		var distance: float = _get_target_score(target, player)

		if target_priority > best_priority:
			best_target = target
			best_priority = target_priority
			best_distance = distance

		elif target_priority == best_priority:
			if distance < best_distance:
				best_target = target
				best_distance = distance

	if (
		_can_target(current_target, player)
		and is_instance_valid(best_target)
		and best_target != current_target
	):
		if current_target.selection_priority == best_priority:
			var current_distance := _get_target_score(
				current_target,
				player
			)

			if best_distance >= current_distance - switch_margin:
				best_target = current_target

	_set_target(best_target)



func _get_target_score(
	target: Interactable,
	player: Node2D
) -> float:
	var distance := global_position.distance_to(
		target.global_position
	)

	var horizontal_difference := (
		target.global_position.x - player.global_position.x
	)

	if horizontal_difference * facing_direction > 10.0:
		distance -= facing_bonus

	return distance


func _can_target(
	target: Variant,
	player: Node2D
) -> bool:
	if not is_instance_valid(target):
		return false

	if target.is_queued_for_deletion():
		return false

	if not target.is_inside_tree():
		return false

	if not nearby_interactables.has(target):
		return false

	return target.can_select(player)


func _cleanup_targets() -> void:
	for i in range(nearby_interactables.size() - 1, -1, -1):
		var target := nearby_interactables[i]

		if not is_instance_valid(target):
			nearby_interactables.remove_at(i)
			continue

		if target.is_queued_for_deletion():
			nearby_interactables.remove_at(i)
			continue

		if not target.is_inside_tree():
			nearby_interactables.remove_at(i)


func _set_target(target: Interactable) -> void:
	if current_target == target:
		return

	current_target = target
	target_changed.emit(current_target)



func _on_area_entered(area: Area2D) -> void:
	print("[DEBUG] Área detectada: ", area.name)

	if not area is Interactable:
		print("[DEBUG] Não é um Interactable!")
		return

	var interactable := area as Interactable

	print("[DEBUG] Objeto interativo encontrado: ",
	interactable.interaction_name)

	if not nearby_interactables.has(interactable):
		nearby_interactables.append(interactable)

	_update_target()



func _on_area_exited(area: Area2D) -> void:
	if not area is Interactable:
		return

	nearby_interactables.erase(area)
	_update_target()


func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value

	if not interaction_enabled:
		if current_target != null:
			current_target = null
			target_changed.emit(null)
	else:
		_update_target()
