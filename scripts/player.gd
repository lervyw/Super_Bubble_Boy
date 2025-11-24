extends CharacterBody2D

enum State { IDLE, WALK, JUMP, ATTACK, CROUCH, DASH, TRANSFORM, DEAD, SWIM }
enum Form { NORMAL, BUBBLE, SUPER }
enum GameMode { PLATAFORMA, METROIDVANIA }

@export var speed := 150.0
@export var jump_force := -450.0
@export var super_jump_force := -350.0
@export var gravity := 900.0
@export var dash_speed := 400.0
@export var dash_time := 0.2
@export var animation_player: AnimationPlayer
@export var audio_normal: AudioStreamPlayer
@export var audio_super: AudioStreamPlayer

@export_group("Death Settings")
@export_range(0.0, 5.0) var death_delay: float = 1.0

@export_group("Dash Settings")
@export var dash_stops_fall: bool = false
@export_range(0.0, 1.0) var dash_fall_factor: float = 0.3
@export_range(0.0, 2.0) var dash_cooldown: float = 0.3

@export_group("Damage Settings")
@export_range(0.0, 5.0) var invincibility_time: float = 1.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

@export var water_speed_normal := 0.6
@export var water_speed_bubble := 0.9
@export var water_speed_super := 0.5

@export var water_gravity_normal := 150.0
@export var water_gravity_bubble := 50.0
@export var water_gravity_super := 250.0
@export var water_buoyancy := 80.0
@export var water_drag := 0.92

@export var respawn_position: Vector2 = Vector2(288, 207)
@export var stats: Node = null

var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var on_ground := false
var form: Form = Form.NORMAL
var state: State = State.IDLE
var in_water: bool = false
var target_form: Form = Form.NORMAL
var is_bouncing_from_enemy := false

var mode: GameMode = GameMode.PLATAFORMA

var unlocked_forms = {
	Form.NORMAL: true,
	Form.BUBBLE: false,
	Form.SUPER: false
}

var bubble_jump_count := 0
var max_bubble_jumps := 40

var is_invincible: bool = false

# ==============================
# ====== READY =================
# ==============================
func _ready() -> void:
	if $Sprite2D:
		$Sprite2D.attack_finished.connect(_on_attack_finished)

	if attack_collision:
		attack_collision.disabled = true

	if has_node("Hurtbox"):
		var hurtbox = $Hurtbox
		if not hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
			hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	update_audio_by_form()

# ==============================
# ====== MODO DE JOGO ==========
# ==============================
func enable_metroidvania_mode() -> void:
	mode = GameMode.METROIDVANIA
	print("🔥 Modo Metroidvania ativado!")
	# opcional: restaurar HP quando entra no metroidvania
	if stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()

func enable_plataforma_mode() -> void:
	mode = GameMode.PLATAFORMA
	print("🎮 Modo Plataforma ativado!")
	# no modo plataforma, HP não é usado na HUD, mas podemos garantir cheio
	if stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()

func can_transform() -> bool:
	if mode != GameMode.METROIDVANIA:
		return false
	return unlocked_forms.get(Form.BUBBLE, false) or unlocked_forms.get(Form.SUPER, false)

func can_dash_global() -> bool:
	# Dash apenas no modo metroidvania
	return mode == GameMode.METROIDVANIA

# ==============================
# ====== PHYSICS PROCESS =======
# ==============================
func _physics_process(delta: float) -> void:
	if is_bouncing_from_enemy:
		is_bouncing_from_enemy = false

	on_ground = is_on_floor()
	if on_ground:
		bubble_jump_count = 0

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if in_water:
		apply_water_physics(delta)
	else:
		apply_normal_gravity(delta)

	handle_input()
	handle_state(delta)
	move_and_slide()

# ==============================
# ====== INPUT =================
# ==============================
func handle_input() -> void:
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_up"):
		handle_jump()

	# Transformações só em metroidvania
	if mode == GameMode.METROIDVANIA:
		if Input.is_action_just_pressed("forma1"):
			toggle_transform(Form.BUBBLE)
		elif Input.is_action_just_pressed("forma2"):
			toggle_transform(Form.SUPER)
		elif Input.is_action_just_pressed("normal"):
			toggle_transform(Form.NORMAL)

# ==============================
# ====== MOVIMENTO =============
# ==============================
func apply_normal_gravity(delta: float) -> void:
	if state == State.DASH:
		if dash_stops_fall:
			return
		velocity.y += gravity * dash_fall_factor * delta
		return
	
	if form == Form.BUBBLE:
		velocity.y += 50 * delta
	else:
		velocity.y += gravity * delta

func apply_water_physics(delta: float) -> void:
	var water_grav := water_gravity_normal
	match form:
		Form.BUBBLE:
			water_grav = water_gravity_bubble
		Form.SUPER:
			water_grav = water_gravity_super
	
	velocity.y += water_grav * delta
	velocity.y -= water_buoyancy * delta
	velocity.y *= water_drag
	velocity.x *= water_drag

