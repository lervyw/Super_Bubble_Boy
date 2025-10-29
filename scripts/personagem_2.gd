extends CharacterBody2D

# ----- ENUMS -----
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
var target_form: Form = Form.NORMAL

var unlocked_forms = {
	Form.NORMAL: true,
	Form.BUBBLE: false,
	Form.SUPER: false
}

# ------------------------------------------------------------
func _ready() -> void:
	# Conecta o sinal de ataque vindo do Textura2
	if $Sprite2D.has_signal("attack_finished"):
		$Sprite2D.attack_finished.connect(_on_attack_finished)

# ------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if in_water:
		velocity.y += gravity * 0.2 * delta
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

# ------------------------------------------------------------
# 🔹 JUMP
func jump_state(delta: float) -> void:
	if on_ground:
		velocity.y = jump_force
		on_ground = false

	handle_horizontal_input()

	if is_on_floor():
		change_state(State.IDLE)

# ------------------------------------------------------------
# 🔹 ATTACK (baseado em estado, sem booleanas)
func attack_state(delta: float) -> void:
	velocity = Vector2.ZERO
	# Nada é chamado diretamente — o texture cuida da animação


# Callback vem de texture_2.gd:
func _on_attack_finished() -> void:
	# Retorna ao idle quando a animação de ataque termina
	change_state(State.IDLE)

# ------------------------------------------------------------
# 🔹 CROUCH
func crouch_state(delta: float) -> void:
	velocity.x = 0
	if not Input.is_action_pressed("crouch"):
		change_state(State.IDLE)

# ------------------------------------------------------------
# 🔹 DASH
func dash_state(delta: float) -> void:
	if dash_timer <= 0.0:
		dash_timer = dash_time
		var dir := int(sign(Input.get_axis("ui_left", "ui_right")))
		if dir == 0:
			dir = -1 if $Sprite2D.flip_h else 1
		velocity.x = dir * dash_speed
		velocity.y = 0

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

# ------------------------------------------------------------
# 🔹 SWIM
func swim_state(delta: float) -> void:
	var dir_x := Input.get_axis("ui_left", "ui_right")
	var dir_y := Input.get_axis("ui_up", "ui_down")

	velocity.x = dir_x * speed * 0.5

	var sink_force: float
	match form:
		Form.BUBBLE:
			sink_force = 10.0
		Form.SUPER:
			sink_force = 70.0
		_:
			sink_force = 50.0

	velocity.y += sink_force * delta
	velocity.y += dir_y * speed * 0.3
	velocity.y = clamp(velocity.y, -100, 100)

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
		return
	if not unlocked_forms.get(target_form, false):
		return

	self.target_form = target_form
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

	await get_tree().create_timer(0.5).timeout
	change_state(State.IDLE)
