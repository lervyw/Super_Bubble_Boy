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
	IDLE, WALK, JUMP, ATTACK, CROUCH, DASH, TRANSFORM, DEAD, SWIM, SPECIAL_ATTACK, DEFEND, HURT
}

enum Form { NORMAL, BUBBLE, SUPER }
enum GameMode { PLATAFORMA, METROIDVANIA }
enum HudMenuAction { NONE, ULTIMATE, PLACEHOLDER, SPECIAL_ATTACK, BUBBLE_PROJECTILE }
enum WheelSlot { ULTIMATE, SPECIAL_ATTACK, BUBBLE_PROJECTILE, PLACEHOLDER }
enum AttackKind { NONE, NORMAL, PASSIVE, ACTIVE_SUPER, ULTIMATE, DEFEND }
enum PassivePower { NONE, GROUND_STOMP, QUICK_RUN, KILL_STOMP }

const ATTACK_META_DAMAGE := &"attack_damage"
const ATTACK_META_KIND := &"attack_kind"
const ATTACK_META_ID := &"attack_id"

const STAMINA_COST_DASH: float = 15.0
const STAMINA_COST_QUICK_RUN_PER_SEC: float = 10.0
const STAMINA_COST_ATTACK: float = 50.0
const STAMINA_COST_SPECIAL: float = 10.0
const STAMINA_COST_DEFEND: float = 0.0
const STAMINA_COST_DEFEND_HIT: float = 8.0
const SUPER_STAMINA_MULTIPLIER: float = 0.25

var hud_menu_open := false
var hud_menu_selection: HudMenuAction = HudMenuAction.NONE
var hud_menu_axis_locked := false
var hud_menu_selection_locked := false
var hud_menu_waiting_for_neutral := false

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

@export_group("Water Jump")
@export_range(1.0, 3.0, 0.05) var water_up_jump_multiplier: float = 1.35

@export_group("Camera Framing")
@export var camera_vertical_offset: float = -18.0
@export var camera_lookahead_distance: float = 80.0
@export_range(0.1, 20.0, 0.1) var camera_offset_smoothing: float = 5.0
@export_range(0.1, 20.0, 0.1) var camera_position_smoothing_speed: float = 6.0
@export_range(0.0, 1.0, 0.01) var camera_drag_left_margin: float = 0.35
@export_range(0.0, 1.0, 0.01) var camera_drag_right_margin: float = 0.10
@export_range(0.0, 1.0, 0.01) var camera_drag_top_margin: float = 0.25
@export_range(0.0, 1.0, 0.01) var camera_drag_bottom_margin: float = 0.38
@export_range(0.0, 200.0, 1.0) var camera_crouch_offset: float = 30.0

@export_group("Modes")
@export var platform_mode_uses_mana: bool = false
@export var platform_mode_allows_mana_attacks: bool = false
@export var force_normal_form_in_platform_mode: bool = true

@export_group("Death Settings")
@export_range(0.0, 5.0) var death_delay: float = 1.0
@export var hurt_animation_name: StringName = &"hurt"

@export_group("Dash Settings")
@export var dash_stops_fall: bool = false
@export_range(0.0, 1.0) var dash_fall_factor: float = 0.3
@export_range(0.0, 2.0) var dash_cooldown: float = 0.3

@export_group("Damage Settings")
@export_range(0.0, 5.0) var invincibility_time: float = 1.0

@export_group("Stomp Settings")
@export var stomp_requires_falling: bool = true
@export var stomp_kills_enemy: bool = true
@export var stomp_damage: int = 1
@export_range(0.0, 2000.0) var stomp_bounce_force_normal: float = 260.0
@export_range(0.0, 2000.0) var stomp_bounce_force_bubble: float = 180.0
@export_range(0.0, 2000.0) var stomp_bounce_force_super: float = 320.0
@export var stomper_normal: Area2D
@export var stomper_bubble: Area2D
@export var stomper_super: Area2D

@export_group("Normal Attack")
@export var normal_attack_damage: int = 2
@export var normal_attack_id: StringName = &"normal_attack"
@export_range(0.05, 1.0, 0.01) var normal_attack_active_time: float = 0.16

@export_group("Passive Attack Foundation")
@export var passive_attack_enabled: bool = false
@export var passive_attack_id: StringName = &"passive_pulse"
@export_range(0.1, 30.0, 0.1) var passive_attack_interval: float = 3.0
@export_range(0.05, 3.0, 0.05) var passive_attack_active_time: float = 0.15
@export var passive_attack_damage: int = 1
@export var passive_attack_requires_target: bool = false
@export var passive_attack_area_path: NodePath = NodePath("AttackHitbox")

@export_group("Selectable Passive Powers")
@export var selected_passive_power: PassivePower = PassivePower.NONE
@export var passive_powers_enabled: bool = true
@export var ground_stomp_damage: int = 2
@export_range(40.0, 260.0, 1.0) var ground_stomp_radius: float = 72.0
@export_range(200.0, 1600.0, 10.0) var ground_stomp_fall_speed: float = 900.0
@export_range(0.05, 0.6, 0.01) var ground_stomp_active_time: float = 0.12
@export_range(0.1, 3.0, 0.05) var ground_stomp_cooldown: float = 0.55
@export var ground_stomp_particle_texture: Texture2D = preload("res://sprites/characters/projectiles/projectile_bubble1.png")
@export_range(2, 16, 1) var ground_stomp_particle_count: int = 9
@export var ground_stomp_particle_scale: Vector2 = Vector2(0.32, 0.32)
@export var ground_stomp_particle_offset: Vector2 = Vector2(0.0, 18.0)
@export_range(8.0, 120.0, 1.0) var ground_stomp_particle_spread: float = 54.0
@export_range(0.1, 1.5, 0.05) var ground_stomp_particle_lifetime: float = 0.45
@export_range(0.05, 0.5, 0.01) var quick_run_double_tap_window: float = 0.25
@export_range(0.2, 6.0, 0.1) var quick_run_duration: float = 2.0
@export_range(1.0, 4.0, 0.05) var quick_run_speed_multiplier: float = 1.65
@export_range(0.0, 5.0, 0.05) var quick_run_cooldown: float = 0.5

@export_group("Active Super Attacks")
@export var active_attack_names: Array[StringName] = [&"super_attack_1"]
@export var active_attack_cooldowns: Array[float] = [1.5]
@export var active_attack_mana_costs: Array[float] = [20.0]
@export var active_attack_damages: Array[int] = [4]
@export var active_attack_area_paths: Array[NodePath] = [NodePath("AttackHitbox")]
@export var active_attack_active_times: Array[float] = [0.22]
@export var selected_active_attack_index: int = 0

@export_group("Bubble Projectile")
@export var bubble_projectile_scene: PackedScene = preload("res://Cenas/player_bubble_projectile.tscn")
@export var bubble_projectile_damage: int = 2
@export_range(0.0, 100.0, 1.0) var bubble_projectile_mana_cost: float = 12.0
@export_range(0.1, 10.0, 0.1) var bubble_projectile_cooldown: float = 1.0
@export var bubble_projectile_spawn_offset: Vector2 = Vector2(18.0, -6.0)
@export var bubble_projectile_animation: StringName = &"attack_projectile"

@export_group("Ultimate Attack")
@export var ultimate_attack_enabled: bool = true
@export var ultimate_attack_id: StringName = &"ultimate_attack"
@export_range(0.1, 60.0, 0.1) var ultimate_attack_cooldown: float = 20.0
@export var ultimate_attack_damage: int = 10
@export var ultimate_attack_area_path: NodePath = NodePath("AttackHitbox")
@export var allow_ultimate_input: bool = true
@export_range(0.05, 1.5, 0.01) var ultimate_attack_active_time: float = 0.3

@export_group("Normal Form Powers (Wheel)")
@export var protective_bubble_duration: float = 5.0
@export var protective_bubble_mana_cost: float = 15.0
@export var protective_bubble_damage: int = 1
@export var portal_bubble_scene: PackedScene = preload("res://Cenas/portal_bubble_projectile.tscn")
@export var portal_max_distance: float = 300.0
@export var portal_mana_cost: float = 10.0
@export var teleport_bubble_scene: PackedScene = preload("res://Cenas/teleport_bubble_projectile.tscn")
@export var teleport_bubble_max_distance: float = 250.0
@export var teleport_bubble_mana_cost: float = 18.0
@export var ghost_mode_duration: float = 10.0
@export var ghost_mode_mana_cost: float = 25.0
@export var ghost_mode_speed_multiplier: float = 1.35

@export_group("Super Form Powers (Wheel)")
@export var super_spike_damage: int = 5
@export_range(0.05, 1.0, 0.01) var super_spike_active_time: float = 0.35
@export_range(0.1, 10.0, 0.1) var super_spike_cooldown: float = 2.0
@export_range(0.0, 100.0, 1.0) var super_spike_mana_cost: float = 18.0
@export var super_launcher_damage: int = 4
@export_range(0.1, 10.0, 0.1) var super_launcher_cooldown: float = 1.5
@export_range(0.0, 100.0, 1.0) var super_launcher_mana_cost: float = 14.0
@export_range(0.1, 20.0, 0.1) var time_bubble_duration: float = 10.0
@export_range(0.1, 30.0, 0.1) var time_bubble_cooldown: float = 15.0
@export_range(0.0, 100.0, 1.0) var time_bubble_mana_cost: float = 30.0
@export_range(0.05, 1.0, 0.01) var super_parry_window: float = 0.45
@export_range(0.1, 10.0, 0.1) var super_parry_cooldown: float = 1.5
@export_range(0.0, 100.0, 1.0) var super_parry_mana_cost: float = 8.0
@export var super_parry_damage: int = 4

@export_group("Respawn")
@export var respawn_position: Vector2 = Vector2(288, 207)
@export var stats: Node = null

@export_group("Respawn Enemy Separation")
@export var release_enemy_contacts_on_respawn: bool = true
@export_range(1, 5, 1) var respawn_collision_release_frames: int = 2

@onready var attack_area: Area2D = $AttackHitbox
@onready var attack_collision: CollisionShape2D = $AttackHitbox/AttackCollisionShape
@onready var player_camera: Camera2D = $Camera
@onready var shield_area: Area2D = $ShieldHitbox

var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var passive_attack_timer := 0.0
var on_ground := false

var form: Form = Form.NORMAL
var state: State = State.IDLE
var mode: GameMode = GameMode.METROIDVANIA

