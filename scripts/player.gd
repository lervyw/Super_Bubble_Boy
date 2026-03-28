# Player.gd
extends CharacterBody2D
# =========================================================
#  PLAYER CONTROLLER
#  - Máquina de estados (idle/walk/jump/attack/dash/etc)
#  - Formas (normal/bubble/super)
#  - Dois modos de jogo (Plataforma vs Metroidvania)
#  - Dano, invencibilidade, respawn e morte
#  - Combos, ataque especial, defesa
#  - Stomp com bounce configurável por forma
# =========================================================


# ==========================
# ====== ENUMS / EXPORTS ===
# ==========================
enum State {
	IDLE, WALK, JUMP, ATTACK, CROUCH, DASH, TRANSFORM, DEAD, SWIM, SPECIAL_ATTACK, DEFEND
}

enum Form { NORMAL, BUBBLE, SUPER }

enum GameMode { PLATAFORMA, METROIDVANIA }

# ACOES DO HUD MENU
# =============================
enum HudMenuAction {
	NONE,
	SPECIAL_ATTACK,
	DEFEND
}

var hud_menu_open := false
var hud_menu_selection: HudMenuAction = HudMenuAction.NONE
var hud_menu_axis_locked := false


# Parâmetros principais de movimento e referências de nodes
@export var speed := 150.0
@export var jump_force := -450.0
@export var super_jump_force := -350.0
@export var gravity := 900.0
@export var dash_speed := 400.0
@export var dash_time := 0.2
@export var animation_player: AnimationPlayer
@export var audio_normal: AudioStreamPlayer
@export var audio_super: AudioStreamPlayer
@export var hud: CanvasLayer

# Ajustes de morte
@export_group("Death Settings")
@export_range(0.0, 5.0) var death_delay: float = 1.0

# Ajustes do dash
@export_group("Dash Settings")
@export var dash_stops_fall: bool = false
@export_range(0.0, 1.0) var dash_fall_factor: float = 0.3
@export_range(0.0, 2.0) var dash_cooldown: float = 0.3

# Ajustes de dano
@export_group("Damage Settings")
@export_range(0.0, 5.0) var invincibility_time: float = 1.0

# Ajustes do stomp
@export_group("Stomp Settings")
@export var stomp_requires_falling: bool = true
@export var stomp_kills_enemy: bool = true
@export_range(0.0, 2000.0) var stomp_bounce_force_normal: float = 260.0
@export_range(0.0, 2000.0) var stomp_bounce_force_bubble: float = 180.0
@export_range(0.0, 2000.0) var stomp_bounce_force_super: float = 320.0

# Seleção manual dos stompers no Inspector
@export var stomper_normal: Area2D
@export var stomper_bubble: Area2D
@export var stomper_super: Area2D

# Spawn/checkpoint + stats (HP, etc)
@export var respawn_position: Vector2 = Vector2(288, 207)
@export var stats: Node = null


# ==========================
# ====== NODES ONREADY =====
# ==========================
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D


# ==========================
# ====== STATE VARS ========
# ==========================
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var on_ground := false

var form: Form = Form.NORMAL
var state: State = State.IDLE

var in_water: bool = false
var target_form: Form = Form.NORMAL
var is_bouncing_from_enemy := false

var combo_lock := false
var defending := false

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
# ========= READY ==============
# ==============================
func _ready() -> void:
	if $Sprite2D and $Sprite2D.has_signal("attack_finished"):
		if not has_method("_on_attack_finished"):
			push_error("Player: método _on_attack_finished não encontrado!")
		else:
			$Sprite2D.attack_finished.connect(_on_attack_finished)

	if attack_collision:
		attack_collision.disabled = true

	if has_node("Hurtbox"):
		var hurtbox = $Hurtbox
		if hurtbox and not hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
			hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	connect_stomper_signals(stomper_normal)
	connect_stomper_signals(stomper_bubble)
	connect_stomper_signals(stomper_super)
	refresh_stompers_for_current_form()

	update_audio_by_form()


# ==============================
# ===== INPUT GLOBAL (HUD etc)
# ==============================
func _input(event):
	if event.is_action_pressed("hud_menu"):
		open_hud_menu()
		return

	if event.is_action_released("hud_menu"):
		close_hud_menu()
		return

	# Enquanto o menu está aberto, bloqueia inputs normais
	if hud_menu_open:
		return

	if event.is_action_pressed("attack_special"):
		start_special_attack()

	if event.is_action_pressed("defend"):
		start_defense()


# ==============================
# ===== PROCESS (não-física)
# ==============================
func _process(_delta: float) -> void:
	if hud_menu_open:
		process_hud_menu_selection()
		return

	check_attack_combos()
	check_quick_form_selection()


