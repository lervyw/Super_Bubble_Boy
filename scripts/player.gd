# Player.gd
extends CharacterBody2D
# =========================================================
#  PLAYER CONTROLLER
#  - Máquina de estados (idle/walk/jump/attack/dash/etc)
#  - Dois modos de jogo (Plataforma vs Metroidvania)
#  - Três formas (normal/bubble/super)
#  - Ataques normais, passivos, super ativos e ultimate
#  - Mana, cooldowns, respawn, dano e invencibilidade
# =========================================================

enum State {
	IDLE, WALK, JUMP, ATTACK, CROUCH, DASH, TRANSFORM, DEAD, SWIM, SPECIAL_ATTACK, DEFEND
}

enum Form { NORMAL, BUBBLE, SUPER }
enum GameMode { PLATAFORMA, METROIDVANIA }
enum HudMenuAction { NONE, SPECIAL_ATTACK, DEFEND }
enum AttackKind { NONE, NORMAL, PASSIVE, ACTIVE_SUPER, ULTIMATE, DEFEND }

const ATTACK_META_DAMAGE := &"attack_damage"
const ATTACK_META_KIND := &"attack_kind"
const ATTACK_META_ID := &"attack_id"

var hud_menu_open := false
var hud_menu_selection: HudMenuAction = HudMenuAction.NONE
var hud_menu_axis_locked := false

@export_group("Movement")
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

@export_group("Modes")
@export var platform_mode_uses_mana: bool = false
@export var platform_mode_allows_mana_attacks: bool = false
@export var force_normal_form_in_platform_mode: bool = true

@export_group("Death Settings")
@export_range(0.0, 5.0) var death_delay: float = 1.0

@export_group("Dash Settings")
@export var dash_stops_fall: bool = false
@export_range(0.0, 1.0) var dash_fall_factor: float = 0.3
@export_range(0.0, 2.0) var dash_cooldown: float = 0.3

@export_group("Damage Settings")
@export_range(0.0, 5.0) var invincibility_time: float = 1.0

@export_group("Stomp Settings")
@export var stomp_requires_falling: bool = true
@export var stomp_kills_enemy: bool = true
@export_range(0.0, 2000.0) var stomp_bounce_force_normal: float = 260.0
@export_range(0.0, 2000.0) var stomp_bounce_force_bubble: float = 180.0
@export_range(0.0, 2000.0) var stomp_bounce_force_super: float = 320.0
@export var stomper_normal: Area2D
@export var stomper_bubble: Area2D
@export var stomper_super: Area2D

@export_group("Normal Attack")
@export var normal_attack_damage: int = 2
@export var normal_attack_id: StringName = &"normal_attack"

@export_group("Passive Attack Foundation")
@export var passive_attack_enabled: bool = false
@export var passive_attack_id: StringName = &"passive_pulse"
@export_range(0.1, 30.0, 0.1) var passive_attack_interval: float = 3.0
@export_range(0.05, 3.0, 0.05) var passive_attack_active_time: float = 0.15
@export var passive_attack_damage: int = 1
@export var passive_attack_requires_target: bool = false
@export var passive_attack_area_path: NodePath = NodePath("AttackArea")

@export_group("Active Super Attacks")
@export var active_attack_names: Array[StringName] = [&"super_attack_1"]
@export var active_attack_cooldowns: Array[float] = [1.5]
@export var active_attack_mana_costs: Array[float] = [20.0]
@export var active_attack_damages: Array[int] = [4]
@export var active_attack_area_paths: Array[NodePath] = [NodePath("AttackArea")]
@export var selected_active_attack_index: int = 0

@export_group("Ultimate Attack")
@export var ultimate_attack_enabled: bool = true
@export var ultimate_attack_id: StringName = &"ultimate_attack"
@export_range(0.1, 30.0, 0.1) var ultimate_attack_cooldown: float = 8.0
@export var ultimate_attack_damage: int = 10
@export var ultimate_attack_area_path: NodePath = NodePath("AttackArea")
@export var allow_ultimate_input: bool = true

@export_group("Respawn")
@export var respawn_position: Vector2 = Vector2(288, 207)
@export var stats: Node = null

@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var passive_attack_timer := 0.0
var on_ground := false

var form: Form = Form.NORMAL
var state: State = State.IDLE
var mode: GameMode = GameMode.PLATAFORMA

var in_water: bool = false
var target_form: Form = Form.NORMAL
var is_bouncing_from_enemy := false
var combo_lock := false
var defending := false
var bubble_jump_count := 0
var max_bubble_jumps := 40
var is_invincible: bool = false