var in_water: bool = false
var water_zone_overlap_count: int = 0
var target_form: Form = Form.NORMAL
var is_bouncing_from_enemy := false
var combo_lock := false
var defending := false
var super_shield_active := false
var bubble_jump_count := 0
var max_bubble_jumps := 40
var is_invincible: bool = false

var active_attack_timers: Array[float] = []
var ultimate_cooldown_timer: float = 0.0
var ultimate_cooldown_node: Timer
var bubble_projectile_cooldown_timer: float = 0.0
var current_attack_kind: AttackKind = AttackKind.NONE
var current_attack_id: StringName = &""
var current_attack_damage: int = 0
var current_attack_area: Area2D
var special_attack_animation_override: StringName = &""
var attack_window_serial: int = 0
var fatal_hit_sequence_running: bool = false
var hurt_sequence_running: bool = false
var ground_stomp_active: bool = false
var ground_stomp_cooldown_timer: float = 0.0
var ground_stomp_area: Area2D
var ground_stomp_shape: CollisionShape2D
var ground_stomp_anim_override: StringName = &""
var quick_run_active: bool = false
var quick_run_timer: float = 0.0
var quick_run_cooldown_timer: float = 0.0
var quick_run_direction: int = 0
var last_tap_direction: int = 0
var last_tap_time_left: float = 0.0
var was_left_pressed: bool = false
var was_right_pressed: bool = false

var protective_bubble_active := false
var protective_bubble_timer := 0.0
var protective_bubble_blink_time := 0.0
var bubble_shield: Area2D

var portals: Array[Node] = []
var portal_count := 0
var portal_bubble_traveling := false
var portal_bubble_ref: Node

var teleport_bubble_active := false
var teleport_bubble_traveling := false
var teleport_bubble_ref: Node
var teleport_bubble_intangible := false
var teleport_bubble_timer := 0.0

var ghost_mode_active := false
var ghost_mode_timer := 0.0
var ghost_mode_blink_time := 0.0
var saved_collision_layer: int = 0

var super_spike_area: Area2D
var super_spike_cooldown_timer := 0.0
var super_launcher_cooldown_timer := 0.0
var time_bubble_active := false
var time_bubble_time_left := 0.0
var time_bubble_cooldown_timer := 0.0
var time_frozen_nodes: Array[Node] = []
var super_parry_active := false
var super_parry_cooldown_timer := 0.0
var super_parry_serial := 0

var camera_follow_target: Node2D
var camera_follow_timer: float = 0.0

var unlocked_forms = {
	Form.NORMAL: true,
	Form.BUBBLE: false,
	Form.SUPER: false
}

var unlocked_wheel_slots = {
	Form.NORMAL: {
		WheelSlot.ULTIMATE: false,
		WheelSlot.SPECIAL_ATTACK: false,
		WheelSlot.BUBBLE_PROJECTILE: false,
		WheelSlot.PLACEHOLDER: false,
	},
	Form.BUBBLE: {
		WheelSlot.ULTIMATE: false,
		WheelSlot.SPECIAL_ATTACK: false,
		WheelSlot.BUBBLE_PROJECTILE: false,
		WheelSlot.PLACEHOLDER: false,
	},
	Form.SUPER: {
		WheelSlot.ULTIMATE: false,
		WheelSlot.SPECIAL_ATTACK: false,
		WheelSlot.BUBBLE_PROJECTILE: false,
		WheelSlot.PLACEHOLDER: false,
	}
}


func _ready() -> void:
	ensure_optional_input_actions()
	normalize_attack_configuration()

	if $Sprite2D and $Sprite2D.has_signal("attack_finished"):
		if not has_method("_on_attack_finished"):
			push_error("Player: método _on_attack_finished não encontrado!")
		else:
			$Sprite2D.attack_finished.connect(_on_attack_finished)

	if attack_collision:
		attack_collision.disabled = true

	if shield_area:
		shield_area.monitoring = false
		shield_area.monitorable = false
		if not shield_area.body_entered.is_connected(_on_shield_body_entered):
			shield_area.body_entered.connect(_on_shield_body_entered)
		if not shield_area.area_entered.is_connected(_on_shield_area_entered):
			shield_area.area_entered.connect(_on_shield_area_entered)

	if has_node("Hurtbox"):
		var hurtbox = $Hurtbox
		if hurtbox and not hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
			hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	elif has_node("HurtboxArea"):
		var hurtbox_area = $HurtboxArea
		if hurtbox_area and not hurtbox_area.area_entered.is_connected(_on_hurtbox_body_entered):
			hurtbox_area.area_entered.connect(_on_hurtbox_body_entered)

	connect_stomper_signals(stomper_normal)
	connect_stomper_signals(stomper_bubble)
	connect_stomper_signals(stomper_super)
	register_combat_area_groups()
	setup_ultimate_cooldown_timer()
	setup_selectable_passive_nodes()
	apply_selected_passive_power()
	setup_camera_framing()
	refresh_stompers_for_current_form()
	update_audio_by_form()
	passive_attack_timer = passive_attack_interval
	setup_protective_bubble_shield()
	setup_super_spike_area()


