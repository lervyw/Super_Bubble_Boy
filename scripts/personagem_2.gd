extends CharacterBody2D

enum State { IDLE, WALK, JUMP, ATTACK, CROUCH, DASH, TRANSFORM, DEAD, SWIM }
enum Form { NORMAL, BUBBLE, SUPER }

@export var speed := 150.0
@export var jump_force := -450.0
@export var super_jump_force := -350.0  # Pulo mais pesado para forma SUPER
@export var gravity := 900.0
@export var dash_speed := 400.0
@export var dash_time := 0.2
@export var animation_player: AnimationPlayer

@export_group("Dash Settings")
## Cancela gravidade durante dash no ar
@export var dash_stops_fall: bool = true

## Cooldown entre dashes (em segundos)
@export_range(0.0, 2.0) var dash_cooldown: float = 0.3

# Referência para área de ataque
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

# Modificadores de velocidade na água por forma
@export var water_speed_normal := 0.6  # 60% da velocidade
@export var water_speed_bubble := 0.9  # 90% da velocidade (bolha é mais eficiente)
@export var water_speed_super := 0.5   # 50% da velocidade (super é mais pesado)

# Física de flutuação na água
@export var water_gravity_normal := 150.0   # Gravidade reduzida na água
@export var water_gravity_bubble := 50.0    # Bolha flutua muito
@export var water_gravity_super := 250.0    # Super afunda mais
@export var water_buoyancy := 80.0          # Força de flutuação para cima
@export var water_drag := 0.92              # Arrasto da água (0-1)

var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var on_ground := false
var form: Form = Form.NORMAL
var state: State = State.IDLE
var in_water: bool = false
var target_form: Form = Form.NORMAL

var unlocked_forms = {
	Form.NORMAL: true,
	Form.BUBBLE: false,
	Form.SUPER: false
}

var bubble_jump_count := 0
var max_bubble_jumps := 40

func _ready() -> void:
	if $Sprite2D:
		$Sprite2D.attack_finished.connect(_on_attack_finished)
	
	# Desativa a área de ataque inicialmente
	if attack_collision:
		attack_collision.disabled = true
		print("✅ Attack area desativada no início")

func _physics_process(delta: float) -> void:
	on_ground = is_on_floor()
	if on_ground:
		bubble_jump_count = 0

	# Atualiza cooldown do dash
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Aplica física de água ou gravidade normal
	if in_water:
		apply_water_physics(delta)
	else:
		apply_normal_gravity(delta)

	handle_input()
	handle_state(delta)
	move_and_slide()

func apply_normal_gravity(delta: float) -> void:
	# Não aplica gravidade durante dash se configurado
	if state == State.DASH and dash_stops_fall:
		return
	
	if form == Form.BUBBLE:
		velocity.y += 50 * delta
	else:
		velocity.y += gravity * delta

func apply_water_physics(delta: float) -> void:
	# Aplica gravidade reduzida baseada na forma
	var water_grav := water_gravity_normal
	match form:
		Form.BUBBLE:
			water_grav = water_gravity_bubble
		Form.SUPER:
			water_grav = water_gravity_super
		Form.NORMAL:
			water_grav = water_gravity_normal
	
	velocity.y += water_grav * delta
	
	# Aplica força de flutuação (empurra para cima)
	velocity.y -= water_buoyancy * delta
	
	# Aplica arrasto da água (desacelera movimento vertical)
	velocity.y *= water_drag
	velocity.x *= water_drag

func handle_input() -> void:
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_up"):
		handle_jump()

	if Input.is_action_just_pressed("forma1"):
		print('bubble')
		toggle_transform(Form.BUBBLE)
	elif Input.is_action_just_pressed("forma2"):
		print('super')
		toggle_transform(Form.SUPER)
	elif Input.is_action_just_pressed("normal"):
		print('normal')
		toggle_transform(Form.NORMAL)

func handle_jump() -> void:
	match form:
		Form.BUBBLE:
			if in_water:
				# Na água, pulo da bolha impulsiona para cima
				velocity.y = -100
				bubble_jump_count += 1
			elif bubble_jump_count < max_bubble_jumps:
				velocity.y = -50
				bubble_jump_count += 1
		Form.SUPER:
			if in_water:
				# Pulo na água dá impulso para cima (mais pesado)
				velocity.y = -120
			elif is_on_floor():
				velocity.y = super_jump_force  # Usa força de pulo específica do SUPER
		_:  # Form.NORMAL
			if in_water:
				# Pulo na água dá impulso para cima
				velocity.y = -150
			elif is_on_floor():
				velocity.y = jump_force

func toggle_transform(target: Form) -> void:
	if state == State.TRANSFORM:
		return
	if form == target:
		start_transform(Form.NORMAL)
	elif unlocked_forms.get(target, false):
		start_transform(target)

