extends CharacterBody2D

const ATTACK_META_DAMAGE := &"attack_damage"

enum MoveMode { WALK, JUMP, FLY, SWIM }
enum AttackMode { CONTACT, HITBOX }
enum FlyMode { X_ONLY, DIRECT, ZIGZAG }

@export_group("Target")
@export var player_group: StringName = "jogador"
@export var player_hurtbox_group: StringName = "player_hurtbox"

@export_group("Movement")
@export var move_mode: MoveMode = MoveMode.JUMP
@export var speed: float = 70.0
@export var gravity: float = 900.0
@export var jump_force: float = -260.0
@export var jump_interval: float = 0.35
@export var fly_mode: FlyMode = FlyMode.X_ONLY
@export var fly_y_speed: float = 70.0
@export var fly_vertical_follow: bool = true
@export var fly_zigzag_amplitude: float = 70.0
@export var fly_zigzag_frequency: float = 5.0

@export_group("Swim Movement")
@export var swim_impulse_interval: float = 0.75
@export var swim_impulse_interval_variance: float = 0.18
@export var swim_impulse_strength: float = 120.0
@export var swim_vertical_impulse_strength: float = 80.0
@export var swim_drag: float = 5.0
@export var swim_zigzag_frequency: float = 5.0
@export var swim_zigzag_vertical_bias: float = 0.65
@export var swim_vertical_follow_strength: float = 0.55
@export var swim_flop_to_water_enabled: bool = true
@export var swim_flop_interval: float = 0.55
@export var swim_flop_horizontal_strength: float = 85.0
@export var swim_flop_vertical_strength: float = 150.0
@export var swim_out_of_water_gravity_multiplier: float = 1.0

@export_group("Water")
@export_range(0.05, 1.0, 0.05) var water_speed_multiplier: float = 0.55
@export_range(0.05, 1.0, 0.05) var water_gravity_multiplier: float = 0.35
@export_range(0.05, 1.0, 0.05) var water_jump_multiplier: float = 0.65

@export_group("AI")
@export var aggro_range: float = 260.0
@export var stop_distance: float = 40.0
@export var turn_horizontal_threshold: float = 24.0
@export var avoid_other_slimes: bool = true
@export var separation_distance: float = 20.0
@export var separation_strength: float = 45.0

@export_group("Player Separation")
@export var prevent_player_platform_carry: bool = true
@export_range(0.0, 400.0, 1.0) var head_slide_force: float = 180.0
@export_range(0.0, 300.0, 1.0) var head_slide_min_player_speed: float = 20.0

@export_group("Attack")
@export var attack_mode: AttackMode = AttackMode.HITBOX
@export var damage: int = 1
@export var attack_range: float = 24.0
@export var attack_vertical_range: float = 42.0
@export var hitbox_active_time: float = 0.10
@export var attack_cooldown: float = 0.85
@export_range(0.0, 5.0, 0.05) var hit_reaction_time: float = 1.0
@export var contact_attack_requires_fall: bool = false
@export var contact_attack_min_speed_y: float = 10.0
@export_range(-1, 99, 1) var attack_hitbox_start_frame: int = -1
@export_range(-1, 99, 1) var attack_hitbox_end_frame: int = -1

@export_group("Coin Drop")
@export var coin_scene: PackedScene = preload("res://Cenas/coin.tscn")
@export var coin_count: int = 5
@export var coin_spread: float = 24.0
@export_range(0.0, 1.0) var coin_drop_chance: float = 1.0

@export_group("Health")
@export var max_health: int = 3
var health: int = max_health

@export_group("Health Bar")
@export var health_bar_enabled: bool = true
@export var health_bar_width: float = 24.0
@export var health_bar_height: float = 3.0
@export var health_bar_offset: Vector2 = Vector2(0, -24.0)
@export var health_bar_show_range: float = 160.0
@export var health_bar_bg_color: Color = Color(0.15, 0.15, 0.15, 0.85)
@export var health_bar_fg_color: Color = Color(0.9, 0.15, 0.1, 0.95)
@export var health_bar_mid_color: Color = Color(0.9, 0.7, 0.1, 0.95)
@export var health_bar_high_color: Color = Color(0.2, 0.85, 0.15, 0.95)