func ensure_optional_input_actions() -> void:
	for action_name in ["hud_select_up", "hud_select_down", "hud_select_left", "hud_select_right", "swim_up"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func _input(event):
	if state in [State.DEAD, State.HURT]:
		return

	if event.is_action_pressed("hud_menu"):
		open_hud_menu()
		return

	if event.is_action_released("hud_menu"):
		close_hud_menu()
		return

	if hud_menu_open:
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("attack_special"):
		start_special_attack()

	if event.is_action_pressed("defend"):
		start_defense()

	if allow_ultimate_input and InputMap.has_action("ultimate_attack") and event.is_action_pressed("ultimate_attack"):
		start_ultimate_attack()


func _process(_delta: float) -> void:
	update_camera_framing(_delta)

	if state == State.HURT:
		return

	if hud_menu_open:
		process_hud_menu_selection()
		return

	check_attack_combos()
	check_quick_form_selection()


func _physics_process(delta: float) -> void:
	refresh_stompers_for_current_form()
	update_attack_cooldowns(delta)
	process_passive_attack(delta)
	process_selectable_passives(delta)
	process_normal_form_powers(delta)

	if is_bouncing_from_enemy:
		is_bouncing_from_enemy = false

	on_ground = is_on_floor()
	if on_ground:
		bubble_jump_count = 0

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if hud_menu_open:
		if in_water:
			apply_water_physics(delta)
		else:
			apply_normal_gravity(delta)
		velocity.x = 0.0
		move_and_slide()
		return

	if in_water:
		apply_water_physics(delta)
	else:
		apply_normal_gravity(delta)

	handle_input()
	handle_state(delta)
	move_and_slide()
	process_ground_stomp_landing()


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
		active_attack_area_paths = [NodePath("AttackHitbox")]
	if active_attack_active_times.is_empty():
		active_attack_active_times = [0.22]

	while active_attack_cooldowns.size() < active_attack_names.size():
		active_attack_cooldowns.append(active_attack_cooldowns.back())
	while active_attack_mana_costs.size() < active_attack_names.size():
		active_attack_mana_costs.append(active_attack_mana_costs.back())
	while active_attack_damages.size() < active_attack_names.size():
		active_attack_damages.append(active_attack_damages.back())
	while active_attack_area_paths.size() < active_attack_names.size():
		active_attack_area_paths.append(active_attack_area_paths.back())
	while active_attack_active_times.size() < active_attack_names.size():
		active_attack_active_times.append(active_attack_active_times.back())

	active_attack_timers.resize(active_attack_names.size())
	for i in range(active_attack_timers.size()):
		active_attack_timers[i] = 0.0

	selected_active_attack_index = clampi(selected_active_attack_index, 0, active_attack_names.size() - 1)


func register_combat_area_groups() -> void:
	if attack_area and not attack_area.is_in_group("player_attack"):
		attack_area.add_to_group("player_attack")

	_update_stomper_group_for_passive()


func update_attack_cooldowns(delta: float) -> void:
	for i in range(active_attack_timers.size()):
		if active_attack_timers[i] > 0.0:
			active_attack_timers[i] = max(active_attack_timers[i] - delta, 0.0)
	if bubble_projectile_cooldown_timer > 0.0:
		bubble_projectile_cooldown_timer = max(bubble_projectile_cooldown_timer - delta, 0.0)
	super_spike_cooldown_timer = maxf(super_spike_cooldown_timer - delta, 0.0)
	super_launcher_cooldown_timer = maxf(super_launcher_cooldown_timer - delta, 0.0)
	time_bubble_cooldown_timer = maxf(time_bubble_cooldown_timer - delta, 0.0)
	super_parry_cooldown_timer = maxf(super_parry_cooldown_timer - delta, 0.0)
	update_time_bubble(delta)

	update_ultimate_cooldown_from_timer()


func setup_super_spike_area() -> void:
	if super_spike_area:
		return

	var example_shape := get_node_or_null("Hitbox_example_spike") as CollisionShape2D
	if not example_shape:
		push_warning("Player: Hitbox_example_spike não encontrado.")
		return

	super_spike_area = Area2D.new()
	super_spike_area.name = "SuperSpikeHitbox"
	super_spike_area.add_to_group("player_attack")
	add_child(super_spike_area)
	example_shape.reparent(super_spike_area)
	example_shape.name = "CollisionShape2D"
	set_area_collision_enabled(super_spike_area, false)


func setup_ultimate_cooldown_timer() -> void:
	ultimate_cooldown_node = Timer.new()
	ultimate_cooldown_node.name = "UltimateCooldownTimer"
	ultimate_cooldown_node.one_shot = true
	ultimate_cooldown_node.wait_time = maxf(ultimate_attack_cooldown, 0.1)
	add_child(ultimate_cooldown_node)

	if not ultimate_cooldown_node.timeout.is_connected(_on_ultimate_cooldown_timeout):
		ultimate_cooldown_node.timeout.connect(_on_ultimate_cooldown_timeout)


func start_ultimate_cooldown() -> void:
	ultimate_cooldown_timer = ultimate_attack_cooldown
	if not ultimate_cooldown_node:
		return

	ultimate_cooldown_node.stop()
	ultimate_cooldown_node.wait_time = maxf(ultimate_attack_cooldown, 0.1)
	ultimate_cooldown_node.start()


func update_ultimate_cooldown_from_timer() -> void:
	if not ultimate_cooldown_node:
		return
	if ultimate_cooldown_node.is_stopped():
		ultimate_cooldown_timer = 0.0
	else:
		ultimate_cooldown_timer = ultimate_cooldown_node.time_left


func _on_ultimate_cooldown_timeout() -> void:
	ultimate_cooldown_timer = 0.0


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


func set_passive_attack_enabled(enabled: bool) -> void:
	passive_attack_enabled = enabled
	passive_attack_timer = passive_attack_interval if enabled else 0.0


func toggle_passive_attack() -> void:
	set_passive_attack_enabled(not passive_attack_enabled)


func configure_passive_attack(interval: float, active_time: float, damage: int) -> void:
	passive_attack_interval = maxf(interval, 0.1)
	passive_attack_active_time = maxf(active_time, 0.05)
	passive_attack_damage = max(damage, 1)
	if passive_attack_enabled:
		passive_attack_timer = passive_attack_interval


func get_passive_power_names() -> Array[String]:
	return [
		"Nenhuma",
		"Stomp no chao",
		"Corrida rapida",
		"Kill Stomp"
	]


func set_selected_passive_power(power_index: int) -> void:
	selected_passive_power = clampi(power_index, PassivePower.NONE, PassivePower.KILL_STOMP)
	apply_selected_passive_power()


func get_selected_passive_power() -> int:
	return int(selected_passive_power)


func apply_selected_passive_power() -> void:
	passive_attack_enabled = false
	ground_stomp_active = false
	quick_run_active = false
	quick_run_timer = 0.0
	quick_run_direction = 0

	if ground_stomp_area:
		set_area_collision_enabled(ground_stomp_area, false)

	_update_stomper_group_for_passive()


func _update_stomper_group_for_passive() -> void:
	var kill_stomp_selected := passive_powers_enabled and selected_passive_power == PassivePower.KILL_STOMP
	if kill_stomp_selected:
		_add_stompers_to_kill_group()
	else:
		_remove_stompers_from_kill_group()


func _add_stompers_to_kill_group() -> void:
	for stomper in [stomper_normal, stomper_bubble, stomper_super]:
		if stomper and not stomper.is_in_group("player_stomper"):
			stomper.add_to_group("player_stomper")


func _remove_stompers_from_kill_group() -> void:
	for stomper in [stomper_normal, stomper_bubble, stomper_super]:
		if stomper and stomper.is_in_group("player_stomper"):
			stomper.remove_from_group("player_stomper")


func set_passive_powers_enabled(enabled: bool) -> void:
	passive_powers_enabled = enabled
	if not enabled:
		ground_stomp_active = false
		quick_run_active = false
		quick_run_timer = 0.0
		quick_run_direction = 0
		if ground_stomp_area:
			set_area_collision_enabled(ground_stomp_area, false)
		_remove_stompers_from_kill_group()
	else:
		apply_selected_passive_power()


func are_passive_powers_enabled() -> bool:
	return passive_powers_enabled


func setup_selectable_passive_nodes() -> void:
	setup_ground_stomp_node()


func setup_ground_stomp_node() -> void:
	if ground_stomp_area:
		return

	ground_stomp_area = Area2D.new()
	ground_stomp_area.name = "PassiveGroundStompArea"
	ground_stomp_area.set_meta(ATTACK_META_DAMAGE, max(ground_stomp_damage, 1))
	ground_stomp_area.set_meta(ATTACK_META_KIND, int(AttackKind.PASSIVE))
	ground_stomp_area.set_meta(ATTACK_META_ID, "ground_stomp")
	add_child(ground_stomp_area)

	ground_stomp_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = ground_stomp_radius
	ground_stomp_shape.shape = shape
	ground_stomp_area.add_child(ground_stomp_shape)

	set_area_collision_enabled(ground_stomp_area, false)


func setup_protective_bubble_shield() -> void:
	if bubble_shield:
		return
	bubble_shield = Area2D.new()
	bubble_shield.name = "ProtectiveBubbleShield"
	bubble_shield.set_meta(ATTACK_META_DAMAGE, protective_bubble_damage)
	bubble_shield.set_meta(ATTACK_META_KIND, int(AttackKind.PASSIVE))
	bubble_shield.set_meta(ATTACK_META_ID, "protective_bubble")
	bubble_shield.add_to_group("player_attack")
	add_child(bubble_shield)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	bubble_shield.add_child(shape)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = preload("res://sprites/characters/projectiles/projectile_bubble1.png")
	sprite.scale = Vector2(0.65, 0.65)
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.material = null
	bubble_shield.add_child(sprite)

	bubble_shield.visible = false
	set_area_collision_enabled(bubble_shield, false)


func process_normal_form_powers(delta: float) -> void:
	if form != Form.NORMAL:
		_deactivate_protective_bubble()
		_deactivate_ghost_mode()
		if teleport_bubble_intangible:
			_end_teleport_intangibility()
		return

	_cleanup_invalid_portals()
	_check_portal_interaction()

	if protective_bubble_active:
		protective_bubble_timer -= delta
		protective_bubble_blink_time += delta
		var t := protective_bubble_timer
		bubble_shield.position = Vector2(
			cos(t * 3.0) * 26.0,
			sin(t * 3.0) * 26.0
		)
		var sprite := bubble_shield.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			var pulse := sin(protective_bubble_blink_time * 8.0) * 0.5 + 0.5
			var blue := Color(0.3, 0.6, 1.0, 1.0)
			var white := Color(1.0, 1.0, 1.0, 1.0)
			sprite.modulate = white.lerp(blue, pulse)
		if protective_bubble_timer <= 0.0:
			_deactivate_protective_bubble()

	if ghost_mode_active:
		ghost_mode_timer -= delta
		ghost_mode_blink_time += delta
		var alpha := 0.4 + sin(ghost_mode_blink_time * 16.0) * 0.3
		modulate.a = clampf(alpha, 0.1, 1.0)
		if ghost_mode_timer <= 0.0:
			_deactivate_ghost_mode()

	if teleport_bubble_intangible:
		teleport_bubble_timer -= delta
		if teleport_bubble_timer <= 0.0:
			_end_teleport_intangibility()


func _deactivate_protective_bubble() -> void:
	if not protective_bubble_active:
		return
	protective_bubble_active = false
	protective_bubble_timer = 0.0
	protective_bubble_blink_time = 0.0
	if is_instance_valid(bubble_shield):
		bubble_shield.visible = false
		set_area_collision_enabled(bubble_shield, false)
		var sprite := bubble_shield.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			sprite.modulate.a = 1.0


func _end_teleport_intangibility() -> void:
	teleport_bubble_intangible = false
	teleport_bubble_timer = 0.0
	teleport_bubble_traveling = false
	teleport_bubble_ref = null
	is_invincible = false
	modulate.a = 1.0


func _do_teleport_arrival() -> void:
	if teleport_bubble_ref and is_instance_valid(teleport_bubble_ref):
		var safe_pos := _find_safe_teleport_position(teleport_bubble_ref.global_position)
		global_position = safe_pos
		teleport_bubble_ref.queue_free()
	teleport_bubble_ref = null
	teleport_bubble_active = false
	teleport_bubble_traveling = false
	_end_teleport_intangibility()
	_play_and_wait_for_arrive()


func _on_teleport_bubble_arrived(pos: Vector2) -> void:
	var safe_pos := _find_safe_teleport_position(pos)
	global_position = safe_pos
	_stop_camera_follow()
	teleport_bubble_ref = null
	teleport_bubble_active = false
	teleport_bubble_traveling = false
	_end_teleport_intangibility()
	_play_and_wait_for_arrive()


func _play_and_wait_for_arrive() -> void:
	var sprite := $Sprite2D as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"bubble_throw_arrive"):
		special_attack_animation_override = &"bubble_throw_arrive"
		change_state(State.SPECIAL_ATTACK)
		sprite.play(&"bubble_throw_arrive")
		await sprite.animation_finished
	special_attack_animation_override = &""
	deactivate_attack_area()
	defending = false
	change_state(State.IDLE)