var active_attack_timers: Array[float] = []
var ultimate_cooldown_timer: float = 0.0
var current_attack_kind: AttackKind = AttackKind.NONE
var current_attack_id: StringName = &""
var current_attack_damage: int = 0
var current_attack_area: Area2D

var unlocked_forms = {
	Form.NORMAL: true,
	Form.BUBBLE: false,
	Form.SUPER: false
}


func _ready() -> void:
	normalize_attack_configuration()

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
	passive_attack_timer = passive_attack_interval


func _input(event):
	if event.is_action_pressed("hud_menu"):
		open_hud_menu()
		return

	if event.is_action_released("hud_menu"):
		close_hud_menu()
		return

	if hud_menu_open:
		return

	if event.is_action_pressed("attack_special"):
		start_special_attack()

	if event.is_action_pressed("defend"):
		start_defense()

	if allow_ultimate_input and InputMap.has_action("ultimate_attack") and event.is_action_pressed("ultimate_attack"):
		start_ultimate_attack()


func _process(_delta: float) -> void:
	if hud_menu_open:
		process_hud_menu_selection()
		return

	check_attack_combos()
	check_quick_form_selection()


func _physics_process(delta: float) -> void:
	refresh_stompers_for_current_form()
	update_attack_cooldowns(delta)
	process_passive_attack(delta)

	if is_bouncing_from_enemy:
		is_bouncing_from_enemy = false

	on_ground = is_on_floor()
	if on_ground:
		bubble_jump_count = 0

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

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


func normalize_attack_configuration() -> void:
	if active_attack_names.is_empty():
		active_attack_names = [&"super_attack_1"]
	if active_attack_cooldowns.is_empty():
		active_attack_cooldowns = [1.5]
	if active_attack_mana_costs.is_empty():
		active_attack_mana_costs = [20.0]
	if active_attack_damages.is_empty():
		active_attack_damages = [4]
	if active_attack_area_paths.is_empty():
		active_attack_area_paths = [NodePath("AttackArea")]

	while active_attack_cooldowns.size() < active_attack_names.size():
		active_attack_cooldowns.append(active_attack_cooldowns.back())
	while active_attack_mana_costs.size() < active_attack_names.size():
		active_attack_mana_costs.append(active_attack_mana_costs.back())
	while active_attack_damages.size() < active_attack_names.size():
		active_attack_damages.append(active_attack_damages.back())
	while active_attack_area_paths.size() < active_attack_names.size():
		active_attack_area_paths.append(active_attack_area_paths.back())

	active_attack_timers.resize(active_attack_names.size())
	for i in range(active_attack_timers.size()):
		active_attack_timers[i] = 0.0

	selected_active_attack_index = clampi(selected_active_attack_index, 0, active_attack_names.size() - 1)


func update_attack_cooldowns(delta: float) -> void:
	for i in range(active_attack_timers.size()):
		if active_attack_timers[i] > 0.0:
			active_attack_timers[i] = max(active_attack_timers[i] - delta, 0.0)

	if ultimate_cooldown_timer > 0.0:
		ultimate_cooldown_timer = max(ultimate_cooldown_timer - delta, 0.0)


func process_passive_attack(delta: float) -> void:
	if not passive_attack_enabled:
		return
	if state in [State.DEAD, State.TRANSFORM]:
		return
	if passive_attack_interval <= 0.0:
		return

	passive_attack_timer -= delta
	if passive_attack_timer > 0.0:
		return

	passive_attack_timer = passive_attack_interval

	var area := get_area_from_path(passive_attack_area_path)
	if passive_attack_requires_target and not attack_area_has_targets(area):
		return

	trigger_instant_attack_window(area, passive_attack_active_time, passive_attack_damage, AttackKind.PASSIVE, passive_attack_id)


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


func start_special_attack() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM]:
		return
	if not can_use_mana_attacks():
		return
	if not can_trigger_active_attack(selected_active_attack_index):
		return

	var attack_name := get_active_attack_name(selected_active_attack_index)
	var mana_cost := get_active_attack_mana_cost(selected_active_attack_index)
	if not consume_attack_mana(mana_cost):
		return

	defending = false
	prepare_attack_area(
		get_active_attack_area(selected_active_attack_index),
		get_active_attack_damage(selected_active_attack_index),
		AttackKind.ACTIVE_SUPER,
		attack_name
	)
	active_attack_timers[selected_active_attack_index] = get_active_attack_cooldown(selected_active_attack_index)
	change_state(State.SPECIAL_ATTACK)
	activate_attack_area()


