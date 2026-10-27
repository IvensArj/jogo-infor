
extends CharacterBody2D

# ==========================================
# CONFIGURAÇÕES
# ==========================================

@export_group("Movimento")
@export var max_speed: float = 260.0
@export var acceleration: float = 1400.0
@export var friction: float = 1800.0
@export_range(0.0, 1.0) var air_control: float = 0.75

@export_group("Pulo")
@export var tile_size: float = 32.0
@export var jump_height_tiles: float = 2.65
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export_range(0.0, 1.0) var jump_cut: float = 0.45
@export_range(1, 3) var max_jumps: int = 2

@export_group("Gravidade")
@export var rising_gravity: float = 0.85
@export var falling_gravity: float = 1.6
@export var max_fall_speed: float = 700.0

@export_group("Paredes")
@export var wall_slide_speed: float = 100.0
@export var wall_slide_duration: float = 0.8
@export var wall_jump_horizontal: float = 220.0
@export var wall_jump_lock_time: float = 0.12

@export_group("Dash")
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.22
@export var dash_cooldown: float = 0.5
@export_range(0.0, 1.0) var dash_exit_speed: float = 0.65

@export_group("Agachamento")
@export_range(0.3, 0.85, 0.05) var crouch_height_ratio: float = 0.55
@export_range(0.1, 1.0, 0.05) var crouch_speed_multiplier: float = 0.45


# ==========================================
# NÓS
# ==========================================

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# ==========================================
# ESTADOS E RECURSOS
# ==========================================

var facing: int = 1

# Pulo
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var floor_jump_available: bool = true
var air_jumps_left: int = 1

# Paredes
# +1 = normal apontando à direita
# -1 = normal apontando à esquerda
#  0 = nenhum lado utilizado
var last_wall_jump_side: int = 0
var slide_wall_side: int = 0
var wall_slide_timer: float = 0.0
var wall_jump_lock: float = 0.0

# Dash
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0
var air_dash_available: bool = true

# Agachamento
var is_crouching: bool = false

var standing_shape: RectangleShape2D
var crouching_shape: RectangleShape2D
var headroom_shape: RectangleShape2D

var standing_position: Vector2
var crouching_position: Vector2
var headroom_position: Vector2


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:
	air_jumps_left = maxi(max_jumps - 1, 0)

	# Ajuda a preservar contato com pisos.
	floor_snap_length = 4.0

	_setup_crouch()
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.inspection_started.connect(_on_dialogue_started)
	if DialogueManager.blocks_interaction():
		_on_dialogue_started()


func _on_dialogue_started() -> void:
	# Descarta comandos pendentes sem interromper a queda ou a subida.
	jump_buffer_timer = 0.0
	wall_jump_lock = 0.0
	_finish_dash()


# ==========================================
# LOOP DE FÍSICA
# ==========================================

func _physics_process(delta: float) -> void:
	var controls_blocked := DialogueManager.blocks_interaction()
	var direction := 0.0 if controls_blocked else Input.get_axis(
		"move_left",
		"move_right"
	)

	var grounded_before := is_on_floor()

	# 1. Recursos e entradas
	_update_timers(delta, grounded_before)
	_update_crouch(grounded_before, controls_blocked)
	if controls_blocked:
		jump_buffer_timer = 0.0
	else:
		_update_jump_buffer(delta)

	# 2. Dash tem prioridade sobre o movimento comum
	if not controls_blocked and not is_dashing:
		_try_start_dash(direction)

	if is_dashing:
		_update_dash(delta, grounded_before)

	else:
		# 3. Física normal
		if not grounded_before:
			_apply_gravity(delta)

		if not controls_blocked:
			_update_wall_slide(delta, direction)

		# 4. Processamento dos pulos
		var jumped := false
		if not controls_blocked:
			jumped = _try_jump(grounded_before)
			_apply_jump_cut()

		_apply_horizontal_movement(
			delta,
			direction,
			grounded_before,
			jumped
		)

	# 5. Uma única resolução física por quadro
	move_and_slide()

	# 6. Colisão durante o dash
	if is_dashing and is_on_wall():
		var normal := get_wall_normal()

		if normal.x * dash_direction < -0.7:
			_finish_dash()

	# 7. Restaura recursos ao aterrissar
	if not grounded_before and is_on_floor():
		_reset_on_landing()


# ==========================================
# TEMPORIZADORES
# ==========================================