func _find_safe_teleport_position(target: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	if not space:
		return target
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	query.shape = shape
	query.collision_mask = collision_mask
	for offset_y in [0, -16, -32, -48, 16]:
		var test_pos := target + Vector2(0, offset_y)
		query.transform = Transform2D(0, test_pos)
		var results := space.intersect_shape(query)
		if results.is_empty():
			return test_pos
	return target


func _deactivate_ghost_mode() -> void:
	if not ghost_mode_active:
		return
	ghost_mode_active = false
	ghost_mode_timer = 0.0
	is_invincible = false
	modulate.a = 1.0
	if saved_collision_layer != 0:
		collision_layer = saved_collision_layer
		saved_collision_layer = 0
	push_out_of_enemies()


func push_out_of_enemies() -> void:
	var push_dir := Vector2.ZERO
	for body in get_tree().get_nodes_in_group(&"slime"):
		if not is_instance_valid(body):
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist < 40.0:
			push_dir += (global_position - body.global_position).normalized() * (1.0 - dist / 40.0)
	if push_dir != Vector2.ZERO:
		push_dir = push_dir.normalized() * 80.0
		velocity += push_dir
		move_and_slide()


func start_protective_bubble() -> void:
	if protective_bubble_active:
		return
	if not can_use_mana_attacks():
		return
	if not consume_attack_mana(protective_bubble_mana_cost):
		return
	protective_bubble_active = true
	protective_bubble_timer = protective_bubble_duration
	if not bubble_shield:
		setup_protective_bubble_shield()
	if bubble_shield:
		bubble_shield.visible = true
		set_area_collision_enabled(bubble_shield, true)


func fire_portal_bubble() -> void:
	if not can_use_mana_attacks():
		return
	if not consume_attack_mana(portal_mana_cost):
		return
	if portal_bubble_scene == null:
		return
	var bubble := portal_bubble_scene.instantiate()
	var dir := get_facing_direction()
	bubble.global_position = global_position + Vector2(18.0 * dir, -6.0)
	if bubble.has_method("setup"):
		bubble.setup(Vector2(float(dir), 0.0))
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(bubble)
	portal_bubble_traveling = true
	portal_bubble_ref = bubble

	_start_camera_follow(bubble, 2.0)


func _on_portal_bubble_hit(pos: Vector2) -> void:
	if portal_count >= 2:
		for p in portals:
			if is_instance_valid(p):
				p.queue_free()
		portals.clear()
		portal_count = 0
	var portal_scene := preload("res://Cenas/portal.tscn")
	var portal := portal_scene.instantiate()
	portal.global_position = pos
	portal.player_ref = self
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(portal)
	portals.append(portal)
	portal_count += 1
	if portal_count == 2:
		var a = portals[0]
		var b = portals[1]
		if is_instance_valid(a) and is_instance_valid(b):
			a.linked_portal = b
			b.linked_portal = a
	portal_bubble_traveling = false
	portal_bubble_ref = null
	_stop_camera_follow()


func _cleanup_invalid_portals() -> void:
	var valid: Array[Node] = []
	for p in portals:
		if is_instance_valid(p):
			valid.append(p)
		else:
			portal_count -= 1
	portals = valid
	if portal_count < 0:
		portal_count = 0


func deactivate_portal(portal_node: Node) -> void:
	var idx := portals.find(portal_node)
	if idx >= 0:
		portals.remove_at(idx)
		portal_count -= 1
		if portal_count == 1 and portals.size() == 1 and is_instance_valid(portals[0]):
			portals[0].linked_portal = null
	if is_instance_valid(portal_node):
		portal_node.queue_free()


func _check_portal_interaction() -> void:
	if portal_count <= 0:
		return
	if not Input.is_action_just_pressed("defend"):
		return
	var nearest_portal: Node = null
	var min_dist := 40.0
	for p in portals:
		if not is_instance_valid(p):
			continue
		var dist := global_position.distance_to(p.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_portal = p
	if nearest_portal:
		deactivate_portal(nearest_portal)


func start_teleport_bubble() -> void:
	if teleport_bubble_active:
		return
	if not can_use_mana_attacks():
		return
	if not consume_attack_mana(teleport_bubble_mana_cost):
		return
	if teleport_bubble_scene == null:
		return
	teleport_bubble_active = true
	special_attack_animation_override = &"bubble_throw"
	change_state(State.SPECIAL_ATTACK)
	await _wait_for_animation(&"bubble_throw")
	special_attack_animation_override = &""
	if state == State.SPECIAL_ATTACK:
		change_state(State.IDLE)
	_fire_teleport_bubble()


func play_bubble_throw_animation() -> void:
	if has_node("Sprite2D"):
		var sprite := $Sprite2D as AnimatedSprite2D
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"bubble_throw"):
			sprite.play(&"bubble_throw")


func play_bubble_throw_arrive_animation() -> void:
	if has_node("Sprite2D"):
		var sprite := $Sprite2D as AnimatedSprite2D
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"bubble_throw_arrive"):
			sprite.play(&"bubble_throw_arrive")


func _wait_for_animation(anim_name: StringName) -> void:
	var sprite := $Sprite2D as AnimatedSprite2D
	if not sprite:
		return
	if not sprite.sprite_frames or not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation == anim_name and not sprite.is_playing():
		return
	await get_tree().process_frame
	if is_instance_valid(sprite) and sprite.animation == anim_name and sprite.is_playing():
		await sprite.animation_finished


func _fire_teleport_bubble() -> void:
	if teleport_bubble_scene == null:
		return
	var bubble := teleport_bubble_scene.instantiate()
	var dir := get_facing_direction()
	var origin := get_node_or_null("origem_throw_teleporte") as Node2D
	if origin:
		var origin_pos := origin.position
		var flipped_pos := Vector2(origin_pos.x * dir, origin_pos.y)
		bubble.global_position = to_global(flipped_pos)
	else:
		bubble.global_position = global_position + Vector2(22.0 * dir, -4.0)
	if bubble.has_method("setup"):
		bubble.setup(Vector2(float(dir), 0.0))
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(bubble)
	_start_camera_follow(bubble, 2.0)
	teleport_bubble_traveling = true
	teleport_bubble_ref = bubble
	teleport_bubble_intangible = true
	teleport_bubble_timer = 3.0
	is_invincible = true
	modulate.a = 0.0


func set_player_body_collisions_disabled_for_enemies(disabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = disabled


func start_ghost_mode() -> void:
	if ghost_mode_active:
		return
	if not can_use_mana_attacks():
		return
	if not consume_attack_mana(ghost_mode_mana_cost):
		return
	ghost_mode_active = true
	ghost_mode_timer = ghost_mode_duration
	ghost_mode_blink_time = 0.0
	is_invincible = true
	saved_collision_layer = collision_layer
	collision_layer = 0


func process_selectable_passives(delta: float) -> void:
	if last_tap_time_left > 0.0:
		last_tap_time_left = max(last_tap_time_left - delta, 0.0)
	if ground_stomp_cooldown_timer > 0.0:
		ground_stomp_cooldown_timer = max(ground_stomp_cooldown_timer - delta, 0.0)
	if quick_run_cooldown_timer > 0.0:
		quick_run_cooldown_timer = max(quick_run_cooldown_timer - delta, 0.0)

	if not passive_powers_enabled:
		ground_stomp_active = false
		quick_run_active = false
		return

	if selected_passive_power == PassivePower.GROUND_STOMP:
		check_ground_stomp_input()

	if selected_passive_power == PassivePower.QUICK_RUN:
		check_quick_run_input(delta)
	else:
		quick_run_active = false

	update_quick_run_timer(delta)


func check_ground_stomp_input() -> void:
	if ground_stomp_active:
		return
	if ground_stomp_cooldown_timer > 0.0:
		return
	if is_on_floor():
		return
	if not is_down_pressed():
		return
	if not Input.is_action_just_pressed("attack"):
		return

	ground_stomp_active = true
	velocity.y = abs(ground_stomp_fall_speed)
	change_state(State.JUMP)


func process_ground_stomp_landing() -> void:
	if not ground_stomp_active:
		return
	if not is_on_floor():
		return

	ground_stomp_active = false
	ground_stomp_cooldown_timer = ground_stomp_cooldown
	trigger_ground_stomp_burst()

	var sp = $Sprite2D
	if sp and sp.sprite_frames and sp.sprite_frames.has_animation(&"bubble_ground_stomp"):
		ground_stomp_anim_override = &"bubble_ground_stomp"
		sp.play(&"bubble_ground_stomp")
		await sp.animation_finished
		ground_stomp_anim_override = &""


func trigger_ground_stomp_burst() -> void:
	if not ground_stomp_area:
		return

	ground_stomp_area.global_position = get_ground_stomp_origin()
	ground_stomp_area.set_meta(ATTACK_META_DAMAGE, max(ground_stomp_damage, 1))
	set_area_collision_enabled(ground_stomp_area, true)
	spawn_ground_stomp_particles()
	apply_passive_area_damage_once(ground_stomp_area, max(ground_stomp_damage, 1))
	_close_ground_stomp_burst()


func get_current_stomper() -> Area2D:
	match form:
		Form.BUBBLE:
			return stomper_bubble
		Form.SUPER:
			return stomper_super
		_:
			return stomper_normal


func get_ground_stomp_origin() -> Vector2:
	var stomper := get_current_stomper()
	if stomper:
		for child in stomper.get_children():
			if child is CollisionShape2D:
				return (child as CollisionShape2D).global_position
		return stomper.global_position
	return global_position + ground_stomp_particle_offset


func spawn_ground_stomp_particles() -> void:
	if not ground_stomp_particle_texture:
		return

	var root := Node2D.new()
	root.name = "GroundStompBubbleParticles"
	root.z_index = 50
	var particle_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	particle_parent.add_child(root)
	root.global_position = get_ground_stomp_origin()

	var count: int = max(ground_stomp_particle_count, 1)
	for i in range(count):
		var particle := Sprite2D.new()
		particle.texture = ground_stomp_particle_texture
		particle.scale = ground_stomp_particle_scale
		particle.modulate = Color(1, 1, 1, 1.0)
		particle.z_index = 50
		root.add_child(particle)

		var side := -1.0 if i % 2 == 0 else 1.0
		var step := float(i / 2 + 1) / float(count / 2 + 1)
		var target := Vector2(
			side * ground_stomp_particle_spread * step,
			-10.0 - ground_stomp_particle_spread * 0.35 * step
		)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target, ground_stomp_particle_lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", ground_stomp_particle_scale * 1.35, ground_stomp_particle_lifetime)
		tween.tween_property(particle, "modulate:a", 0.0, ground_stomp_particle_lifetime)

	await get_tree().create_timer(ground_stomp_particle_lifetime).timeout
	if is_instance_valid(root):
		root.queue_free()


func apply_passive_area_damage_once(area: Area2D, damage: int) -> void:
	await get_tree().physics_frame
	if not is_instance_valid(area):
		return

	var damaged_targets := {}
	for overlapping_area in area.get_overlapping_areas():
		var target := resolve_attack_receiver_target(overlapping_area)
		if target and target.has_method("take_damage") and not damaged_targets.has(target):
			damaged_targets[target] = true
			target.take_damage(damage)

	for body in area.get_overlapping_bodies():
		var target := resolve_attack_receiver_target(body)
		if target and target.has_method("take_damage") and not damaged_targets.has(target):
			damaged_targets[target] = true
			target.take_damage(damage)


func resolve_attack_receiver_target(node: Node) -> Node:
	var current := node
	while current != null:
		if current.name == "AttackReceiver" or current.is_in_group("stompable"):
			return current.get_parent()
		if current.is_in_group("enemy") or current.is_in_group("slime") or current.is_in_group("boss"):
			return current
		current = current.get_parent()
	return null


func _close_ground_stomp_burst() -> void:
	await get_tree().create_timer(ground_stomp_active_time).timeout
	if ground_stomp_area:
		set_area_collision_enabled(ground_stomp_area, false)


func check_quick_run_input(_delta: float) -> void:
	if form != Form.NORMAL:
		return

	var left_pressed := is_left_pressed()
	var right_pressed := is_right_pressed()

	if left_pressed and not was_left_pressed:
		register_quick_run_tap(-1)
	if right_pressed and not was_right_pressed:
		register_quick_run_tap(1)

	was_left_pressed = left_pressed
	was_right_pressed = right_pressed


func register_quick_run_tap(direction: int) -> void:
	if quick_run_active or quick_run_cooldown_timer > 0.0:
		last_tap_direction = direction
		last_tap_time_left = quick_run_double_tap_window
		return

	if last_tap_direction == direction and last_tap_time_left > 0.0:
		start_quick_run(direction)
	else:
		last_tap_direction = direction
		last_tap_time_left = quick_run_double_tap_window


func start_quick_run(direction: int) -> void:
	quick_run_active = true
	quick_run_timer = quick_run_duration
	quick_run_direction = direction
	last_tap_time_left = 0.0
	last_tap_direction = 0


func update_quick_run_timer(delta: float) -> void:
	if not quick_run_active:
		return

	if form != Form.NORMAL:
		quick_run_active = false
		quick_run_direction = 0
		quick_run_cooldown_timer = quick_run_cooldown
		return

	if not has_stamina(STAMINA_COST_QUICK_RUN_PER_SEC * delta):
		quick_run_active = false
		quick_run_direction = 0
		quick_run_cooldown_timer = quick_run_cooldown
		return

	consume_stamina(STAMINA_COST_QUICK_RUN_PER_SEC * delta)

	quick_run_timer = max(quick_run_timer - delta, 0.0)
	if quick_run_timer <= 0.0 or not is_forward_pressed(quick_run_direction):
		quick_run_active = false
		quick_run_direction = 0
		quick_run_cooldown_timer = quick_run_cooldown


func is_passive_run_boosting() -> bool:
	return passive_powers_enabled and selected_passive_power == PassivePower.QUICK_RUN and quick_run_active


func is_left_pressed() -> bool:
	return Input.is_action_pressed("left") or Input.is_action_pressed("ui_left")


func is_right_pressed() -> bool:
	return Input.is_action_pressed("right") or Input.is_action_pressed("ui_right")


func is_down_pressed() -> bool:
	return Input.is_action_pressed("crouch") or Input.is_action_pressed("ui_down")


func is_forward_pressed(direction: int) -> bool:
	if direction < 0:
		return is_left_pressed()
	if direction > 0:
		return is_right_pressed()
	return false


func handle_input() -> void:
	if hud_menu_open or state in [State.HURT, State.DEAD, State.SPECIAL_ATTACK]:
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
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM, State.HURT]:
		return
	if not can_use_mana_attacks():
		return
	if not can_trigger_active_attack(selected_active_attack_index):
		return
	if not has_stamina(STAMINA_COST_SPECIAL):
		show_stamina_warning()
		return

	var attack_name := get_active_attack_name(selected_active_attack_index)
	var mana_cost := get_active_attack_mana_cost(selected_active_attack_index)
	if not consume_attack_mana(mana_cost):
		return

	defending = false
	consume_stamina(STAMINA_COST_SPECIAL * (SUPER_STAMINA_MULTIPLIER if form == Form.SUPER else 1.0))
	prepare_attack_area(
		get_active_attack_area(selected_active_attack_index),
		get_active_attack_damage(selected_active_attack_index),
		AttackKind.ACTIVE_SUPER,
		attack_name
	)
	active_attack_timers[selected_active_attack_index] = get_active_attack_cooldown(selected_active_attack_index)
	change_state(State.SPECIAL_ATTACK)
	trigger_attack_window(get_active_attack_active_time(selected_active_attack_index))