func start_ultimate_attack() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM]:
		return
	if not ultimate_attack_enabled:
		return
	if not can_use_mana_attacks():
		return
	if ultimate_cooldown_timer > 0.0:
		return
	if not consume_ultimate_mana():
		return

	defending = false
	prepare_attack_area(
		get_area_from_path(ultimate_attack_area_path),
		ultimate_attack_damage,
		AttackKind.ULTIMATE,
		ultimate_attack_id
	)
	ultimate_cooldown_timer = ultimate_attack_cooldown
	change_state(State.SPECIAL_ATTACK)
	activate_attack_area()


func start_defense() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM]:
		return

	defending = true
	prepare_attack_area(attack_area, 0, AttackKind.DEFEND, &"defend")
	change_state(State.DEFEND)
	activate_attack_area()


func stop_defense() -> void:
	defending = false
	deactivate_attack_area()

	if state == State.DEFEND:
		change_state(State.IDLE)


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
	prepare_attack_area(attack_area, normal_attack_damage, AttackKind.NORMAL, StringName("combo_%s" % id))
	state = State.ATTACK
	activate_attack_area()
	print("Combo executado:", id)

	await get_tree().create_timer(0.25).timeout
	combo_lock = false


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


func special_attack_state() -> void:
	velocity = Vector2.ZERO


func defend_state() -> void:
	velocity = Vector2.ZERO


func enable_metroidvania_mode() -> void:
	mode = GameMode.METROIDVANIA
	print("🔥 Modo Metroidvania ativado!")
	restore_resources_full()


func enable_plataforma_mode() -> void:
	mode = GameMode.PLATAFORMA
	print("🎮 Modo Plataforma ativado!")
	restore_resources_full()

	if force_normal_form_in_platform_mode:
		force_form(Form.NORMAL)


func can_transform() -> bool:
	if mode != GameMode.METROIDVANIA:
		return false
	return unlocked_forms.get(Form.BUBBLE, false) or unlocked_forms.get(Form.SUPER, false)


func can_dash_global() -> bool:
	return mode == GameMode.METROIDVANIA


func can_use_mana_system() -> bool:
	if mode == GameMode.METROIDVANIA:
		return true
	return platform_mode_uses_mana


func can_use_mana_attacks() -> bool:
	if mode == GameMode.METROIDVANIA:
		return true
	return platform_mode_allows_mana_attacks


func restore_resources_full() -> void:
	if stats == null:
		return
	if stats.has_method("restore_all"):
		stats.restore_all()
		return

	if stats.has_method("restore_full_health"):
		stats.restore_full_health()
	if stats.has_method("restore_full_mana"):
		stats.restore_full_mana()


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


func toggle_transform(target: Form) -> void:
	if state == State.TRANSFORM:
		return
	if not can_transform():
		return
	if target != Form.NORMAL and not unlocked_forms.get(target, false):
		return

	if form == target:
		start_transform(Form.NORMAL)
	else:
		start_transform(target)


func start_transform(new_form: Form) -> void:
	if state == State.DEAD:
		return
	if mode != GameMode.METROIDVANIA:
		return
	if new_form != Form.NORMAL and not unlocked_forms.get(new_form, false):
		return
	if form == new_form:
		return

	target_form = new_form
	change_state(State.TRANSFORM)
	velocity = Vector2.ZERO
	deactivate_attack_area()
	defending = false


func force_form(new_form: Form) -> void:
	if new_form != Form.NORMAL and not unlocked_forms.get(new_form, false):
		return

	form = new_form
	target_form = new_form
	if state == State.TRANSFORM:
		change_state(State.IDLE)
	refresh_stompers_for_current_form()
	update_audio_by_form()


func can_dash() -> bool:
	if not can_dash_global():
		return false
	return dash_cooldown_timer <= 0


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


func idle_state() -> void:
	handle_horizontal_input()

	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif abs(Input.get_axis("ui_left", "ui_right")) > 0:
		change_state(State.WALK)
	elif Input.is_action_just_pressed("attack"):
		start_normal_attack()
	elif Input.is_action_pressed("crouch"):
		change_state(State.CROUCH)
	elif Input.is_action_just_pressed("dash") and can_dash():
		change_state(State.DASH)


func walk_state() -> void:
	handle_horizontal_input()

	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif Input.is_action_just_pressed("attack"):
		start_normal_attack()
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
			swim_speed *= 0.6
		Form.BUBBLE:
			swim_speed *= 0.9
		Form.SUPER:
			swim_speed *= 0.5

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