func _update_timers(
	delta: float,
	grounded: bool
) -> void:

	dash_cooldown_timer = maxf(
		dash_cooldown_timer - delta,
		0.0
	)

	wall_jump_lock = maxf(
		wall_jump_lock - delta,
		0.0
	)

	if grounded:
		_reset_on_landing()

	elif floor_jump_available:
		coyote_timer = maxf(
			coyote_timer - delta,
			0.0
		)

		if coyote_timer <= 0.0:
			floor_jump_available = false


func _update_jump_buffer(delta: float) -> void:
	if is_crouching:
		jump_buffer_timer = 0.0
		return

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	else:
		jump_buffer_timer = maxf(
			jump_buffer_timer - delta,
			0.0
		)


func _reset_on_landing() -> void:
	# Pulo normal e pulo duplo
	floor_jump_available = true
	coyote_timer = coyote_time
	air_jumps_left = maxi(max_jumps - 1, 0)

	# Permite novamente qualquer lado de parede
	last_wall_jump_side = 0

	# Restaura o orçamento de deslize
	slide_wall_side = 0
	wall_slide_timer = 0.0

	# Restaura a carga aérea do dash,
	# mas NÃO elimina seu cooldown.
	air_dash_available = true


# ==========================================
# MOVIMENTO HORIZONTAL
# ==========================================

func _apply_horizontal_movement(
	delta: float,
	direction: float,
	grounded: bool,
	jumped: bool
) -> void:

	# Preserva o impulso inicial do wall jump.
	if jumped or wall_jump_lock > 0.0:
		return

	var control := (
		1.0 if grounded
		else air_control
	)

	var target_speed := max_speed

	if is_crouching:
		target_speed *= crouch_speed_multiplier

	if absf(direction) > 0.01:
		facing = 1 if direction > 0.0 else -1

		velocity.x = move_toward(
			velocity.x,
			direction * target_speed,
			acceleration * control * delta
		)

	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			friction * control * delta
		)


# ==========================================
# GRAVIDADE
# ==========================================

func _apply_gravity(delta: float) -> void:
	var gravity := get_gravity().y

	var gravity_multiplier := (
		rising_gravity if velocity.y < 0.0
		else falling_gravity
	)

	velocity.y += gravity * gravity_multiplier * delta

	velocity.y = minf(
		velocity.y,
		max_fall_speed
	)


# ==========================================
# PULOS
# ==========================================

func _get_jump_velocity() -> float:
	var height := tile_size * jump_height_tiles

	var gravity := (
		get_gravity().y * rising_gravity
	)

	return -sqrt(
		2.0 * maxf(gravity, 1.0) * height
	)


func _perform_jump() -> void:
	velocity.y = _get_jump_velocity()

	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	floor_jump_available = false


func _try_jump(grounded: bool) -> bool:
	if jump_buffer_timer <= 0.0:
		return false

	if is_crouching:
		return false

	# PRIORIDADE 1: pulo normal / coyote time
	if floor_jump_available and (
		grounded or coyote_timer > 0.0
	):
		_perform_jump()
		return true

	var wall_side := _get_wall_side()

	# PRIORIDADE 2: pulo na parede oposta
	if (
		wall_side != 0
		and GameState.has_ability("wall_jump")
		and wall_side != last_wall_jump_side
	):
		_perform_jump()

		velocity.x = (
			float(wall_side)
			* wall_jump_horizontal
		)

		facing = wall_side

		# Registra qual lado forneceu o salto.
		last_wall_jump_side = wall_side

		wall_jump_lock = wall_jump_lock_time

		# Não restaura o pulo duplo.
		# Isso evita recuperar saltos infinitamente.
		return true

	# PRIORIDADE 3: pulo aéreo
	if air_jumps_left > 0 and GameState.has_ability("double_jump"):
		air_jumps_left -= 1

		_perform_jump()
		return true

	return false


func _apply_jump_cut() -> void:
	if (
		Input.is_action_just_released("jump")
		and velocity.y < 0.0
	):
		velocity.y *= jump_cut


# ==========================================
# INTERAÇÃO COM PAREDES
# ==========================================

func _get_wall_side() -> int:
	# Os contatos vêm do último move_and_slide().
	if not is_on_wall() or is_on_floor():
		return 0

	var normal := get_wall_normal()

	# Ignora contatos que não representam
	# paredes predominantemente verticais.
	if absf(normal.x) < 0.7:
		return 0

	return 1 if normal.x > 0.0 else -1