func start_ultimate_attack() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM, State.HURT]:
		return
	if not can_use_ultimate_attack():
		if can_attempt_ultimate_attack() and not has_full_mana_for_ultimate():
			show_mana_warning()
		return
	if not consume_ultimate_mana():
		show_mana_warning()
		return

	defending = false
	prepare_attack_area(
		get_area_from_path(ultimate_attack_area_path),
		ultimate_attack_damage,
		AttackKind.ULTIMATE,
		ultimate_attack_id
	)
	start_ultimate_cooldown()
	change_state(State.SPECIAL_ATTACK)
	trigger_attack_window(ultimate_attack_active_time)


func start_defense() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM, State.HURT]:
		return

	defending = true
	change_state(State.DEFEND)


func start_super_shield() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM, State.HURT]:
		return

	if not consume_stamina(STAMINA_COST_DASH):
		return

	defending = true
	super_shield_active = true
	if shield_area:
		shield_area.monitoring = true
		shield_area.monitorable = true
	change_state(State.DEFEND)


func start_bubble_projectile() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM, State.HURT]:
		return
	if bubble_projectile_scene == null:
		return
	if bubble_projectile_cooldown_timer > 0.0:
		return
	if not can_use_mana_attacks():
		return
	if not consume_attack_mana(bubble_projectile_mana_cost):
		return

	defending = false
	bubble_projectile_cooldown_timer = bubble_projectile_cooldown
	special_attack_animation_override = bubble_projectile_animation
	change_state(State.SPECIAL_ATTACK)

	spawn_bubble_projectile()

	var animation_time := get_sprite_animation_duration(bubble_projectile_animation)
	await get_tree().create_timer(maxf(animation_time, 0.18)).timeout
	if special_attack_animation_override == bubble_projectile_animation:
		special_attack_animation_override = &""
	if state == State.SPECIAL_ATTACK:
		change_state(State.IDLE)


func start_super_spike() -> void:
	if not _can_start_super_wheel_power(super_spike_cooldown_timer):
		return
	if not consume_attack_mana(super_spike_mana_cost):
		return
	if not super_spike_area:
		setup_super_spike_area()
	if not super_spike_area:
		return

	super_spike_cooldown_timer = super_spike_cooldown
	special_attack_animation_override = &"super_espinho"
	prepare_attack_area(super_spike_area, super_spike_damage, AttackKind.ACTIVE_SUPER, &"super_spike")
	change_state(State.SPECIAL_ATTACK)
	trigger_attack_window(super_spike_active_time)
	await _finish_super_power_animation(&"super_espinho")


func start_super_launcher() -> void:
	if not _can_start_super_wheel_power(super_launcher_cooldown_timer):
		return
	if bubble_projectile_scene == null:
		return
	if not consume_attack_mana(super_launcher_mana_cost):
		return

	super_launcher_cooldown_timer = super_launcher_cooldown
	special_attack_animation_override = &"super_lancador"
	change_state(State.SPECIAL_ATTACK)
	var animation_time := maxf(get_sprite_animation_duration(&"super_lancador"), 0.3)
	await get_tree().create_timer(animation_time * 0.55).timeout
	if state == State.SPECIAL_ATTACK and form == Form.SUPER:
		spawn_super_launcher_projectile()
	await get_tree().create_timer(animation_time * 0.45).timeout
	_finish_super_power_state(&"super_lancador")


func spawn_super_launcher_projectile() -> void:
	var projectile := bubble_projectile_scene.instantiate()
	var dir := get_facing_direction()
	projectile.global_position = global_position + Vector2(bubble_projectile_spawn_offset.x * dir, bubble_projectile_spawn_offset.y)
	if "vertical_wave_amplitude" in projectile:
		projectile.vertical_wave_amplitude = 0.0
	if "attack_id" in projectile:
		projectile.attack_id = &"super_launcher"
	if projectile.has_method("setup"):
		projectile.setup(Vector2(float(dir), 0.0), super_launcher_damage)
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(projectile)


func start_time_bubble() -> void:
	if time_bubble_active or not _can_start_super_wheel_power(time_bubble_cooldown_timer):
		return
	if not consume_attack_mana(time_bubble_mana_cost):
		return

	time_bubble_cooldown_timer = time_bubble_cooldown
	special_attack_animation_override = &"super_warudo"
	change_state(State.SPECIAL_ATTACK)
	await get_tree().create_timer(maxf(get_sprite_animation_duration(&"super_warudo"), 0.2)).timeout
	if form != Form.SUPER or state in [State.DEAD, State.HURT]:
		_finish_super_power_state(&"super_warudo")
		return

	_finish_super_power_state(&"super_warudo")
	time_bubble_active = true
	time_bubble_time_left = time_bubble_duration
	_freeze_time_targets()


func start_super_parry() -> void:
	if not _can_start_super_wheel_power(super_parry_cooldown_timer):
		return
	if not consume_attack_mana(super_parry_mana_cost):
		return

	super_parry_cooldown_timer = super_parry_cooldown
	super_parry_serial += 1
	var serial := super_parry_serial
	super_parry_active = true
	defending = true
	special_attack_animation_override = &""
	change_state(State.DEFEND)
	await get_tree().create_timer(super_parry_window).timeout
	if serial != super_parry_serial:
		return
	super_parry_active = false
	defending = false
	if state == State.DEFEND:
		change_state(State.IDLE if is_on_floor() else State.JUMP)


func _can_start_super_wheel_power(cooldown_left: float) -> bool:
	if form != Form.SUPER or cooldown_left > 0.0:
		return false
	return state not in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM, State.HURT]


func _finish_super_power_animation(animation_name: StringName) -> void:
	await get_tree().create_timer(maxf(get_sprite_animation_duration(animation_name), 0.2)).timeout
	_finish_super_power_state(animation_name)


func _finish_super_power_state(animation_name: StringName) -> void:
	if special_attack_animation_override == animation_name:
		special_attack_animation_override = &""
	if state == State.SPECIAL_ATTACK:
		change_state(State.IDLE if is_on_floor() else State.JUMP)


func update_time_bubble(delta: float) -> void:
	if not time_bubble_active:
		return
	_freeze_new_time_targets()
	time_bubble_time_left = maxf(time_bubble_time_left - delta, 0.0)
	if time_bubble_time_left <= 0.0:
		_end_time_bubble()


func _freeze_time_targets() -> void:
	time_frozen_nodes.clear()
	_freeze_new_time_targets()


func _freeze_new_time_targets() -> void:
	for group_name in [&"slime", &"boss", &"enemy", &"boss_projectile"]:
		for target in get_tree().get_nodes_in_group(group_name):
			if target == self or target in time_frozen_nodes or not is_instance_valid(target):
				continue
			time_frozen_nodes.append(target)
			if target.has_method("set_time_frozen"):
				target.set_time_frozen(true)
			elif target is Node:
				target.set_process(false)
				target.set_physics_process(false)


func _end_time_bubble() -> void:
	time_bubble_active = false
	time_bubble_time_left = 0.0
	for target in time_frozen_nodes:
		if not is_instance_valid(target):
			continue
		if target.has_method("set_time_frozen"):
			target.set_time_frozen(false)
		else:
			target.set_process(true)
			target.set_physics_process(true)
	time_frozen_nodes.clear()


func is_time_bubble_active() -> bool:
	return time_bubble_active


func get_time_bubble_time_left() -> float:
	return time_bubble_time_left


