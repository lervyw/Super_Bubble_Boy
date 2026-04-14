extends CharacterBody2D

signal boss_defeated

enum State { IDLE, CHASE, ATTACK, STUN, TRANSFORM, DEAD }
enum Form { NORMAL, SUPER }

@export var player_group: StringName = "player"

@export_group("Stats")
@export var max_health: int = 6
var health: int = max_health

@export_group("Movement")
@export var speed: float = 90.0
@export var gravity: float = 900.0
@export var stop_distance: float = 60.0
@export var aggro_range: float = 450.0

@export_group("Attack")
@export var damage: int = 2
@export var attack_range: float = 70.0
@export var attack_cooldown: float = 1.0
@export var hitbox_active_time: float = 0.12

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

@onready var sprite: AnimatedSprite2D = get_node_or_null(sprite_path)
@onready var hurtbox: Area2D = get_node_or_null(hurtbox_path)
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)
@onready var hitbox_shape: CollisionShape2D = hitbox.get_node_or_null("CollisionShape2D") if hitbox else null

var player: Node2D
var state: State = State.IDLE
var form: Form = Form.NORMAL

var cooldown_t := 0.0
var facing_dir := -1

# =========================================================

func _ready():
	player = get_tree().get_first_node_in_group(player_group)

	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	if hitbox_shape:
		hitbox_shape.disabled = true

	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

# =========================================================

func _physics_process(delta):
	if state == State.DEAD:
		return

	if cooldown_t > 0:
		cooldown_t -= delta

	apply_gravity(delta)

	if not is_instance_valid(player):
		return

	var dist = global_position.distance_to(player.global_position)

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
	var dir = sign(player.global_position.x - global_position.x)

	if dist <= stop_distance:
		velocity.x = 0
	else:
		facing_dir = dir
		update_sprite_direction(facing_dir)
		velocity.x = dir * speed

	if dist <= attack_range and cooldown_t <= 0:
		state = State.ATTACK
		start_attack()
		return

# =========================================================

func start_attack():
	cooldown_t = attack_cooldown

	play_attack_animation()

	await wait_for_attack_hitbox_start()

	if hitbox_shape:
		hitbox_shape.disabled = false

	await get_tree().create_timer(hitbox_active_time).timeout

	if hitbox_shape:
		hitbox_shape.disabled = true

	await wait_for_animation(get_attack_anim())

	state = State.CHASE

# =========================================================

func take_damage(amount):
	if state == State.DEAD:
		return

	health -= amount

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

	if has_animation(death_animation):
		play_animation(death_animation)
		await wait_for_animation(death_animation)

	emit_signal("boss_defeated")
	queue_free()

# =========================================================

func _on_hurtbox_area_entered(area):
	if area.is_in_group("player_stomper"):
		take_damage(1)

func _on_hitbox_body_entered(body):
	if body.is_in_group(player_group):
		if body.has_method("take_damage"):
			body.take_damage(damage)

# =========================================================

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

# =========================================================

func update_sprite_direction(dir):
	if not sprite:
		return

	# sprite olha pra esquerda por padrão
	sprite.flip_h = dir > 0

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
	play_animation(get_attack_anim())

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