func _update_wall_slide(
	delta: float,
	direction: float
) -> void:

	var wall_side := _get_wall_side()

	if wall_side == 0:
		return

	# Cada lado possui uma oportunidade de deslize.
	# Voltar ao MESMO lado não reinicia o tempo.
	if wall_side != slide_wall_side:
		slide_wall_side = wall_side
		wall_slide_timer = wall_slide_duration

	# Precisa estar caindo e pressionando a parede.
	var pressing_wall := (
		direction * float(wall_side) < -0.2
	)

	if not pressing_wall:
		return

	if velocity.y <= 0.0:
		return

	if wall_slide_timer <= 0.0:
		return

	# Limita a velocidade vertical temporariamente.
	velocity.y = minf(
		velocity.y,
		wall_slide_speed
	)

	wall_slide_timer = maxf(
		wall_slide_timer - delta,
		0.0
	)


# ==========================================
# DASH
# ==========================================

func _try_start_dash(direction: float) -> void:
	if not GameState.has_ability("dash"):
		return
	if not Input.is_action_just_pressed("dash"):
		return

	if is_crouching:
		return

	# Exige direção horizontal.
	if absf(direction) <= 0.2:
		return

	if dash_cooldown_timer > 0.0:
		return

	# Um dash por fase aérea.
	if not is_on_floor() and not air_dash_available:
		return

	is_dashing = true
	velocity.y = 0.0

	dash_direction = (
		1.0 if direction > 0.0 else -1.0
	)

	facing = int(dash_direction)

	dash_timer = dash_duration

	# O cooldown não pode terminar antes do dash.
	dash_cooldown_timer = maxf(
		dash_cooldown,
		dash_duration
	)

	# Gasta a carga aérea até tocar o chão.
	air_dash_available = false


func _update_dash(
	delta: float,
	grounded: bool
) -> void:
	velocity.y = 0.0

	dash_timer = maxf(
		dash_timer - delta,
		0.0
	)

	if dash_timer <= 0.0:
		_finish_dash()
		if not grounded:
			_apply_gravity(delta)
		return

	# Direção e velocidade permanecem fixas.
	velocity.x = dash_direction * dash_speed


func _finish_dash() -> void:
	if not is_dashing:
		return

	is_dashing = false
	dash_timer = 0.0

	# Remove o excesso de velocidade ao terminar.
	velocity.x = (
		dash_direction
		* max_speed
		* dash_exit_speed
	)


# ==========================================
# AGACHAMENTO
# ==========================================

func _setup_crouch() -> void:
	assert(
		collision_shape.shape is RectangleShape2D,
		"Player precisa de RectangleShape2D."
	)

	standing_shape = (
		collision_shape.shape.duplicate()
		as RectangleShape2D
	)

	crouching_shape = (
		standing_shape.duplicate()
		as RectangleShape2D
	)

	standing_position = collision_shape.position

	var full_height := standing_shape.size.y

	var short_height := (
		full_height * crouch_height_ratio
	)

	crouching_shape.size.y = short_height

	var height_difference := (
		full_height - short_height
	)

	# Preserva a posição dos pés.
	crouching_position = (
		standing_position
		+ Vector2(0.0, height_difference * 0.5)
	)

	# Volume acima da cabeça que precisa estar livre.
	headroom_shape = RectangleShape2D.new()

	headroom_shape.size = Vector2(
		maxf(standing_shape.size.x - 0.5, 0.1),
		maxf(height_difference - 0.5, 0.1)
	)

	var standing_top := (
		standing_position.y - full_height * 0.5
	)

	var crouching_top := (
		crouching_position.y - short_height * 0.5
	)

	headroom_position = Vector2(
		standing_position.x,
		(standing_top + crouching_top) * 0.5
	)

	collision_shape.shape = standing_shape
	collision_shape.position = standing_position


func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()

	query.shape = headroom_shape

	query.transform = (
		global_transform
		* Transform2D(0.0, headroom_position)
	)

	query.collision_mask = collision_mask
	query.exclude = [get_rid()]

	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 0.0

	var hits := (
		get_world_2d()
		.direct_space_state
		.intersect_shape(query, 1)
	)

	return hits.is_empty()


func _set_crouching(enabled: bool) -> void:
	if is_crouching == enabled:
		return

	is_crouching = enabled

	if enabled:
		collision_shape.shape = crouching_shape
		collision_shape.position = crouching_position
	else:
		collision_shape.shape = standing_shape
		collision_shape.position = standing_position


func _update_crouch(grounded: bool, controls_blocked: bool = false) -> void:
	var holding_crouch := (
		not controls_blocked and Input.is_action_pressed("crouch")
	)

	if not is_crouching:
		if (
			holding_crouch
			and grounded
			and not is_dashing
		):
			_set_crouching(true)

		return

	# Não tenta levantar enquanto segura o botão.
	if holding_crouch:
		return

	# Permanece agachado em túneis baixos.
	# Levanta automaticamente quando há espaço.
	if _can_stand():
		_set_crouching(false)