@export_group("Nodes")
@export var sprite_path: NodePath = NodePath("AnimatedSprite2D")
@export var hitbox_path: NodePath = NodePath("AttackHitbox")
@export var attack_receiver_path: NodePath = NodePath("AttackReceiver")
@export var hurtbox_path: NodePath = NodePath("Hurtbox")

@export var sprite_faces_left_by_default: bool = true
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var attack_animation: StringName = &"attack"
@export var got_hit_animation: StringName = &"got_hit"
@export var death_animation: StringName = &"death"

@onready var sprite: AnimatedSprite2D = get_node_or_null(sprite_path)
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)
@onready var hitbox_shape: CollisionShape2D = hitbox.get_node_or_null("CollisionShape2D") if hitbox else null
@onready var attack_receiver: Area2D = get_node_or_null(attack_receiver_path)
@onready var hurtbox: Area2D = get_node_or_null(hurtbox_path)
@onready var health_bar_bg: ColorRect
@onready var health_bar_fill: ColorRect

var player: Node2D
var cooldown_t: float = 0.0
var jump_t: float = 0.0
var attacking: bool = false
var stunned: bool = false
var dying: bool = false
var hit_reaction_active: bool = false
var hit_reaction_serial: int = 0
var attack_serial: int = 0
var facing_dir: int = -1
var attack_hitbox_base_position: Vector2 = Vector2.ZERO
var fly_time: float = 0.0
var swim_impulse_t: float = 0.0
var swim_flop_t: float = 0.0
var in_water: bool = false
var water_zone_overlap_count: int = 0
var last_water_position: Vector2 = Vector2.ZERO
var has_last_water_position: bool = false
var time_frozen: bool = false
var time_frozen_velocity: Vector2 = Vector2.ZERO
var time_frozen_sprite_was_playing: bool = false


func _ready():
	if not is_in_group("slime"):
		add_to_group("slime")

	if prevent_player_platform_carry:
		platform_floor_layers = 0

	player = get_tree().get_first_node_in_group(player_group)

	if hitbox_shape:
		attack_hitbox_base_position = hitbox_shape.position
		hitbox_shape.disabled = true

	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	if attack_receiver and not attack_receiver.area_entered.is_connected(_on_attack_receiver_area_entered):
		attack_receiver.area_entered.connect(_on_attack_receiver_area_entered)

	if hurtbox and not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	create_health_bar()
	update_health_bar()

	update_sprite_direction(facing_dir)
	play_idle_animation()


func _physics_process(delta):
	if dying:
		return
	if time_frozen:
		velocity = Vector2.ZERO
		return

	if cooldown_t > 0:
		cooldown_t -= delta
	if jump_t > 0:
		jump_t -= delta
	if swim_impulse_t > 0:
		swim_impulse_t -= delta
	if swim_flop_t > 0:
		swim_flop_t -= delta
	fly_time += delta

	if move_mode == MoveMode.SWIM:
		if in_water:
			apply_swim_drag(delta)
		else:
			process_swim_out_of_water(delta)
	elif move_mode != MoveMode.FLY and not is_on_floor():
		velocity.y += gravity * get_water_gravity_multiplier() * delta
	elif move_mode == MoveMode.FLY:
		velocity.y = 0

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(player_group)

	if not is_instance_valid(player):
		velocity.x = 0
		move_and_slide()
		return

	var dist = global_position.distance_to(player.global_position)

	if dist > aggro_range:
		velocity.x = 0
		move_and_slide()
		return

	if attack_mode == AttackMode.HITBOX and not stunned and not attacking and cooldown_t <= 0 and is_player_in_hitbox_attack_range():
		start_attack()
		return

	if attacking:
		velocity.x = 0
		if move_mode == MoveMode.FLY:
			velocity.y = 0
		move_and_slide()
		update_animation()
		return

	separate_from_player()
	move_towards_player(dist)
	separate_from_player()
	move_and_slide()
	process_contact_attack()
	update_animation()
	update_health_bar_visibility()


