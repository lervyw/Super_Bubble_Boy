extends CharacterBody2D

# ----- ENUM DE ESTADOS -----
enum State { IDLE, WALK, JUMP, ATTACK, CROUCH, DASH, TRANSFORM, DEAD }
var state: State = State.IDLE

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

# ------------------------------------------------------------
func _physics_process(delta: float) -> void:
	handle_state(delta)
	move_and_slide()

# ------------------------------------------------------------
func handle_state(delta: float) -> void:
	on_ground = is_on_floor()

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

# ------------------------------------------------------------
# 🔹 IDLE
func idle_state(delta: float) -> void:
	animation_player.play("Idle")
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

# ------------------------------------------------------------
func handle_horizontal_input() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * speed
	if dir != 0:
		$Sprite2D.flip_h = dir < 0

# ------------------------------------------------------------
func change_state(new_state: State) -> void:
	state = new_state