func start_normal_attack() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM]:
		return

	defending = false
	prepare_attack_area(attack_area, normal_attack_damage, AttackKind.NORMAL, normal_attack_id)
	change_state(State.ATTACK)
	activate_attack_area()


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

	if stats and stats.has_method("restore_all"):
		stats.restore_all()
	else:
		if mode == GameMode.METROIDVANIA and stats and stats.has_method("reset_health_full"):
			stats.reset_health_full()
		if stats and stats.has_method("reset_mana_full"):
			stats.reset_mana_full()

	is_invincible = true
	var tree := get_tree()
	if tree:
		var timer := tree.create_timer(invincibility_time)
		if timer:
			await timer.timeout
	is_invincible = false


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

	if abs(horizontal) < 0.35:
		hud_menu_axis_locked = false
		return

	if hud_menu_axis_locked:
		return

	hud_menu_axis_locked = true

	if horizontal > 0.0 and can_use_mana_attacks():
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


func activate_attack_area() -> void:
	set_area_collision_enabled(current_attack_area if current_attack_area != null else attack_area, true)


func deactivate_attack_area() -> void:
	set_area_collision_enabled(current_attack_area if current_attack_area != null else attack_area, false)
	clear_attack_area_metadata(current_attack_area if current_attack_area != null else attack_area)
	current_attack_kind = AttackKind.NONE
	current_attack_id = &""
	current_attack_damage = 0
	current_attack_area = null


func _on_attack_finished() -> void:
	deactivate_attack_area()
	defending = false

	if state != State.DEAD:
		change_state(State.IDLE)


func prepare_attack_area(area: Area2D, damage: int, kind: AttackKind, attack_id: StringName) -> void:
	var target_area := area if area != null else attack_area
	if target_area == null:
		return

	current_attack_kind = kind
	current_attack_id = attack_id
	current_attack_damage = damage
	current_attack_area = target_area

	target_area.set_meta(ATTACK_META_DAMAGE, damage)
	target_area.set_meta(ATTACK_META_KIND, int(kind))
	target_area.set_meta(ATTACK_META_ID, String(attack_id))


func clear_attack_area_metadata(area: Area2D) -> void:
	if area == null:
		return

	if area.has_meta(ATTACK_META_DAMAGE):
		area.remove_meta(ATTACK_META_DAMAGE)
	if area.has_meta(ATTACK_META_KIND):
		area.remove_meta(ATTACK_META_KIND)
	if area.has_meta(ATTACK_META_ID):
		area.remove_meta(ATTACK_META_ID)


func trigger_instant_attack_window(area: Area2D, duration: float, damage: int, kind: AttackKind, attack_id: StringName) -> void:
	if area == null:
		return

	prepare_attack_area(area, damage, kind, attack_id)
	set_area_collision_enabled(area, true)
	_close_instant_attack_window(area, max(duration, 0.05), attack_id)


func _close_instant_attack_window(area: Area2D, duration: float, attack_id: StringName) -> void:
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(area):
		return
	if current_attack_id == attack_id:
		clear_attack_area_metadata(area)
	set_area_collision_enabled(area, false)


func set_area_collision_enabled(area: Area2D, enabled: bool) -> void:
	if area == null:
		return

	area.monitoring = enabled
	area.monitorable = enabled

	for child in area.get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled


func attack_area_has_targets(area: Area2D) -> bool:
	if area == null:
		return false

	for overlapping_area in area.get_overlapping_areas():
		var target := overlapping_area.get_parent()
		if is_valid_attack_target(target):
			return true

	for body in area.get_overlapping_bodies():
		if is_valid_attack_target(body):
			return true

	return false


func is_valid_attack_target(target: Node) -> bool:
	if target == null:
		return false
	return target.is_in_group("enemy") or target.is_in_group("slime") or target.is_in_group("boss") or target.is_in_group("stompable")


func get_area_from_path(path: NodePath) -> Area2D:
	if path == NodePath(""):
		return attack_area
	return get_node_or_null(path) as Area2D


func get_active_attack_name(index: int) -> StringName:
	return active_attack_names[index]


func get_active_attack_cooldown(index: int) -> float:
	return active_attack_cooldowns[index]


func get_active_attack_mana_cost(index: int) -> float:
	return active_attack_mana_costs[index]


func get_active_attack_damage(index: int) -> int:
	return active_attack_damages[index]


func get_active_attack_area(index: int) -> Area2D:
	return get_area_from_path(active_attack_area_paths[index])


func can_trigger_active_attack(index: int) -> bool:
	if index < 0 or index >= active_attack_names.size():
		return false
	return active_attack_timers[index] <= 0.0


func consume_attack_mana(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not can_use_mana_system():
		return true
	if not stats or not stats.has_method("consume_mana"):
		return true
	return stats.consume_mana(amount)


func consume_ultimate_mana() -> bool:
	if not can_use_mana_system():
		return true
	if not stats:
		return true
	if stats.has_method("consume_all_mana"):
		return stats.consume_all_mana()
	return false


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