func start_transform(new_form: Form) -> void:
	state = State.TRANSFORM
	target_form = new_form
	# Sprite2D.gd cuida da animação via handle_transform_animation()

func can_dash() -> bool:
	"""Verifica se pode dar dash (sem limite de quantidade, apenas cooldown)"""
	return dash_cooldown_timer <= 0

func handle_state(delta: float) -> void:
	match state:
		State.IDLE: idle_state()
		State.WALK: walk_state()
		State.JUMP: jump_state()
		State.ATTACK: attack_state()
		State.CROUCH: crouch_state()
		State.DASH: dash_state()
		State.TRANSFORM: transform_state()
		State.DEAD: dead_state()
		State.SWIM: swim_state()

func idle_state() -> void:
	handle_horizontal_input()
	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif abs(Input.get_axis("ui_left", "ui_right")) > 0:
		change_state(State.WALK)
	elif Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
		activate_attack_area()
	elif Input.is_action_pressed("crouch"):
		change_state(State.CROUCH)
	elif Input.is_action_just_pressed("dash") and can_dash():
		change_state(State.DASH)

func walk_state() -> void:
	handle_horizontal_input()
	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
		activate_attack_area()
	elif Input.is_action_pressed("crouch"):
		change_state(State.CROUCH)
	elif Input.is_action_just_pressed("dash") and can_dash():
		change_state(State.DASH)
	elif velocity.x == 0:
		change_state(State.IDLE)

func jump_state() -> void:
	handle_horizontal_input()
	
	# Permite dash no ar (ilimitado, respeitando apenas cooldown)
	if Input.is_action_just_pressed("dash") and can_dash():
		change_state(State.DASH)
	
	if is_on_floor():
		change_state(State.IDLE)

func attack_state() -> void:
	velocity = Vector2.ZERO

func crouch_state() -> void:
	velocity.x = 0
	if not Input.is_action_pressed("crouch"):
		change_state(State.IDLE)

func dash_state() -> void:
	if dash_timer <= 0.0:
		dash_timer = dash_time
		dash_cooldown_timer = dash_cooldown  # Inicia cooldown
		
		var dir: int = int(sign(Input.get_axis("ui_left", "ui_right")))
		if dir == 0:
			dir = -1 if $Sprite2D.flip_h else 1
		velocity.x = dir * dash_speed
		
		# Cancela queda durante dash
		if dash_stops_fall:
			velocity.y = 0

	dash_timer -= get_physics_process_delta_time()
	if dash_timer <= 0:
		# Volta para estado apropriado
		if is_on_floor():
			change_state(State.IDLE)
		else:
			change_state(State.JUMP)

func transform_state() -> void:
	velocity = Vector2.ZERO

func dead_state() -> void:
	die()

func swim_state() -> void:
	var dir_x := Input.get_axis("ui_left", "ui_right")
	var dir_y := Input.get_axis("ui_up", "ui_down")
	
	# Velocidade base para natação (já reduzida)
	var swim_speed := speed * 0.5
	
	# Aplica modificador adicional por forma
	match form:
		Form.NORMAL:
			swim_speed *= water_speed_normal
		Form.BUBBLE:
			swim_speed *= water_speed_bubble
		Form.SUPER:
			swim_speed *= water_speed_super
	
	velocity.x = dir_x * swim_speed
	velocity.y += dir_y * swim_speed * 0.6
	
	if not in_water:
		change_state(State.IDLE)

func handle_horizontal_input() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	var current_speed := speed
	
	# Aplica modificador de velocidade se estiver na água
	if in_water:
		match form:
			Form.NORMAL:
				current_speed *= water_speed_normal
			Form.BUBBLE:
				current_speed *= water_speed_bubble
			Form.SUPER:
				current_speed *= water_speed_super
	
	velocity.x = dir * current_speed
	if dir != 0:
		$Sprite2D.flip_h = dir < 0

func change_state(new_state: State) -> void:
	state = new_state

# ===== SISTEMA DE ATAQUE =====

func activate_attack_area() -> void:
	"""Ativa a área de ataque quando o player ataca"""
	if attack_collision:
		attack_collision.disabled = false
		print("⚔️ Attack area ATIVADA")

func deactivate_attack_area() -> void:
	"""Desativa a área de ataque após o ataque"""
	if attack_collision:
		attack_collision.disabled = true
		print("🛡️ Attack area DESATIVADA")

func _on_attack_finished() -> void:
	"""Chamado quando a animação de ataque termina"""
	deactivate_attack_area()
	change_state(State.IDLE)

# ===== MORTE =====

func die() -> void:
	state = State.DEAD
	animation_player.play("Dead")
	velocity = Vector2.ZERO
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