# ==============================
# ===== AÇÕES: ESPECIAL/DEFESA
# ==============================
func start_special_attack() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM]:
		return

	defending = false
	change_state(State.SPECIAL_ATTACK)
	activate_attack_area()

func start_defense() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM]:
		return

	defending = true
	change_state(State.DEFEND)
	activate_attack_area()

func stop_defense() -> void:
	defending = false
	deactivate_attack_area()

	if state == State.DEFEND:
		change_state(State.IDLE)


# ==============================
# ===== COMBOS
# ==============================
func check_attack_combos() -> void:
	if hud_menu_open or combo_lock or state == State.DEAD:
		return

	if Input.is_action_pressed("attack") and Input.is_action_pressed("attack_special"):
		execute_combo(1)
	elif Input.is_action_pressed("attack") and Input.is_action_pressed("defend"):
		execute_combo(2)
	elif Input.is_action_pressed("attack_special") and Input.is_action_pressed("defend"):
		execute_combo(3)
	elif Input.is_action_pressed("attack") and Input.is_action_pressed("jump"):
		execute_combo(4)

func execute_combo(id: int) -> void:
	combo_lock = true
	state = State.ATTACK
	activate_attack_area()
	print("Combo executado:", id)

	await get_tree().create_timer(0.25).timeout
	combo_lock = false


# ==============================
# ===== SELEÇÃO RÁPIDA DE FORMA
# ==============================
func check_quick_form_selection() -> void:
	if hud_menu_open:
		return

	if not Input.is_action_pressed("form_select"):
		return
	if state == State.TRANSFORM or not can_transform():
		return

	if Input.is_action_pressed("right_stick_up"):
		start_transform(Form.BUBBLE)
	elif Input.is_action_pressed("right_stick_right"):
		start_transform(Form.SUPER)
	elif Input.is_action_pressed("right_stick_down"):
		start_transform(Form.NORMAL)


# ==============================
# ===== ESTADOS “TRAVADOS”
# ==============================
func special_attack_state() -> void:
	velocity = Vector2.ZERO

func defend_state() -> void:
	velocity = Vector2.ZERO


# ==============================
# ===== MODO DE JOGO
# ==============================
func enable_metroidvania_mode() -> void:
	mode = GameMode.METROIDVANIA
	print("🔥 Modo Metroidvania ativado!")
	if stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()

func enable_plataforma_mode() -> void:
	mode = GameMode.PLATAFORMA
	print("🎮 Modo Plataforma ativado!")
	if stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()

func can_transform() -> bool:
	if mode != GameMode.METROIDVANIA:
		return false
	return unlocked_forms.get(Form.BUBBLE, false) or unlocked_forms.get(Form.SUPER, false)

func can_dash_global() -> bool:
	return mode == GameMode.METROIDVANIA


# ==============================
# ===== FÍSICA PRINCIPAL
# ==============================
func _physics_process(delta: float) -> void:
	refresh_stompers_for_current_form()

	if is_bouncing_from_enemy:
		is_bouncing_from_enemy = false

	on_ground = is_on_floor()
	if on_ground:
		bubble_jump_count = 0

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Enquanto o menu estiver aberto, congela o player
	if hud_menu_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if in_water:
		apply_water_physics(delta)
	else:
		apply_normal_gravity(delta)

	handle_input()
	handle_state(delta)

	move_and_slide()


# ==============================
# ===== INPUT (pulo + formas)
# ==============================
func handle_input() -> void:
	if hud_menu_open:
		return

	if Input.is_action_just_pressed("jump"):
		handle_jump()

	if mode == GameMode.METROIDVANIA:
		if Input.is_action_just_pressed("forma1"):
			toggle_transform(Form.BUBBLE)
		elif Input.is_action_just_pressed("forma2"):
			toggle_transform(Form.SUPER)
		elif Input.is_action_just_pressed("normal"):
			toggle_transform(Form.NORMAL)


# ==============================
# ===== GRAVIDADE / ÁGUA / DASH
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
	var water_grav := 150.0
	match form:
		Form.BUBBLE:
			water_grav = 50.0
		Form.SUPER:
			water_grav = 250.0

	velocity.y += water_grav * delta
	velocity.y -= 80.0 * delta
	velocity.y *= 0.92
	velocity.x *= 0.92


# ==============================
# ===== PULO (por forma)
# ==============================
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
# ===== TRANSFORMAÇÃO
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
	if state == State.DEAD:
		return

	if form == new_form:
		return

	target_form = new_form
	change_state(State.TRANSFORM)
	velocity = Vector2.ZERO
	deactivate_attack_area()
	defending = false