func spawn_bubble_projectile() -> void:
	var projectile := bubble_projectile_scene.instantiate()
	var dir := get_facing_direction()
	projectile.global_position = global_position + Vector2(bubble_projectile_spawn_offset.x * dir, bubble_projectile_spawn_offset.y)
	if projectile.has_method("setup"):
		projectile.setup(Vector2(float(dir), 0.0), bubble_projectile_damage)
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(projectile)


func get_facing_direction() -> int:
	if has_node("Sprite2D") and $Sprite2D.flip_h:
		return -1
	return 1


func stop_defense() -> void:
	defending = false
	deactivate_attack_area()

	if state == State.DEFEND:
		change_state(State.IDLE)


func check_attack_combos() -> void:
	if hud_menu_open or combo_lock or state in [State.DEAD, State.HURT]:
		return

	if InputMap.has_action("combo_1") and Input.is_action_just_pressed("combo_1"):
		execute_combo(1)
	elif InputMap.has_action("combo_2") and Input.is_action_just_pressed("combo_2"):
		execute_combo(2)
	elif InputMap.has_action("combo_3") and Input.is_action_just_pressed("combo_3"):
		execute_combo(3)
	elif InputMap.has_action("combo_4") and Input.is_action_just_pressed("combo_4"):
		execute_combo(4)
	elif Input.is_action_pressed("attack") and Input.is_action_pressed("attack_special"):
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
	trigger_attack_window(normal_attack_active_time)
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
	velocity.x = 0.0


func defend_state() -> void:
	velocity.x = 0.0

	if super_shield_active:
		_update_shield_direction()
		if shield_area:
			for body in shield_area.get_overlapping_bodies():
				_push_enemy_away(body)
			for area in shield_area.get_overlapping_areas():
				_push_enemy_away(area)

		if not Input.is_action_pressed("dash"):
			super_shield_active = false
			defending = false
			if shield_area:
				shield_area.monitoring = false
				shield_area.monitorable = false
			change_state(State.IDLE if is_on_floor() else State.JUMP)


func enable_metroidvania_mode() -> void:
	mode = GameMode.METROIDVANIA
	print("🔥 Modo Metroidvania ativado!")
	restore_resources_full()


func enable_plataforma_mode() -> void:
	mode = GameMode.METROIDVANIA
	print("🎮 Modo Plataforma ignorado: gameplay atual usa apenas Metroidvania.")
	restore_resources_full()


func can_transform() -> bool:
	return unlocked_forms.get(Form.BUBBLE, false) or unlocked_forms.get(Form.SUPER, false)


func is_wheel_slot_unlocked(slot: WheelSlot) -> bool:
	return unlocked_wheel_slots.get(form, {}).get(slot, false)

func is_wheel_slot_unlocked_for_form(slot: WheelSlot, f: Form) -> bool:
	return unlocked_wheel_slots.get(f, {}).get(slot, false)

func get_unlocked_wheel_slots_for_form(f: Form) -> Array[WheelSlot]:
	var slots: Array[WheelSlot] = []
	var form_slots = unlocked_wheel_slots.get(f, {})
	for slot in form_slots.keys():
		if form_slots[slot]:
			slots.append(slot)
	return slots

func get_unlocked_wheel_slots_for_current_form() -> Array[WheelSlot]:
	return get_unlocked_wheel_slots_for_form(form)

func get_wheel_slot_name(slot: WheelSlot) -> String:
	match slot:
		WheelSlot.ULTIMATE:
			return "ultimate_attack"
		WheelSlot.SPECIAL_ATTACK:
			return "attack_special"
		WheelSlot.BUBBLE_PROJECTILE:
			return "bubble_projectile"
		WheelSlot.PLACEHOLDER:
			return "placeholder"
	return "none"

func can_dash_global() -> bool:
	return true


func can_use_mana_system() -> bool:
	return true


func can_use_mana_attacks() -> bool:
	return true


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
	if stats.has_method("restore_full_stamina"):
		stats.restore_full_stamina()


func apply_normal_gravity(delta: float) -> void:
	if state == State.DASH:
		if dash_stops_fall:
			return
		velocity.y += gravity * dash_fall_factor * delta
		return

	match form:
		Form.BUBBLE:
			velocity.y += 50 * delta
		Form.SUPER:
			velocity.y += gravity * 1.5 * delta
		_:
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


func enter_water_zone(_water: Node = null) -> void:
	water_zone_overlap_count += 1
	if water_zone_overlap_count > 1:
		return

	in_water = true
	if state != State.DEAD:
		change_state(State.SWIM)


func exit_water_zone(_water: Node = null) -> void:
	water_zone_overlap_count = max(water_zone_overlap_count - 1, 0)
	if water_zone_overlap_count > 0:
		return

	in_water = false
	if state == State.DEAD:
		return

	if is_on_floor():
		change_state(State.IDLE)
	else:
		change_state(State.JUMP)


func handle_jump() -> void:
	var water_jump_multiplier := water_up_jump_multiplier if in_water and is_swim_up_pressed() else 1.0

	match form:
		Form.BUBBLE:
			if in_water:
				velocity.y = -100 * water_jump_multiplier
				bubble_jump_count += 1
			elif bubble_jump_count < max_bubble_jumps:
				velocity.y = -50
				bubble_jump_count += 1
		Form.SUPER:
			if in_water:
				velocity.y = -120 * water_jump_multiplier
			elif is_on_floor():
				velocity.y = super_jump_force
		_:
			if in_water:
				velocity.y = -150 * water_jump_multiplier
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
	if state in [State.DEAD, State.HURT]:
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
	if dash_cooldown_timer > 0:
		return false
	return has_stamina(STAMINA_COST_DASH)


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
		State.HURT: hurt_state()


func idle_state() -> void:
	handle_horizontal_input()

	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif abs(get_horizontal_axis()) > 0:
		change_state(State.WALK)
	elif Input.is_action_just_pressed("attack"):
		start_normal_attack()
	elif Input.is_action_pressed("crouch"):
		change_state(State.CROUCH)
	elif Input.is_action_just_pressed("dash") and can_dash():
		if form == Form.SUPER:
			start_super_shield()
		else:
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
		if form == Form.SUPER:
			start_super_shield()
		else:
			change_state(State.DASH)
	elif velocity.x == 0:
		change_state(State.IDLE)


func jump_state() -> void:
	handle_horizontal_input()

	if Input.is_action_just_pressed("dash") and can_dash():
		if form == Form.SUPER:
			start_super_shield()
		else:
			change_state(State.DASH)

	if is_on_floor():
		change_state(State.IDLE)


func attack_state() -> void:
	velocity.x = 0.0


func crouch_state() -> void:
	velocity.x = 0
	if not Input.is_action_pressed("crouch"):
		change_state(State.IDLE)


func dash_state() -> void:
	if dash_timer <= 0.0:
		if not consume_stamina(STAMINA_COST_DASH):
			return

		dash_timer = dash_time
		dash_cooldown_timer = dash_cooldown

		var dir: int = int(sign(get_horizontal_axis()))
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
	velocity = Vector2.ZERO


func hurt_state() -> void:
	velocity = Vector2.ZERO


func swim_state() -> void:
	var dir_x := get_horizontal_axis()
	var dir_y := get_vertical_swim_axis()

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
	var dir := get_horizontal_axis()
	var current_speed := speed

	if form == Form.SUPER:
		current_speed *= 0.7

	if in_water:
		match form:
			Form.NORMAL:
				current_speed *= 0.6
			Form.BUBBLE:
				current_speed *= 0.9
			Form.SUPER:
				current_speed *= 0.5

	if is_passive_run_boosting():
		current_speed *= quick_run_speed_multiplier

	velocity.x = dir * current_speed

	if dir != 0:
		$Sprite2D.flip_h = dir < 0
		_update_shield_direction()


func get_horizontal_axis() -> float:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir == 0.0:
		dir = Input.get_axis("left", "right")
	return dir


func get_vertical_swim_axis() -> float:
	var dir := Input.get_axis("ui_up", "ui_down")
	if dir == 0.0:
		dir = Input.get_axis("swim_up", "crouch")
	return dir


func is_swim_up_pressed() -> bool:
	return Input.is_action_pressed("ui_up") or Input.is_action_pressed("swim_up")


func change_state(new_state: State) -> void:
	state = new_state


func start_normal_attack() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.DEAD, State.TRANSFORM, State.HURT]:
		return
	if not has_stamina(STAMINA_COST_ATTACK):
		show_stamina_warning()
		return

	defending = false
	consume_stamina(STAMINA_COST_ATTACK * (SUPER_STAMINA_MULTIPLIER if form == Form.SUPER else 1.0))
	prepare_attack_area(attack_area, normal_attack_damage, AttackKind.NORMAL, normal_attack_id)
	change_state(State.ATTACK)
	trigger_attack_window(normal_attack_active_time)


func take_damage(amount: int = 1, source: Node = null) -> void:
	if is_invincible or state in [State.DEAD, State.HURT]:
		return
	if super_parry_active and state == State.DEFEND:
		_resolve_super_parry(source)
		return
	if defending and state == State.DEFEND:
		if not consume_stamina(STAMINA_COST_DEFEND_HIT):
			defending = false
			change_state(State.IDLE)
		return

	var is_fatal_hit := false

	if stats and stats.has_method("take_damage"):
		stats.take_damage(amount)
		if stats.current_health <= 0:
			is_fatal_hit = true
	else:
		is_fatal_hit = true

	if is_fatal_hit:
		_on_fatal_hit()
		return

	start_invincibility()
	play_hurt_reaction()


func _resolve_super_parry(source: Node) -> void:
	super_parry_active = false
	super_parry_serial += 1
	defending = false
	var enemy := _resolve_enemy(source)
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(super_parry_damage)
	if source and source.is_in_group("boss_projectile"):
		source.queue_free()
	if state == State.DEFEND:
		change_state(State.IDLE if is_on_floor() else State.JUMP)


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
	if fatal_hit_sequence_running or state == State.DEAD:
		return

	await play_fatal_hit_sequence()


