extends CharacterBody2D

# ----- ENUM DE ESTADOS -----
enum State { IDLE, WALK, JUMP, ATTACK, CROUCH, DASH, TRANSFORM, DEAD, SWIM }

enum Form { NORMAL, BUBBLE, SUPER }

# ----- EXPORTS -----
@export var speed := 150.0
@export var jump_force := -350.0
@export var gravity := 900.0
@export var dash_speed := 400.0
@export var dash_time := 0.2
@export var animation_player: AnimationPlayer

# ----- VARIÁVEIS -----
var dash_timer := 0.0
var on_ground := false


var form: Form = Form.NORMAL
var state: State = State.IDLE
var in_water: bool = false

var unlocked_forms = {
	Form.NORMAL: true,  # sempre disponível
	Form.BUBBLE: false,
	Form.SUPER: false
}

# ------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if in_water:
		velocity.y += gravity * 0.2 * delta  # gravidade reduzida
	else:
		velocity.y += gravity * delta
	
	handle_state(delta)

	if Input.is_action_just_pressed("forma1"):
		try_transform(Form.BUBBLE)
	elif Input.is_action_just_pressed("forma2"):
		try_transform(Form.SUPER)
	
	move_and_slide()
# ------------------------------------------------------------
func handle_state(delta: float) -> void:
	on_ground = is_on_floor()
	
	if in_water and state != State.SWIM:
		change_state(State.SWIM)
		print('mudou para SWIM')

	match state:
		State.IDLE:
			idle_state(delta)
		State.WALK:
			walk_state(delta)
		State.JUMP:
			jump_state(delta)
		State.ATTACK:
			attack_state(delta)
		State.CROUCH:
			crouch_state(delta)
		State.DASH:
			dash_state(delta)
		State.TRANSFORM:
			transform_state(delta)
		State.DEAD:
			dead_state(delta)
		State.SWIM:
			swim_state(delta)

# ------------------------------------------------------------
# 🔹 IDLE
func idle_state(delta: float) -> void:
	
	match form:
		Form.NORMAL:
			animation_player.play("Idle")
		Form.BUBBLE:
			animation_player.play("Bubble_Idle")
		Form.SUPER:
			animation_player.play("Super_Idle")
			
#	animation_player.play("Idle")
	velocity.y += gravity * delta
	handle_horizontal_input()

	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif abs(Input.get_axis("ui_left", "ui_right")) > 0:
		change_state(State.WALK)
	elif Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
	elif Input.is_action_pressed("crouch"):
		change_state(State.CROUCH)
	elif Input.is_action_just_pressed("dash"):
		change_state(State.DASH)

# ------------------------------------------------------------
# 🔹 WALK
func walk_state(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0:
		velocity.x = dir * speed
		$Sprite2D.flip_h = dir < 0
		animation_player.play("Walk")
	else:
		change_state(State.IDLE)

	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
	elif Input.is_action_pressed("crouch"):
		change_state(State.CROUCH)
	elif Input.is_action_just_pressed("dash"):
		change_state(State.DASH)

	velocity.y += gravity * delta

# ------------------------------------------------------------
# 🔹 JUMP
func jump_state(delta: float) -> void:
	if on_ground:
		velocity.y = jump_force
		animation_player.play("Jump")
		on_ground = false

	velocity.y += gravity * delta

	if velocity.y > 0:
		animation_player.play("Fall")

	handle_horizontal_input()

	if is_on_floor():
		change_state(State.IDLE)

# ------------------------------------------------------------
# 🔹 ATTACK
func attack_state(delta: float) -> void:
	velocity = Vector2.ZERO
	animation_player.play("Attack")
	await animation_player.animation_finished
	change_state(State.IDLE)

# ------------------------------------------------------------
# 🔹 CROUCH
func crouch_state(delta: float) -> void:
	velocity.x = 0
	animation_player.play("Crouch")
	if not Input.is_action_pressed("crouch"):
		change_state(State.IDLE)

# ------------------------------------------------------------
# 🔹 DASH
func dash_state(delta: float) -> void:
	if dash_timer <= 0.0:
		dash_timer = dash_time
		# pega -1, 0 ou 1
		var dir := int(sign(Input.get_axis("ui_left", "ui_right")))
		if dir == 0:
			# ternário no estilo Python do GDScript
			dir = -1 if $Sprite2D.flip_h else 1
		velocity.x = dir * dash_speed
		velocity.y = 0
		animation_player.play("Dash")

	dash_timer -= delta
	if dash_timer <= 0:
		change_state(State.IDLE)

# ------------------------------------------------------------
# 🔹 TRANSFORM
func transform_state(delta: float) -> void:
	velocity = Vector2.ZERO
	animation_player.play("Transform")
	await animation_player.animation_finished
	change_state(State.IDLE)

# ------------------------------------------------------------
# 🔹 DEAD
func dead_state(delta: float) -> void:
	velocity = Vector2.ZERO
	animation_player.play("Dead")

# -----------------------------------------------------------
# SWIM
func swim_state(delta: float) -> void:
	animation_player.play("Swim")

	var dir_x := Input.get_axis("ui_left", "ui_right")
	var dir_y := Input.get_axis("ui_up", "ui_down")

	# Movimento reduzido na água
	velocity.x = dir_x * speed * 0.5

	# Afundamento leve natural
	var sink_force: float
	match form:
		Form.BUBBLE:
			sink_force = 10.0
		Form.SUPER:
			sink_force = 70.0
		_:
			sink_force = 50.0


	velocity.y += sink_force * delta

	# Controle do jogador (para subir/descer)
	velocity.y += dir_y * speed * 0.3

	# Limitador de velocidade vertical para não despencar
	velocity.y = clamp(velocity.y, -100, 100)

	# Sai da água
	if not in_water:
		change_state(State.IDLE)

# ------------------------------------------------------------
func handle_horizontal_input() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * speed
	if dir != 0:
		$Sprite2D.flip_h = dir < 0

# ------------------------------------------------------------
func change_state(new_state: State) -> void:
	state = new_state

# ------------------------------------------------------------
func try_transform(target_form: Form) -> void:
	if target_form == form:
		return # já está nessa forma
	if not unlocked_forms.get(target_form, false):
		return # forma ainda não desbloqueada

	change_state(State.TRANSFORM)
	perform_transform(target_form)

# -----------------------------------------------------------
func perform_transform(target_form: Form) -> void:
	form = target_form
	match form:
		Form.NORMAL:
			speed = 150
			jump_force = -300
			gravity = 500
		Form.BUBBLE:
			speed = 50
			jump_force = -50
			gravity = 50
		Form.SUPER:
			speed = 100
			jump_force = -420
			gravity = 600

	# Atualiza animação da forma
	if $Sprite2D.has_method("play"):
		$Sprite2D.play(get_form_animation(form))

	# Sai do estado de transformação após um pequeno delay
	await get_tree().create_timer(0.5).timeout
	change_state(State.IDLE)


func get_form_animation(f: Form) -> String:
	match f:
		Form.NORMAL:
			return "Normal_Idle"
			print('ta idle')
		Form.BUBBLE:
			return "Bubble_Idle"
			print('Ta bubble')
		Form.SUPER:
			print('Ta super')
			return "Super_Idle"
	return "Idle"
	print('voltou normal')
