
extends Camera2D

@export_group("Câmera")
@export var follow_speed: float = 8.0
@export var smooth_follow: bool = true

var target: Node2D


func _ready() -> void:
	get_target()


func _physics_process(delta: float) -> void:
	# Não tenta acessar um alvo inexistente.
	if not is_instance_valid(target):
		get_target()
		return

	# Usa coordenadas globais, independentemente
	# de onde a câmera esteja na árvore de nós.
	var target_position := target.global_position

	if smooth_follow:
		global_position = global_position.lerp(
			target_position,
			1.0 - exp(-follow_speed * delta)
		)
	else:
		global_position = target_position


func get_target() -> void:
	var nodes := get_tree().get_nodes_in_group("Player")

	for node in nodes:
		if node is Node2D:
			target = node
			return

	target = null