func respawn_player() -> void:
	var body_collision_states: Dictionary = {}
	if release_enemy_contacts_on_respawn:
		body_collision_states = set_player_body_collisions_disabled(true)
		await wait_physics_frames(respawn_collision_release_frames)

	global_position = respawn_position
	velocity = Vector2.ZERO
	change_state(State.IDLE)

	if release_enemy_contacts_on_respawn:
		await wait_physics_frames(1)
		restore_player_body_collision_states(body_collision_states)

	if stats and stats.has_method("restore_all"):
		stats.restore_all()
	else:
		if stats and stats.has_method("reset_health_full"):
			stats.reset_health_full()
		if stats and stats.has_method("reset_mana_full"):
			stats.reset_mana_full()

	update_audio_by_form()

	is_invincible = true
	var tree := get_tree()
	if tree:
		var timer := tree.create_timer(invincibility_time)
		if timer:
			await timer.timeout
	is_invincible = false
	fatal_hit_sequence_running = false


func wait_physics_frames(frame_count: int) -> void:
	var tree := get_tree()
	if tree == null:
		return

	for _i in range(maxi(frame_count, 0)):
		await tree.physics_frame


func set_player_body_collisions_disabled(disabled: bool) -> Dictionary:
	var previous_states: Dictionary = {}

	for shape in get_player_body_collision_shapes():
		previous_states[shape] = shape.disabled
		shape.disabled = disabled

	return previous_states


func restore_player_body_collision_states(previous_states: Dictionary) -> void:
	for shape in previous_states.keys():
		if is_instance_valid(shape):
			(shape as CollisionShape2D).disabled = previous_states[shape]


func get_player_body_collision_shapes() -> Array[CollisionShape2D]:
	var shapes: Array[CollisionShape2D] = []

	for child in get_children():
		if child is CollisionShape2D and child.is_in_group("player"):
			shapes.append(child)

	return shapes


func open_hud_menu() -> void:
	if state in [State.DEAD, State.HURT, State.ATTACK, State.SPECIAL_ATTACK, State.DEFEND, State.TRANSFORM]:
		return

	hud_menu_open = true
	hud_menu_selection = HudMenuAction.NONE
	hud_menu_axis_locked = false
	hud_menu_selection_locked = false
	hud_menu_waiting_for_neutral = get_raw_hud_menu_direction() != Vector2.ZERO
	velocity.x = 0.0

	if hud and hud.has_method("show_menu"):
		hud.show_menu()

	if hud and hud.has_method("update_action_selection"):
		hud.update_action_selection("none")


func close_hud_menu(keep_panel_active: bool = false) -> void:
	if not hud_menu_open:
		if not keep_panel_active and hud and hud.has_method("hide_menu"):
			hud.hide_menu()
		return

	hud_menu_open = false
	hud_menu_selection = HudMenuAction.NONE
	hud_menu_axis_locked = false
	hud_menu_selection_locked = false
	hud_menu_waiting_for_neutral = false

	if not keep_panel_active and hud and hud.has_method("hide_menu"):
		hud.hide_menu()


func process_hud_menu_selection() -> void:
	var direction := get_hud_menu_direction()

	if direction == Vector2.ZERO:
		hud_menu_axis_locked = false
		hud_menu_selection_locked = false
		hud_menu_selection = HudMenuAction.NONE
		if hud and hud.has_method("update_action_selection"):
			hud.update_action_selection("none")
		return

	if hud_menu_selection_locked:
		return

	if hud_menu_axis_locked:
		return

	hud_menu_axis_locked = true
	hud_menu_selection_locked = true

	if abs(direction.x) > abs(direction.y):
		if direction.x > 0.0:
			select_hud_menu_action(HudMenuAction.SPECIAL_ATTACK)
		else:
			select_hud_menu_action(HudMenuAction.BUBBLE_PROJECTILE)
	else:
		if direction.y < 0.0:
			select_hud_menu_action(HudMenuAction.ULTIMATE)
		else:
			select_hud_menu_action(HudMenuAction.PLACEHOLDER)


func get_hud_menu_direction() -> Vector2:
	var direction := get_raw_hud_menu_direction()
	if hud_menu_waiting_for_neutral:
		if direction == Vector2.ZERO:
			hud_menu_waiting_for_neutral = false
		return Vector2.ZERO

	return direction


func get_raw_hud_menu_direction() -> Vector2:
	var keyboard_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down", 0.35)
	if keyboard_direction != Vector2.ZERO:
		return keyboard_direction

	if Input.is_action_pressed("hud_select_left"):
		keyboard_direction.x -= 1.0
	if Input.is_action_pressed("hud_select_right"):
		keyboard_direction.x += 1.0
	if Input.is_action_pressed("hud_select_up"):
		keyboard_direction.y -= 1.0
	if Input.is_action_pressed("hud_select_down"):
		keyboard_direction.y += 1.0

	if Input.is_action_pressed("left"):
		keyboard_direction.x -= 1.0
	if Input.is_action_pressed("right"):
		keyboard_direction.x += 1.0
	if Input.is_action_pressed("jump"):
		keyboard_direction.y -= 1.0
	if Input.is_action_pressed("crouch"):
		keyboard_direction.y += 1.0

	return keyboard_direction.normalized() if keyboard_direction != Vector2.ZERO else Vector2.ZERO


func setup_camera_framing() -> void:
	if not player_camera:
		return

	player_camera.position_smoothing_enabled = true
	player_camera.position_smoothing_speed = camera_position_smoothing_speed
	player_camera.drag_horizontal_enabled = true
	player_camera.drag_vertical_enabled = true
	player_camera.drag_left_margin = camera_drag_left_margin
	player_camera.drag_right_margin = camera_drag_right_margin
	player_camera.drag_top_margin = camera_drag_top_margin
	player_camera.drag_bottom_margin = camera_drag_bottom_margin
	player_camera.offset = Vector2(get_camera_lookahead_direction() * camera_lookahead_distance, camera_vertical_offset)


func update_camera_framing(delta: float) -> void:
	if not player_camera:
		return

	if camera_follow_target and is_instance_valid(camera_follow_target):
		camera_follow_timer -= delta
		player_camera.global_position = camera_follow_target.global_position
		if camera_follow_timer <= 0.0 or not is_instance_valid(camera_follow_target):
			_stop_camera_follow()
		return

	var vertical_offset := camera_vertical_offset
	if is_on_floor() and (state == State.CROUCH or is_down_pressed()):
		vertical_offset += camera_crouch_offset

	var target_offset := Vector2(get_camera_lookahead_direction() * camera_lookahead_distance, vertical_offset)
	var weight := clampf(delta * camera_offset_smoothing, 0.0, 1.0)
	player_camera.offset = player_camera.offset.lerp(target_offset, weight)


func get_camera_lookahead_direction() -> float:
	var dir := get_horizontal_axis()
	if absf(dir) > 0.1:
		return -1.0 if dir < 0.0 else 1.0
	if has_node("Sprite2D") and $Sprite2D.flip_h:
		return -1.0
	return 1.0


func _start_camera_follow(target: Node2D, duration: float) -> void:
	camera_follow_target = target
	camera_follow_timer = duration


func _stop_camera_follow() -> void:
	camera_follow_target = null
	camera_follow_timer = 0.0
	if is_instance_valid(player_camera):
		player_camera.position = Vector2.ZERO


func action_to_wheel_slot(action: HudMenuAction) -> WheelSlot:
	match action:
		HudMenuAction.ULTIMATE:
			return WheelSlot.ULTIMATE
		HudMenuAction.SPECIAL_ATTACK:
			return WheelSlot.SPECIAL_ATTACK
		HudMenuAction.BUBBLE_PROJECTILE:
			return WheelSlot.BUBBLE_PROJECTILE
		HudMenuAction.PLACEHOLDER:
			return WheelSlot.PLACEHOLDER
		_:
			return WheelSlot.ULTIMATE

func select_hud_menu_action(action: HudMenuAction) -> void:
	if hud_menu_selection == action:
		return

	var slot := action_to_wheel_slot(action)
	if not is_wheel_slot_unlocked(slot):
		return

	hud_menu_selection = action

	var action_name := get_hud_action_name(action)
	if hud and hud.has_method("update_action_selection"):
		hud.update_action_selection(action_name)
	execute_hud_menu_action(action_name)


func get_hud_action_name(action: HudMenuAction) -> String:
	var base_name := ""
	match action:
		HudMenuAction.ULTIMATE:
			base_name = "ultimate_attack"
		HudMenuAction.PLACEHOLDER:
			base_name = "placeholder"
		HudMenuAction.SPECIAL_ATTACK:
			base_name = "attack_special"
		HudMenuAction.BUBBLE_PROJECTILE:
			base_name = "bubble_projectile"
	if form == Form.NORMAL:
		match action:
			HudMenuAction.ULTIMATE:
				base_name = "protective_bubble"
			HudMenuAction.PLACEHOLDER:
				base_name = "ghost_mode"
			HudMenuAction.SPECIAL_ATTACK:
				base_name = "portal"
			HudMenuAction.BUBBLE_PROJECTILE:
				base_name = "teleport_bubble"
	elif form == Form.SUPER:
		match action:
			HudMenuAction.ULTIMATE:
				base_name = "super_spike"
			HudMenuAction.PLACEHOLDER:
				base_name = "super_parry"
			HudMenuAction.SPECIAL_ATTACK:
				base_name = "time_bubble"
			HudMenuAction.BUBBLE_PROJECTILE:
				base_name = "super_launcher"
	return base_name


func execute_hud_menu_action(action_name: String) -> void:
	if form == Form.NORMAL:
		match action_name:
			"protective_bubble":
				start_protective_bubble()
			"ghost_mode":
				start_ghost_mode()
			"portal":
				fire_portal_bubble()
			"teleport_bubble":
				start_teleport_bubble()
		_await_hud_release()
		return
	if form == Form.SUPER:
		match action_name:
			"super_spike":
				start_super_spike()
			"super_launcher":
				start_super_launcher()
			"time_bubble":
				start_time_bubble()
			"super_parry":
				start_super_parry()
		_await_hud_release()
		return

	match action_name:
		"ultimate_attack":
			start_ultimate_attack()
		"placeholder":
			pass
		"attack_special":
			start_special_attack()
		"bubble_projectile":
			start_bubble_projectile()

	_await_hud_release()


func _await_hud_release() -> void:
	await get_tree().create_timer(0.45).timeout
	if hud_menu_open and get_hud_menu_direction() == Vector2.ZERO:
		hud_menu_axis_locked = false
		hud_menu_selection_locked = false
		hud_menu_selection = HudMenuAction.NONE
		if hud and hud.has_method("update_action_selection"):
			hud.update_action_selection("none")


func activate_attack_area() -> void:
	set_area_collision_enabled(current_attack_area if current_attack_area != null else attack_area, true)