func move_towards_player(dist):
	if dist <= stop_distance:
		velocity.x = 0
		if move_mode == MoveMode.FLY:
			velocity.y = 0
		return

	var dir: int = get_horizontal_chase_direction()
	if dir == 0 and move_mode != MoveMode.FLY:
		velocity.x = 0
		return

	if dir != 0:
		facing_dir = dir
		update_sprite_direction(dir)

	match move_mode:
		MoveMode.WALK:
			velocity.x = dir * get_water_speed()
		MoveMode.JUMP:
			velocity.x = dir * get_water_speed()
			if is_on_floor():
				velocity.y = jump_force * get_water_jump_multiplier()
		MoveMode.FLY:
			move_flying_towards_player(dir)
		MoveMode.SWIM:
			move_swimming_towards_player(dir)


func move_flying_towards_player(dir: int) -> void:
	var to_player := player.global_position - global_position

	match fly_mode:
		FlyMode.X_ONLY:
			velocity.x = dir * get_water_speed()
			velocity.y = 0
		FlyMode.DIRECT:
			velocity.x = sign(to_player.x) * get_water_speed() if absf(to_player.x) > stop_distance else 0.0
			velocity.y = sign(to_player.y) * get_water_fly_y_speed() if fly_vertical_follow and absf(to_player.y) > stop_distance else 0.0
		FlyMode.ZIGZAG:
			var horizontal_dir := dir
			if horizontal_dir == 0:
				horizontal_dir = facing_dir

			velocity.x = horizontal_dir * get_water_speed()
			velocity.y = sin(fly_time * fly_zigzag_frequency) * fly_zigzag_amplitude * get_water_speed_multiplier()


func move_swimming_towards_player(dir: int) -> void:
	if not in_water:
		return
	if swim_impulse_t > 0:
		return

	var to_player := player.global_position - global_position
	var horizontal_dir := dir
	if horizontal_dir == 0:
		horizontal_dir = facing_dir

	var vertical_dir: float = sign(to_player.y) * swim_vertical_follow_strength
	var zigzag_dir: float = sin(fly_time * swim_zigzag_frequency)
	var final_vertical_dir: float = clampf(vertical_dir + zigzag_dir * swim_zigzag_vertical_bias, -1.0, 1.0)

	velocity.x = horizontal_dir * swim_impulse_strength * get_water_speed_multiplier()
	velocity.y = final_vertical_dir * swim_vertical_impulse_strength * get_water_speed_multiplier()

	var interval_variance: float = randf_range(-swim_impulse_interval_variance, swim_impulse_interval_variance)
	swim_impulse_t = maxf(swim_impulse_interval + interval_variance, 0.1)


func apply_swim_drag(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, swim_drag * 100.0 * delta)


func process_swim_out_of_water(delta: float) -> void:
	velocity.y += gravity * swim_out_of_water_gravity_multiplier * delta

	if not swim_flop_to_water_enabled:
		return

	if swim_flop_t > 0:
		return

	var horizontal_dir := facing_dir
	if has_last_water_position:
		var delta_to_water: float = last_water_position.x - global_position.x
		if absf(delta_to_water) > turn_horizontal_threshold:
			horizontal_dir = int(sign(delta_to_water))
	elif is_instance_valid(player):
		var delta_to_player: float = player.global_position.x - global_position.x
		if absf(delta_to_player) > turn_horizontal_threshold:
			horizontal_dir = int(sign(delta_to_player))

	if horizontal_dir != 0:
		facing_dir = horizontal_dir
		update_sprite_direction(horizontal_dir)
		velocity.x = horizontal_dir * swim_flop_horizontal_strength

	if is_on_floor():
		velocity.y = -swim_flop_vertical_strength

	swim_flop_t = swim_flop_interval


func enter_water_zone(water: Node = null) -> void:
	water_zone_overlap_count += 1
	in_water = true
	if water is Node2D:
		last_water_position = water.global_position
		has_last_water_position = true
	swim_flop_t = 0.0


func exit_water_zone(water: Node = null) -> void:
	water_zone_overlap_count = max(water_zone_overlap_count - 1, 0)
	in_water = water_zone_overlap_count > 0
	if water is Node2D:
		last_water_position = water.global_position
		has_last_water_position = true


func get_water_speed_multiplier() -> float:
	return water_speed_multiplier if in_water else 1.0


func get_water_gravity_multiplier() -> float:
	return water_gravity_multiplier if in_water else 1.0


func get_water_jump_multiplier() -> float:
	return water_jump_multiplier if in_water else 1.0


func get_water_speed() -> float:
	return speed * get_water_speed_multiplier()


