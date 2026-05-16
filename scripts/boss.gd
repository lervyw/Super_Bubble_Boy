extends CharacterBody2D

signal boss_defeated
signal health_changed(current_health: int, max_health: int)
signal hud_visibility_changed(visible: bool)

const ATTACK_META_DAMAGE := &"attack_damage"

enum State { IDLE, CHASE, ATTACK, STUN, TRANSFORM, DEAD }
enum Form { NORMAL, SUPER }

@export var player_group: StringName = "jogador"
@export var player_hurtbox_group: StringName = "player_hurtbox"

@export_group("Stats")
@export var max_health: int = 6
@export var take_stomp_damage: bool = true
var health: int = max_health

@export_group("Movement")
@export var speed: float = 90.0
@export var gravity: float = 900.0
@export var stop_distance: float = 60.0
@export var aggro_range: float = 450.0
@export var turn_horizontal_threshold: float = 32.0

@export_group("Water")
@export_range(0.05, 1.0, 0.05) var water_speed_multiplier: float = 0.55
@export_range(0.05, 1.0, 0.05) var water_gravity_multiplier: float = 0.35

@export_group("Attack")
@export var damage: int = 2
@export var attack_range: float = 70.0
@export var attack_cooldown: float = 1.0
@export var hitbox_active_time: float = 0.12
@export_range(-1, 99, 1) var attack_hitbox_start_frame: int = -1
@export_range(-1, 99, 1) var attack_hitbox_end_frame: int = -1

@export_group("Projectile Attack")
@export var projectile_attack_scene: PackedScene = preload("res://Cenas/boss_projectile.tscn")
@export_range(0.0, 1.0, 0.05) var projectile_attack_chance: float = 0.35
@export var projectile_attack_animation: StringName = &"attack2"
@export_range(0, 99, 1) var projectile_attack_fire_frame: int = 6
@export var projectile_mouth_offset: Vector2 = Vector2(38.0, -27.0)
@export var projectile_damage: int = 2

@export_group("Animations")
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var attack_animation: StringName = &"attack"

@export var idle_super_animation: StringName = &"idle_super"
@export var walk_super_animation: StringName = &"walk_super"
@export var attack_super_animation: StringName = &"attack_super"

@export var transform_animation: StringName = &"transform"
@export var death_animation: StringName = &"death"

@export_group("Nodes")
@export var sprite_path: NodePath = NodePath("AnimatedSprite2D")
@export var hurtbox_path: NodePath = NodePath("Hurtbox")
@export var hitbox_path: NodePath = NodePath("AttackHitbox")
@export var attack_receiver_path: NodePath = NodePath("AttackReceiver")

@onready var sprite: AnimatedSprite2D = get_node_or_null(sprite_path)
@onready var hurtbox: Area2D = get_node_or_null(hurtbox_path)
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)
@onready var hitbox_shape: CollisionShape2D = hitbox.get_node_or_null("CollisionShape2D") if hitbox else null
@onready var attack_receiver: Area2D = get_node_or_null(attack_receiver_path)

var player: Node2D
var state: State = State.IDLE
var form: Form = Form.NORMAL

var cooldown_t := 0.0
var facing_dir := -1
var hud_visible := false
var attack_hitbox_base_position: Vector2 = Vector2.ZERO
var in_water: bool = false
var water_zone_overlap_count: int = 0
var rng := RandomNumberGenerator.new()
var current_attack_animation: StringName = &""

# =========================================================

func _ready():
	if not is_in_group("boss"):
		add_to_group("boss")
	rng.randomize()

	health = max_health
	player = get_tree().get_first_node_in_group(player_group)

	if hurtbox and not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	if attack_receiver and not attack_receiver.area_entered.is_connected(_on_attack_receiver_area_entered):
		attack_receiver.area_entered.connect(_on_attack_receiver_area_entered)

	if hitbox_shape:
		attack_hitbox_base_position = hitbox_shape.position
		hitbox_shape.disabled = true

	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)

	update_sprite_direction(facing_dir)

	emit_signal("health_changed", health, max_health)
	emit_signal("hud_visibility_changed", false)

# =========================================================