func deactivate_attack_area() -> void:
	attack_window_serial += 1
	set_area_collision_enabled(current_attack_area if current_attack_area != null else attack_area, false)
	clear_attack_area_metadata(current_attack_area if current_attack_area != null else attack_area)
	current_attack_kind = AttackKind.NONE
	current_attack_id = &""
	current_attack_damage = 0
	current_attack_area = null


func _on_attack_finished() -> void:
	deactivate_attack_area()

	if super_shield_active:
		if not Input.is_action_pressed("dash"):
			super_shield_active = false
			defending = false
			if shield_area:
				shield_area.monitoring = false
				shield_area.monitorable = false
			if state not in [State.DEAD, State.HURT]:
				change_state(State.IDLE)
		return

	defending = false
	super_shield_active = false
	special_attack_animation_override = &""

	if state not in [State.DEAD, State.HURT]:
		change_state(State.IDLE)


func _on_shield_body_entered(body: Node) -> void:
	if not super_shield_active:
		return
	_push_enemy_away(body)


func _on_shield_area_entered(area: Area2D) -> void:
	if not super_shield_active:
		return
	_push_enemy_away(area)


func _push_enemy_away(node: Node) -> void:
	var enemy := _resolve_enemy(node)
	if not enemy:
		return

	var dir: Vector2 = (enemy.global_position - global_position).normalized()
	dir.y = maxf(dir.y, 0.0)

	enemy.global_position += dir * 8.0

	if "velocity" in enemy:
		enemy.velocity = dir * 2000.0


func _update_shield_direction() -> void:
	if not shield_area:
		return
	var shape = shield_area.get_node_or_null("ShieldCollisionShape")
	if not shape:
		return
	shape.position.x = absf(shape.position.x) * (-1 if $Sprite2D.flip_h else 1)


func _resolve_enemy(node: Node) -> Node:
	var current := node
	while current != null:
		if current.is_in_group("slime") or current.is_in_group("boss") or current.is_in_group("enemy"):
			return current
		current = current.get_parent()
	return null


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


func trigger_attack_window(duration: float) -> void:
	var target_area := current_attack_area if current_attack_area != null else attack_area
	if target_area == null:
		return

	attack_window_serial += 1
	var serial := attack_window_serial
	activate_attack_area()
	_close_attack_window(serial, maxf(duration, 0.05))


func _close_attack_window(serial: int, duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if serial != attack_window_serial:
		return
	deactivate_attack_area()


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


func get_active_attack_cooldown_progress(index: int = -1) -> float:
	if index < 0:
		index = selected_active_attack_index
	if index < 0 or index >= active_attack_timers.size():
		return 1.0

	var cooldown := maxf(get_active_attack_cooldown(index), 0.001)
	return clampf(1.0 - (active_attack_timers[index] / cooldown), 0.0, 1.0)


func get_bubble_projectile_cooldown_progress() -> float:
	var cooldown := maxf(bubble_projectile_cooldown, 0.001)
	return clampf(1.0 - (bubble_projectile_cooldown_timer / cooldown), 0.0, 1.0)


func get_super_wheel_cooldown_progress(slot: WheelSlot) -> float:
	match slot:
		WheelSlot.ULTIMATE:
			return _cooldown_progress(super_spike_cooldown_timer, super_spike_cooldown)
		WheelSlot.SPECIAL_ATTACK:
			return _cooldown_progress(time_bubble_cooldown_timer, time_bubble_cooldown)
		WheelSlot.BUBBLE_PROJECTILE:
			return _cooldown_progress(super_launcher_cooldown_timer, super_launcher_cooldown)
		WheelSlot.PLACEHOLDER:
			return _cooldown_progress(super_parry_cooldown_timer, super_parry_cooldown)
	return 1.0


func _cooldown_progress(time_left: float, duration: float) -> float:
	return clampf(1.0 - (time_left / maxf(duration, 0.001)), 0.0, 1.0)


func get_ultimate_cooldown_progress() -> float:
	var cooldown := maxf(ultimate_attack_cooldown, 0.001)
	if ultimate_cooldown_node and not ultimate_cooldown_node.is_stopped():
		return clampf(1.0 - (ultimate_cooldown_node.time_left / maxf(ultimate_cooldown_node.wait_time, 0.001)), 0.0, 1.0)
	return clampf(1.0 - (ultimate_cooldown_timer / cooldown), 0.0, 1.0)


func get_ultimate_hud_progress() -> float:
	if not allow_ultimate_input or not ultimate_attack_enabled or not can_use_mana_attacks():
		return 0.0
	return get_ultimate_cooldown_progress()


func get_mana_ratio() -> float:
	if not stats:
		return 1.0
	if not "current_mana" in stats or not "max_mana" in stats:
		return 1.0

	var max_mana_value: float = maxf(float(stats.max_mana), 0.001)
	return clampf(float(stats.current_mana) / max_mana_value, 0.0, 1.0)


func can_use_ultimate_attack() -> bool:
	if not can_attempt_ultimate_attack():
		return false
	return has_full_mana_for_ultimate()


func can_attempt_ultimate_attack() -> bool:
	if not allow_ultimate_input:
		return false
	if not ultimate_attack_enabled:
		return false
	if not can_use_mana_attacks():
		return false
	if ultimate_cooldown_timer > 0.0:
		return false
	return true


func has_full_mana_for_ultimate() -> bool:
	return get_mana_ratio() >= 1.0


func get_active_attack_mana_cost(index: int) -> float:
	return active_attack_mana_costs[index]


func get_active_attack_damage(index: int) -> int:
	return active_attack_damages[index]


func get_active_attack_area(index: int) -> Area2D:
	return get_area_from_path(active_attack_area_paths[index])


func get_active_attack_active_time(index: int) -> float:
	return active_attack_active_times[index]


func can_trigger_active_attack(index: int) -> bool:
	if index < 0 or index >= active_attack_names.size():
		return false
	return active_attack_timers[index] <= 0.0


func has_stamina(amount: float = 1.0) -> bool:
	if not stats or not stats.has_method("consume_stamina"):
		return true
	return stats.current_stamina >= amount


func consume_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not stats or not stats.has_method("consume_stamina"):
		return true
	var consumed: bool = stats.consume_stamina(amount)
	if not consumed:
		show_stamina_warning()
	return consumed


func show_stamina_warning() -> void:
	if hud and hud.has_method("show_warning_message"):
		hud.show_warning_message("baixa estamina")


func consume_attack_mana(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not can_use_mana_system():
		return true
	if not stats or not stats.has_method("consume_mana"):
		return true
	var consumed: bool = stats.consume_mana(amount)
	if not consumed:
		show_mana_warning()
	return consumed


func consume_ultimate_mana() -> bool:
	if not can_use_mana_system():
		return true
	if not stats:
		return true
	if stats.has_method("consume_all_mana"):
		return stats.consume_all_mana()
	return false


func show_mana_warning() -> void:
	if hud and hud.has_method("show_mana_warning"):
		hud.show_mana_warning("sem mana suficiente")


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
	if fatal_hit_sequence_running or state == State.DEAD:
		return
	await play_death_sequence()


func handle_level_timeout() -> void:
	if fatal_hit_sequence_running or state == State.DEAD:
		return

	await play_fatal_hit_sequence()


func play_hurt_reaction() -> void:
	if hurt_sequence_running or fatal_hit_sequence_running or state == State.DEAD:
		return

	hurt_sequence_running = true
	defending = false
	deactivate_attack_area()
	velocity = Vector2.ZERO
	change_state(State.HURT)
	await wait_for_current_sprite_animation(hurt_animation_name)

	if is_inside_tree() and state == State.HURT:
		change_state(State.IDLE)

	hurt_sequence_running = false


func play_fatal_hit_sequence() -> void:
	fatal_hit_sequence_running = true
	hurt_sequence_running = false
	is_invincible = true
	defending = false
	deactivate_attack_area()
	velocity = Vector2.ZERO
	change_state(State.HURT)
	await wait_for_current_sprite_animation(hurt_animation_name)

	if not is_inside_tree():
		return

	await play_death_sequence()


func play_death_sequence() -> void:
	if not is_inside_tree():
		return

	change_state(State.DEAD)
	velocity = Vector2.ZERO
	deactivate_attack_area()

	if audio_normal:
		audio_normal.stop()
	if audio_super:
		audio_super.stop()

	await wait_for_current_sprite_animation(get_death_animation_name(), death_delay)

	if not is_inside_tree():
		return

	await respawn_player()


func wait_for_current_sprite_animation(anim_name: StringName, minimum_duration: float = 0.0) -> void:
	var wait_duration := maxf(get_sprite_animation_duration(anim_name), minimum_duration)
	if wait_duration <= 0.0:
		return
	await get_tree().create_timer(wait_duration).timeout


func get_sprite_animation_duration(anim_name: StringName) -> float:
	if not has_node("Sprite2D"):
		return 0.0

	var sprite := $Sprite2D as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return 0.0
	if not sprite.sprite_frames.has_animation(anim_name):
		return 0.0

	var frame_count: int = sprite.sprite_frames.get_frame_count(anim_name)
	var speed: float = maxf(sprite.sprite_frames.get_animation_speed(anim_name), 1.0)
	return maxf(float(frame_count) / speed, 0.0)


func get_death_animation_name() -> StringName:
	match form:
		Form.BUBBLE:
			return &"death_bubble"
		Form.SUPER:
			return &"death_super"
		_:
			return &"death"


func restart_level_from_beginning() -> void:
	await respawn_player()


func connect_stomper_signals(stomper: Area2D) -> void:
	if not stomper:
		return

	stomper.set_meta(ATTACK_META_DAMAGE, max(stomp_damage, 1))
	stomper.set_meta(ATTACK_META_KIND, int(AttackKind.PASSIVE))
	stomper.set_meta(ATTACK_META_ID, "stomp")

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

	stomper.set_meta(ATTACK_META_DAMAGE, max(stomp_damage, 1))
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


func resolve_stomp_target(node: Node) -> Node:
	var current: Node = node

	while current != null:
		# ✅ só aceita stompable
		if current.is_in_group("stompable"):
			return current.get_parent() # retorna o inimigo (slime/boss)

		current = current.get_parent()

	return null


func _on_hurtbox_body_entered(body: Node) -> void:
	if is_invincible:
		return

	if body.has_method("deal_damage_to_player"):
		body.deal_damage_to_player(self)
		return