func get_water_fly_y_speed() -> float:
	return fly_y_speed * get_water_speed_multiplier()


func get_horizontal_chase_direction() -> int:
	if not is_instance_valid(player):
		return 0

	var horizontal_delta: float = player.global_position.x - global_position.x
	if absf(horizontal_delta) < turn_horizontal_threshold:
		return 0

	return int(sign(horizontal_delta))


func is_player_in_hitbox_attack_range() -> bool:
	if not is_instance_valid(player):
		return false

	var to_player := player.global_position - global_position
	if to_player.length() <= attack_range:
		return true

	return absf(to_player.x) <= attack_range and absf(to_player.y) <= attack_vertical_range


# ✅ NOVA FUNÇÃO RESPONSÁVEL POR VIRAR O SPRITE
func update_sprite_direction(dir: int) -> void:
	if not sprite or dir == 0:
		return

	if sprite_faces_left_by_default:
		sprite.flip_h = dir > 0
	else:
		sprite.flip_h = dir < 0

	update_attack_hitbox_direction(dir)
	update_health_bar()


func update_attack_hitbox_direction(dir: int) -> void:
	if not hitbox_shape:
		return

	hitbox_shape.position = Vector2(
		-attack_hitbox_base_position.x if sprite and sprite.flip_h else attack_hitbox_base_position.x,
		attack_hitbox_base_position.y
	)


# ================================
#        HEALTH BAR
# ================================
func create_health_bar() -> void:
	if not health_bar_enabled:
		return

	health_bar_bg = ColorRect.new()
	health_bar_bg.name = "HealthBarBg"
	health_bar_bg.size = Vector2(health_bar_width, health_bar_height)
	health_bar_bg.color = health_bar_bg_color
	health_bar_bg.position = health_bar_offset - Vector2(health_bar_width * 0.5, 0)
	add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.name = "HealthBarFill"
	health_bar_fill.size = Vector2(health_bar_width, health_bar_height)
	health_bar_fill.color = health_bar_fg_color
	health_bar_fill.position = Vector2.ZERO
	health_bar_bg.add_child(health_bar_fill)

	health_bar_bg.visible = false


func update_health_bar() -> void:
	if not health_bar_enabled or not health_bar_bg:
		return

	if max_health <= 0:
		return

	var ratio: float = float(health) / float(max_health)
	ratio = clampf(ratio, 0.0, 1.0)

	health_bar_fill.size.x = health_bar_width * ratio

	if ratio > 0.6:
		health_bar_fill.color = health_bar_high_color
	elif ratio > 0.3:
		health_bar_fill.color = health_bar_mid_color
	else:
		health_bar_fill.color = health_bar_fg_color

	if sprite and sprite.flip_h:
		health_bar_bg.position.x = -health_bar_offset.x - health_bar_width * 0.5
		health_bar_fill.position.x = health_bar_width * (1.0 - ratio)
		health_bar_fill.size.x = health_bar_width * ratio
	else:
		health_bar_bg.position.x = -health_bar_width * 0.5
		health_bar_fill.position.x = 0.0
		health_bar_fill.size.x = health_bar_width * ratio

	health_bar_bg.position.y = health_bar_offset.y


func update_health_bar_visibility() -> void:
	if not health_bar_enabled or not health_bar_bg:
		return

	if dying or health <= 0:
		health_bar_bg.visible = false
		return

	var dist_to_player := INF
	if is_instance_valid(player):
		dist_to_player = global_position.distance_to(player.global_position)

	health_bar_bg.visible = dist_to_player <= health_bar_show_range


func process_contact_attack():
	if dying:
		return

	if attack_mode != AttackMode.CONTACT:
		return

	if cooldown_t > 0 or stunned or attacking:
		return

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision == null:
			continue

		var target := resolve_contact_target(collision.get_collider())
		if target:
			apply_damage_to(target)
			cooldown_t = attack_cooldown
			return


func separate_from_player():
	if not is_instance_valid(player):
		return

	var offset := global_position - player.global_position
	var dist := offset.length()
	if dist > stop_distance * 2.0 or dist < 1.0:
		return

	var push_dir := offset.normalized()
	var separation_dist := stop_distance * 2.0 - dist
	var base_push := separation_dist * 6.0

	if offset.y < 0 and absf(offset.x) < stop_distance:
		base_push = maxf(base_push, 120.0)
		var player_velocity := Vector2.ZERO
		if "velocity" in player:
			player_velocity = player.get("velocity")
		if absf(player_velocity.x) >= head_slide_min_player_speed:
			push_dir = Vector2(-sign(player_velocity.x), -0.2).normalized()
			base_push = maxf(base_push, head_slide_force)

	velocity += push_dir * base_push