func _physics_process(delta):
	if state == State.DEAD:
		return

	if cooldown_t > 0:
		cooldown_t -= delta

	apply_gravity(delta)

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(player_group)
	if not is_instance_valid(player):
		return

	var dist = global_position.distance_to(player.global_position)
	update_hud_visibility(dist <= aggro_range)

	match state:
		State.IDLE:
			handle_idle(dist)

		State.CHASE:
			handle_chase(dist)

		State.ATTACK:
			pass

		State.STUN:
			pass

	move_and_slide()
	update_animation()

# =========================================================

func handle_idle(dist):
	if dist <= aggro_range:
		state = State.CHASE

func handle_chase(dist):
	var dir: int = get_horizontal_chase_direction()

	if dir != 0:
		facing_dir = dir

	if dist <= stop_distance:
		velocity.x = 0
	else:
		velocity.x = facing_dir * get_water_speed()
		update_sprite_direction(facing_dir)

	if dist <= attack_range and cooldown_t <= 0:
		state = State.ATTACK
		start_attack()
		return


func get_horizontal_chase_direction() -> int:
	if not is_instance_valid(player):
		return 0

	var horizontal_delta: float = player.global_position.x - global_position.x
	if absf(horizontal_delta) < turn_horizontal_threshold:
		return 0

	return int(sign(horizontal_delta))

# =========================================================

func start_attack():
	cooldown_t = attack_cooldown
	velocity.x = 0

	if should_use_projectile_attack():
		await start_projectile_attack()
		return

	current_attack_animation = get_attack_anim()
	restart_attack_animation()

	if uses_frame_based_hitbox():
		await run_attack_hitbox_by_frames(get_attack_anim())
	else:
		await wait_for_attack_hitbox_start()

		if hitbox_shape:
			hitbox_shape.disabled = false

		await get_tree().create_timer(hitbox_active_time).timeout

		if hitbox_shape:
			hitbox_shape.disabled = true

	await wait_for_animation(get_attack_anim())

	state = State.CHASE
	current_attack_animation = &""

# =========================================================

func should_use_projectile_attack() -> bool:
	return projectile_attack_scene != null and has_animation(projectile_attack_animation) and rng.randf() <= projectile_attack_chance


func start_projectile_attack() -> void:
	current_attack_animation = projectile_attack_animation
	if hitbox_shape:
		hitbox_shape.disabled = true

	if sprite:
		sprite.play(projectile_attack_animation)

	await fire_projectile_on_animation_frame(projectile_attack_animation, projectile_attack_fire_frame)
	await wait_for_animation(projectile_attack_animation)

	state = State.CHASE
	current_attack_animation = &""


func fire_projectile_on_animation_frame(anim: StringName, target_frame: int) -> void:
	if not sprite or not has_animation(anim):
		spawn_projectile()
		return

	var fired := false
	while state == State.ATTACK and sprite.animation == anim and sprite.is_playing():
		if not fired and sprite.frame >= target_frame:
			spawn_projectile()
			fired = true
			return
		await get_tree().process_frame

	if not fired:
		spawn_projectile()


func spawn_projectile() -> void:
	if projectile_attack_scene == null:
		return

	var projectile := projectile_attack_scene.instantiate()
	projectile.global_position = get_projectile_spawn_position()
	var dir := Vector2(float(facing_dir), 0.0)
	if projectile.has_method("setup"):
		projectile.setup(dir, projectile_damage)
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(projectile)


func get_projectile_spawn_position() -> Vector2:
	var local_offset := Vector2(absf(projectile_mouth_offset.x) * float(facing_dir), projectile_mouth_offset.y)
	return global_position + local_offset

# =========================================================

func take_damage(amount):
	if state == State.DEAD:
		return

	health -= max(amount, 1)
	emit_signal("health_changed", max(health, 0), max_health)

	if form == Form.NORMAL and health <= max_health / 2:
		start_transform()
		return

	if health <= 0:
		die()
		return

	state = State.STUN
	await get_tree().create_timer(0.5).timeout
	state = State.CHASE

# =========================================================

func start_transform():
	state = State.TRANSFORM
	velocity = Vector2.ZERO

	if has_animation(transform_animation):
		play_animation(transform_animation)
		await wait_for_animation(transform_animation)

	change_form(Form.SUPER)

	state = State.CHASE

func change_form(new_form: Form):
	form = new_form

	# 🔥 melhora comportamento na fase 2
	speed *= 1.3
	attack_cooldown *= 0.7

	update_animation()

# =========================================================