# ==============================
# ===== DASH
# ==============================
func can_dash() -> bool:
	if not can_dash_global():
		return false
	return dash_cooldown_timer <= 0


# ==============================
# ===== MÁQUINA DE ESTADOS
# ==============================
func handle_state(_delta: float) -> void:
	match state:
		State.IDLE: idle_state()
		State.WALK: walk_state()
		State.JUMP: jump_state()
		State.ATTACK: attack_state()
		State.SPECIAL_ATTACK: special_attack_state()
		State.DEFEND: defend_state()
		State.CROUCH: crouch_state()
		State.DASH: dash_state()
		State.TRANSFORM: transform_state()
		State.DEAD: dead_state()
		State.SWIM: swim_state()


# ==============================
# ===== ESTADOS BÁSICOS
# ==============================
func idle_state() -> void:
	handle_horizontal_input()

	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif abs(Input.get_axis("ui_left", "ui_right")) > 0:
		change_state(State.WALK)
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


# ==============================
# ===== DASH STATE
# ==============================
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


# ==============================
# ===== NADO
# ==============================
func swim_state() -> void:
	var dir_x := Input.get_axis("ui_left", "ui_right")
	var dir_y := Input.get_axis("ui_up", "ui_down")

	var swim_speed := speed * 0.5
	match form:
		Form.NORMAL:
			swim_speed *= 0.6
		Form.BUBBLE:
			swim_speed *= 0.9
		Form.SUPER:
			swim_speed *= 0.5

	velocity.x = dir_x * swim_speed
	velocity.y += dir_y * swim_speed * 0.6

	if not in_water:
		change_state(State.IDLE)


# ==============================
# ===== MOVIMENTO HORIZONTAL
# ==============================
func handle_horizontal_input() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")

	var current_speed := speed
	if in_water:
		match form:
			Form.NORMAL:
				current_speed *= 0.6
			Form.BUBBLE:
				current_speed *= 0.9
			Form.SUPER:
				current_speed *= 0.5

	velocity.x = dir * current_speed

	if dir != 0:
		$Sprite2D.flip_h = dir < 0

func change_state(new_state: State) -> void:
	state = new_state


# ==============================
# ===== DANO / VIDAS / HP
# ==============================
func take_damage(amount: int = 1) -> void:
	if is_invincible or state == State.DEAD:
		return

	if defending and state == State.DEFEND:
		return

	if mode == GameMode.PLATAFORMA:
		_on_fatal_hit()
		return

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
		is_invincible = false
		return

	var timer := tree.create_timer(invincibility_time)
	if timer == null:
		is_invincible = false
		return

	await timer.timeout
	is_invincible = false

func _on_fatal_hit() -> void:
	if mode == GameMode.METROIDVANIA:
		die()
		return

	GameManager.lose_life()
	if GameManager.get_lives() <= 0:
		die()
	else:
		await respawn_player()

func respawn_player() -> void:
	global_position = respawn_position
	velocity = Vector2.ZERO
	change_state(State.IDLE)

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
# ===== HUD MENU
# ==============================
func open_hud_menu() -> void:
	if state in [State.DEAD, State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.TRANSFORM]:
		return

	hud_menu_open = true
	hud_menu_selection = HudMenuAction.NONE
	hud_menu_axis_locked = false
	velocity = Vector2.ZERO

	if hud and hud.has_method("show_menu"):
		hud.show_menu()

	if hud and hud.has_method("update_action_selection"):
		hud.update_action_selection("none")

func close_hud_menu() -> void:
	if not hud_menu_open:
		return

	hud_menu_open = false
	hud_menu_selection = HudMenuAction.NONE
	hud_menu_axis_locked = false

	if hud and hud.has_method("hide_menu"):
		hud.hide_menu()

func process_hud_menu_selection() -> void:
	var horizontal := get_hud_menu_horizontal_axis()

	# trava enquanto o eixo continua pressionado
	if abs(horizontal) < 0.35:
		hud_menu_axis_locked = false
		return

	if hud_menu_axis_locked:
		return

	hud_menu_axis_locked = true

	if horizontal > 0.0:
		select_hud_menu_action(HudMenuAction.SPECIAL_ATTACK)
	elif horizontal < 0.0:
		select_hud_menu_action(HudMenuAction.DEFEND)

func get_hud_menu_horizontal_axis() -> float:
	var raw_axis := Input.get_axis("ui_left", "ui_right")
	if raw_axis == 0.0:
		return 0.0

	var facing_right := true
	if has_node("Sprite2D"):
		facing_right = not $Sprite2D.flip_h

	# Frente = positivo, Trás = negativo
	if facing_right:
		return raw_axis

	return -raw_axis