func handle_jump() -> void:
	match form:
		Form.BUBBLE:
			if in_water:
				velocity.y = -100
				bubble_jump_count += 1
			elif bubble_jump_count < max_bubble_jumps:
				velocity.y = -50
				bubble_jump_count += 1
		Form.SUPER:
			if in_water:
				velocity.y = -120
			elif is_on_floor():
				velocity.y = super_jump_force
		_:
			if in_water:
				velocity.y = -150
			elif is_on_floor():
				velocity.y = jump_force

# ==============================
# ====== TRANSFORMAÇÃO =========
# ==============================
func toggle_transform(target: Form) -> void:
	if state == State.TRANSFORM:
		return

	if not can_transform():
		return

	if form == target:
		start_transform(Form.NORMAL)
	elif unlocked_forms.get(target, false):
		start_transform(target)

func start_transform(new_form: Form) -> void:
	state = State.TRANSFORM
	target_form = new_form

# ==============================
# ====== DASH ==================
# ==============================
func can_dash() -> bool:
	if not can_dash_global():
		return false
	return dash_cooldown_timer <= 0

# ==============================
# ====== STATE MACHINE =========
# ==============================
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
	# Ataque NO BOTÃO só no modo metroidvania
	elif mode == GameMode.METROIDVANIA and Input.is_action_just_pressed("attack"):
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
	elif mode == GameMode.METROIDVANIA and Input.is_action_just_pressed("attack"):
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
		dash_cooldown_timer = dash_cooldown
		var dir: int = int(sign(Input.get_axis("ui_left", "ui_right")))
		if dir == 0:
			dir = -1 if $Sprite2D.flip_h else 1
		velocity.x = dir * dash_speed

	dash_timer -= get_physics_process_delta_time()
	if dash_timer <= 0:
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
	var swim_speed := speed * 0.5
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

# ==============================
# ====== DANO / VIDAS ==========
# ==============================
func take_damage(amount: int = 1) -> void:
	if is_invincible or state == State.DEAD:
		return
	
	if mode == GameMode.PLATAFORMA:
		# Sem HP visível, cada hit = 1 vida
		_on_fatal_hit()
		return
	
	# METROIDVANIA → usa barra de HP
	if stats and stats.has_method("take_damage"):
		stats.take_damage(amount)
		if stats.current_health <= 0:
			_on_fatal_hit()
	else:
		_on_fatal_hit()
	
	if state != State.DEAD:
		start_invincibility()

func start_invincibility() -> void:
	is_invincible = true
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(invincibility_time)
	if timer == null:
		return
	await timer.timeout
	is_invincible = false

func _on_fatal_hit() -> void:
	# 🔹 No METROIDVANIA → "uma vida só": morreu = vai pra Continue
	if mode == GameMode.METROIDVANIA:
		die()
		return

	# 🔹 No PLATAFORMA → usa sistema de 3 vidas + respawn
	GameManager.lose_life()
	
	if GameManager.get_lives() <= 0:
		die()
	else:
		await respawn_player()

func respawn_player() -> void:
	global_position = respawn_position
	velocity = Vector2.ZERO
	change_state(State.IDLE)
	
	# no metroidvania respawn restauraria HP,
	# mas atualmente ele só é chamado no modo plataforma
	if mode == GameMode.METROIDVANIA and stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()
	
	is_invincible = true
	var tree := get_tree()
	if tree:
		var timer := tree.create_timer(invincibility_time)
		if timer:
			await timer.timeout
	is_invincible = false

# ==============================
# ====== ATAQUE ================
# ==============================
func activate_attack_area() -> void:
	if attack_collision:
		attack_collision.disabled = false

func deactivate_attack_area() -> void:
	if attack_collision:
		attack_collision.disabled = true

func _on_attack_finished() -> void:
	deactivate_attack_area()
	change_state(State.IDLE)

# ==============================
# ====== ÁUDIO =================
# ==============================
func update_audio_by_form() -> void:
	if not audio_normal or not audio_super:
		return
	
	match form:
		Form.NORMAL, Form.BUBBLE:
			if audio_super.playing:
				audio_super.stop()
			if not audio_normal.playing:
				audio_normal.play()
		
		Form.SUPER:
			if audio_normal.playing:
				audio_normal.stop()
			if not audio_super.playing:
				audio_super.play()

# ==============================
# ====== MORTE =================
# ==============================
func die() -> void:
	state = State.DEAD
	if animation_player:
		animation_player.play("Dead")
	velocity = Vector2.ZERO
	
	if audio_normal:
		audio_normal.stop()
	if audio_super:
		audio_super.stop()

	var tree := get_tree()
	if tree == null:
		return

	# Nos dois modos, morte "definitiva" leva para a tela de Continue
	var timer := tree.create_timer(death_delay)
	if timer == null:
		return
	await timer.timeout

	if not is_inside_tree():
		return

	GameManager.goto_continue()

# ==============================
# ====== BOUNCE NO INIMIGO =====
# ==============================
func bounce_from_enemy() -> void:
	is_bouncing_from_enemy = true
	velocity.y = -260

func _on_hurtbox_body_entered(body: Area2D) -> void:
	if is_invincible:
		return

	if body.has_method("deal_damage_to_player"):
		body.deal_damage_to_player(self)
		return

	if body.is_in_group("enemy"):
		take_damage(1)
		return

	if body.is_in_group("boss"):
		take_damage(1)
		return