func die():
	state = State.DEAD

	set_physics_process(false)
	update_hud_visibility(false)

	if has_animation(death_animation):
		play_animation(death_animation)
		await wait_for_animation(death_animation)

	emit_signal("boss_defeated")
	queue_free()

# =========================================================

func _on_hurtbox_area_entered(area):
	if area == null or state == State.DEAD:
		return

	if take_stomp_damage and area.is_in_group("player_stomper"):
		take_damage(get_damage_from_area(area, 1))


func _on_attack_receiver_area_entered(area):
	if area == null or state == State.DEAD:
		return

	if area.has_meta(&"projectile_direct_damage"):
		return

	if area.is_in_group("player_attack"):
		take_damage(get_damage_from_area(area, 1))

func _on_hitbox_body_entered(body):
	var target := resolve_damage_target(body)
	if target and target.has_method("take_damage"):
		target.take_damage(damage, self)


func _on_hitbox_area_entered(area):
	var target := resolve_damage_target(area)
	if target and target.has_method("take_damage"):
		target.take_damage(damage, self)


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


func deal_damage_to_player(target: Node) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(damage)


func update_hud_visibility(visible: bool) -> void:
	if hud_visible == visible:
		return
	hud_visible = visible
	emit_signal("hud_visibility_changed", visible)


func is_hud_visible() -> bool:
	return hud_visible

# =========================================================

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * get_water_gravity_multiplier() * delta

# =========================================================

func enter_water_zone(_water: Node = null) -> void:
	water_zone_overlap_count += 1
	in_water = true


func exit_water_zone(_water: Node = null) -> void:
	water_zone_overlap_count = max(water_zone_overlap_count - 1, 0)
	in_water = water_zone_overlap_count > 0


func get_water_speed() -> float:
	return speed * (water_speed_multiplier if in_water else 1.0)


func get_water_gravity_multiplier() -> float:
	return water_gravity_multiplier if in_water else 1.0

# =========================================================

func update_sprite_direction(dir):
	if not sprite:
		return

	# sprite olha pra esquerda por padrão
	sprite.flip_h = dir > 0
	update_attack_hitbox_direction(dir)


func update_attack_hitbox_direction(dir: int) -> void:
	if not hitbox_shape:
		return

	hitbox_shape.position = Vector2(
		-attack_hitbox_base_position.x if sprite and sprite.flip_h else attack_hitbox_base_position.x,
		attack_hitbox_base_position.y
	)


func uses_frame_based_hitbox() -> bool:
	return attack_hitbox_start_frame >= 0 and attack_hitbox_end_frame >= attack_hitbox_start_frame


func run_attack_hitbox_by_frames(anim: StringName) -> void:
	if not sprite or not has_animation(anim):
		return

	if hitbox_shape:
		hitbox_shape.disabled = true

	var last_frame := -1
	while state == State.ATTACK and sprite.animation == anim and sprite.is_playing():
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

# =========================================================

func update_animation():
	if not sprite:
		return

	if state == State.ATTACK:
		play_attack_animation()
		return

	if abs(velocity.x) > 5:
		play_animation(get_walk_anim())
	else:
		play_animation(get_idle_anim())

# =========================================================

func get_idle_anim():
	return idle_super_animation if form == Form.SUPER else idle_animation

func get_walk_anim():
	return walk_super_animation if form == Form.SUPER else walk_animation

func get_attack_anim():
	return attack_super_animation if form == Form.SUPER else attack_animation

# =========================================================

func play_attack_animation():
	play_animation(get_current_attack_anim())

func restart_attack_animation():
	var anim := get_current_attack_anim()
	if has_animation(anim):
		sprite.play(anim)

func get_current_attack_anim() -> StringName:
	return current_attack_animation if current_attack_animation != &"" else get_attack_anim()

func play_animation(anim):
	if has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)

func has_animation(anim):
	return sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim)

func wait_for_animation(anim):
	var duration = get_animation_duration(anim)
	if duration > 0:
		await get_tree().create_timer(duration).timeout

func wait_for_attack_hitbox_start():
	var total = get_animation_duration(get_attack_anim())
	var delay = maxf(total - hitbox_active_time, 0)
	if delay > 0:
		await get_tree().create_timer(delay).timeout

func get_animation_duration(anim):
	if not has_animation(anim):
		return 0
	var frames = sprite.sprite_frames.get_frame_count(anim)
	var speed = maxf(sprite.sprite_frames.get_animation_speed(anim), 1.0)
	return float(frames) / speed