func select_hud_menu_action(action: HudMenuAction) -> void:
	if hud_menu_selection == action:
		return

	hud_menu_selection = action

	match action:
		HudMenuAction.SPECIAL_ATTACK:
			if hud and hud.has_method("update_action_selection"):
				hud.update_action_selection("attack_special")
			execute_hud_menu_action("attack_special")

		HudMenuAction.DEFEND:
			if hud and hud.has_method("update_action_selection"):
				hud.update_action_selection("defend")
			execute_hud_menu_action("defend")

func execute_hud_menu_action(action_name: String) -> void:
	close_hud_menu()

	match action_name:
		"attack_special":
			start_special_attack()
		"defend":
			start_defense()


# ==============================
# ===== ATAQUE (HITBOX)
# ==============================
func activate_attack_area() -> void:
	if attack_collision:
		attack_collision.disabled = false

func deactivate_attack_area() -> void:
	if attack_collision:
		attack_collision.disabled = true

func _on_attack_finished() -> void:
	deactivate_attack_area()
	defending = false

	if state != State.DEAD:
		change_state(State.IDLE)


# ==============================
# ===== ÁUDIO POR FORMA
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
# ===== MORTE / CONTINUE
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
		GameManager.call_deferred("goto_continue")
		return

	var timer := tree.create_timer(death_delay)
	if timer == null:
		GameManager.call_deferred("goto_continue")
		return

	await timer.timeout

	if not is_inside_tree():
		return

	GameManager.goto_continue()


# ==============================
# ===== STOMP / BOUNCE
# ==============================
func connect_stomper_signals(stomper: Area2D) -> void:
	if not stomper:
		return

	if not stomper.body_entered.is_connected(_on_stomper_body_entered):
		stomper.body_entered.connect(_on_stomper_body_entered)

	if not stomper.area_entered.is_connected(_on_stomper_area_entered):
		stomper.area_entered.connect(_on_stomper_area_entered)

func refresh_stompers_for_current_form() -> void:
	set_stomper_enabled(stomper_normal, form == Form.NORMAL)
	set_stomper_enabled(stomper_bubble, form == Form.BUBBLE)
	set_stomper_enabled(stomper_super, form == Form.SUPER)

func set_stomper_enabled(stomper: Area2D, enabled: bool) -> void:
	if not stomper:
		return

	stomper.monitoring = enabled
	stomper.monitorable = enabled

	for child in stomper.get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled

func get_stomp_bounce_force() -> float:
	match form:
		Form.BUBBLE:
			return stomp_bounce_force_bubble
		Form.SUPER:
			return stomp_bounce_force_super
		_:
			return stomp_bounce_force_normal

func bounce_from_enemy(force: float = -1.0) -> void:
	is_bouncing_from_enemy = true

	var applied_force := force
	if applied_force < 0.0:
		applied_force = get_stomp_bounce_force()

	velocity.y = -abs(applied_force)

	if state != State.DEAD and state != State.TRANSFORM:
		change_state(State.JUMP)

func _on_stomper_body_entered(body: Node2D) -> void:
	try_stomp(body)

func _on_stomper_area_entered(area: Area2D) -> void:
	try_stomp(area)

func try_stomp(target: Node) -> void:
	if target == null:
		return

	if state == State.DEAD or state == State.TRANSFORM:
		return

	if stomp_requires_falling and velocity.y <= 0.0:
		return

	var stomp_target := resolve_stomp_target(target)
	if stomp_target == null:
		return

	bounce_from_enemy()

	if stomp_target.has_method("on_stomped"):
		stomp_target.on_stomped(self)
		return

	if stomp_kills_enemy:
		if stomp_target.has_method("die"):
			stomp_target.die()
			return

		if stomp_target.has_method("take_damage"):
			stomp_target.take_damage(999)
			return

func resolve_stomp_target(node: Node) -> Node:
	var current: Node = node

	while current != null:
		if current.is_in_group("enemy") \
		or current.is_in_group("stompable") \
		or current.is_in_group("boss") \
		or current.is_in_group("slime"):
			return current
		current = current.get_parent()

	return null


# ==============================
# ===== HURTBOX
# ==============================
func _on_hurtbox_body_entered(body: Node) -> void:
	if is_invincible:
		return

	if body.has_method("deal_damage_to_player"):
		body.deal_damage_to_player(self)
		return

	if body.is_in_group("slime"):
		bounce_from_enemy()
		take_damage(1)
		return

	if body.is_in_group("boss"):
		bounce_from_enemy()
		take_damage(1)
		return

	if body.is_in_group("enemy"):
		take_damage(1)
		return