func start_attack():
	if attacking or stunned or dying:
		return

	attacking = true
	attack_serial += 1
	var current_attack_serial := attack_serial
	cooldown_t = attack_cooldown
	velocity.x = 0

	play_attack_animation(true)

	if uses_frame_based_hitbox():
		await run_attack_hitbox_by_frames(attack_animation, current_attack_serial)
	else:
		var animation_duration: float = get_animation_duration(attack_animation)
		var hitbox_start_delay: float = get_attack_hitbox_start_delay()

		if hitbox_start_delay > 0:
			await get_tree().create_timer(hitbox_start_delay).timeout
			if not is_current_attack(current_attack_serial):
				return

		if hitbox_shape:
			hitbox_shape.disabled = false

		await get_tree().create_timer(hitbox_active_time).timeout
		if not is_current_attack(current_attack_serial):
			if hitbox_shape:
				hitbox_shape.disabled = true
			return

		if hitbox_shape:
			hitbox_shape.disabled = true

		var remaining_animation_time: float = maxf(animation_duration - hitbox_start_delay - hitbox_active_time, 0.0)
		if remaining_animation_time > 0:
			await get_tree().create_timer(remaining_animation_time).timeout
			if not is_current_attack(current_attack_serial):
				return

	attacking = false
	update_animation()


func is_current_attack(serial: int) -> bool:
	return attacking and not dying and not stunned and serial == attack_serial


func take_damage(amount, _source: Node = null):
	if dying:
		return

	health -= max(amount, 1)
	stunned = true
	update_health_bar()
	attacking = false
	attack_serial += 1
	hit_reaction_serial += 1
	var current_hit_reaction := hit_reaction_serial

	if hitbox_shape:
		hitbox_shape.disabled = true

	if health <= 0:
		die()
		return
	if time_frozen:
		stunned = false
		return

	await play_hit_reaction(current_hit_reaction)

	if dying or current_hit_reaction != hit_reaction_serial:
		return

	stunned = false


func set_time_frozen(frozen: bool) -> void:
	if time_frozen == frozen or dying:
		return
	time_frozen = frozen

	if frozen:
		time_frozen_velocity = velocity
		velocity = Vector2.ZERO
		attacking = false
		attack_serial += 1
		if hitbox_shape:
			hitbox_shape.set_deferred("disabled", true)
		if sprite:
			time_frozen_sprite_was_playing = sprite.is_playing()
			sprite.pause()
	else:
		velocity = time_frozen_velocity
		if sprite and time_frozen_sprite_was_playing:
			sprite.play()


func play_hit_reaction(reaction_serial: int) -> void:
	hit_reaction_active = true

	if has_animation(got_hit_animation):
		play_animation(got_hit_animation)

	var reaction_time := hit_reaction_time
	if has_animation(got_hit_animation):
		reaction_time = maxf(reaction_time, get_animation_duration(got_hit_animation))

	if reaction_time > 0:
		await get_tree().create_timer(reaction_time).timeout

	if reaction_serial == hit_reaction_serial:
		hit_reaction_active = false


func die():
	if dying:
		return

	dying = true

	set_physics_process(false)
	set_collision_layer(0)
	set_collision_mask(0)

	if $CollisionShape2D:
		$CollisionShape2D.set_deferred("disabled", true)

	if hitbox_shape:
		hitbox_shape.set_deferred("disabled", true)

	if hurtbox:
		hurtbox.set_deferred("monitoring", false)

	if attack_receiver:
		attack_receiver.set_deferred("monitoring", false)

	attacking = false

	call_deferred("spawn_coins")

	if has_animation(death_animation):
		play_animation(death_animation)
		await wait_for_animation(death_animation)

	queue_free()


func spawn_coins() -> void:
	if coin_scene == null or coin_count <= 0:
		return
	if randf() > coin_drop_chance:
		return

	var parent := get_tree().current_scene
	if parent == null:
		return

	for i in range(coin_count):
		var coin := coin_scene.instantiate()
		var offset := Vector2(
			randf_range(-coin_spread, coin_spread),
			randf_range(-coin_spread * 0.3, 0.0)
		)
		coin.global_position = global_position + offset
		parent.add_child(coin)


func apply_damage_to(target):
	if target.has_method("take_damage"):
		target.take_damage(damage, self)


func _on_hitbox_body_entered(body):
	if dying or not attacking:
		return
	var target := resolve_damage_target(body)
	if target:
		apply_damage_to(target)


func _on_hitbox_area_entered(area):
	if dying or not attacking:
		return
	var target := resolve_damage_target(area)
	if target:
		apply_damage_to(target)


func _on_attack_receiver_area_entered(area):
	if area == null or dying:
		return

	if area.has_meta(&"projectile_direct_damage"):
		return

	if area.is_in_group("player_attack"):
		take_damage(get_damage_from_area(area, 1))


func _on_hurtbox_area_entered(area):
	if area == null or dying:
		return

	if area.is_in_group("player_stomper"):
		take_damage(get_damage_from_area(area, 1))


func get_damage_from_area(area: Area2D, fallback: int = 1) -> int:
	if area and area.has_meta(ATTACK_META_DAMAGE):
		return max(int(area.get_meta(ATTACK_META_DAMAGE)), 1)
	return max(fallback, 1)


func resolve_damage_target(node: Node) -> Node:
	var current := node
	while current != null:
		if current.is_in_group(player_hurtbox_group):
			return current.get_parent()
		current = current.get_parent()
	return null


func resolve_contact_target(node: Node) -> Node:
	var current := node
	while current != null:
		if current.is_in_group(player_group):
			return current
		current = current.get_parent()
	return null


func deal_damage_to_player(target: Node) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(damage)


func uses_frame_based_hitbox() -> bool:
	return attack_hitbox_start_frame >= 0 and attack_hitbox_end_frame >= attack_hitbox_start_frame


func run_attack_hitbox_by_frames(anim: StringName, serial: int) -> void:
	if not sprite or not has_animation(anim):
		return

	if hitbox_shape:
		hitbox_shape.disabled = true

	var last_frame := -1
	while is_current_attack(serial) and sprite.animation == anim and sprite.is_playing():
		var frame := sprite.frame
		if frame != last_frame:
			update_attack_hitbox_frame_state(frame)
			last_frame = frame
		await get_tree().process_frame

	if hitbox_shape:
		hitbox_shape.disabled = true


func update_attack_hitbox_frame_state(frame: int) -> void:
	if not hitbox_shape:
		return

	var inside_window := frame >= attack_hitbox_start_frame and frame <= attack_hitbox_end_frame
	hitbox_shape.disabled = not inside_window


func update_animation():
	if sprite == null or dying:
		return

	if hit_reaction_active:
		play_animation(got_hit_animation)
	elif attacking:
		play_attack_animation()
	elif abs(velocity.x) > 5 or (move_mode == MoveMode.FLY and abs(velocity.y) > 5):
		play_walk_animation()
	else:
		play_idle_animation()


func play_idle_animation():
	play_animation(idle_animation)

func play_walk_animation():
	play_animation(walk_animation)

func play_attack_animation(restart: bool = false):
	if restart:
		restart_animation(attack_animation)
		return
	play_animation(attack_animation)


func wait_for_animation(anim):
	if not has_animation(anim):
		return

	var duration = get_animation_duration(anim)
	if duration > 0:
		await get_tree().create_timer(duration).timeout


func get_attack_hitbox_start_delay() -> float:
	var total = get_animation_duration(attack_animation)
	return maxf(total - hitbox_active_time, 0)


func get_animation_duration(anim):
	if not has_animation(anim):
		return 0

	var frames = sprite.sprite_frames.get_frame_count(anim)
	var speed = maxf(sprite.sprite_frames.get_animation_speed(anim), 1.0)

	return float(frames) / speed


func has_animation(anim):
	return sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim)


func play_animation(anim):
	if has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


func restart_animation(anim: StringName) -> void:
	if not has_animation(anim):
		return
	sprite.stop()
	sprite.animation = anim
	sprite.set_frame_and_progress(0, 0.0)
	sprite.play(anim)
