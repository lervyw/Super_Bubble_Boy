extends CharacterBody2D

const ATTACK_META_DAMAGE := &"attack_damage"

enum MoveMode { WALK, JUMP, FLY }
enum AttackMode { CONTACT, HITBOX }

@export_group("Target")
@export var player_group: StringName = "player"

@export_group("Movement")
@export var move_mode: MoveMode = MoveMode.JUMP
@export var speed: float = 70.0
@export var gravity: float = 900.0
@export var jump_force: float = -260.0
@export var jump_interval: float = 0.35
@export var fly_y_speed: float = 70.0
@export var fly_vertical_follow: bool = true

@export_group("AI")
@export var aggro_range: float = 260.0
@export var stop_distance: float = 40.0
@export var avoid_other_slimes: bool = true
@export var separation_distance: float = 20.0
@export var separation_strength: float = 45.0

@export_group("Attack")
@export var attack_mode: AttackMode = AttackMode.HITBOX
@export var damage: int = 1
@export var attack_range: float = 48.0
@export var hitbox_active_time: float = 0.10
@export var attack_cooldown: float = 0.85
@export var contact_attack_requires_fall: bool = false
@export var contact_attack_min_speed_y: float = 10.0

@export_group("Health")
@export var max_health: int = 3
var health: int = max_health

@export_group("Nodes")
@export var sprite_path: NodePath = NodePath("AnimatedSprite2D")
@export var hitbox_path: NodePath = NodePath("AttackHitbox")
@export var attack_receiver_path: NodePath = NodePath("AttackReceiver")
@export var hurtbox_path: NodePath = NodePath("Hurtbox")

@export var sprite_faces_left_by_default: bool = true
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var attack_animation: StringName = &"attack"
@export var death_animation: StringName = &"death"

@onready var sprite: AnimatedSprite2D = get_node_or_null(sprite_path)
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)
@onready var hitbox_shape: CollisionShape2D = hitbox.get_node_or_null("CollisionShape2D") if hitbox else null
@onready var attack_receiver: Area2D = get_node_or_null(attack_receiver_path)
@onready var hurtbox: Area2D = get_node_or_null(hurtbox_path)

var player: Node2D
var cooldown_t: float = 0.0
var jump_t: float = 0.0
var attacking: bool = false
var stunned: bool = false
var dying: bool = false
var attack_hitbox_base_position: Vector2 = Vector2.ZERO


func _ready():
	if not is_in_group("slime"):
		add_to_group("slime")

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

	play_idle_animation()


func _physics_process(delta):
	if dying:
		return

	if cooldown_t > 0:
		cooldown_t -= delta
	if jump_t > 0:
		jump_t -= delta

	if move_mode != MoveMode.FLY and not is_on_floor():
		velocity.y += gravity * delta
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

	if attack_mode == AttackMode.HITBOX and not stunned and not attacking and cooldown_t <= 0 and dist <= attack_range:
		start_attack()
		return

	move_towards_player(dist)
	move_and_slide()
	process_contact_attack()
	update_animation()


func move_towards_player(dist):
	var dir = sign(player.global_position.x - global_position.x)

	# ❌ NÃO vira imediatamente
	if dist <= stop_distance and attack_mode == AttackMode.HITBOX:
		velocity.x = 0
		return

	# ✅ só vira quando realmente vai se mover
	update_sprite_direction(dir)

	match move_mode:
		MoveMode.WALK:
			velocity.x = dir * speed
		MoveMode.JUMP:
			velocity.x = dir * speed
			if is_on_floor():
				velocity.y = jump_force
		MoveMode.FLY:
			velocity.x = dir * speed


# ✅ NOVA FUNÇÃO RESPONSÁVEL POR VIRAR O SPRITE
func update_sprite_direction(dir):
	if not sprite:
		return

	if sprite_faces_left_by_default:
		sprite.flip_h = dir > 0
	else:
		sprite.flip_h = dir < 0


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

		var target := resolve_player_target(collision.get_collider())
		if target:
			apply_damage_to(target)
			cooldown_t = attack_cooldown
			return


func start_attack():
	attacking = true
	cooldown_t = attack_cooldown

	play_attack_animation()

	await wait_for_attack_hitbox_start()

	if hitbox_shape:
		hitbox_shape.disabled = false

	await get_tree().create_timer(hitbox_active_time).timeout

	if hitbox_shape:
		hitbox_shape.disabled = true

	await wait_for_animation(attack_animation)

	attacking = false


func take_damage(amount):
	if dying:
		return

	health -= max(amount, 1)
	stunned = true
	attacking = false

	if health <= 0:
		die()
		return

	await get_tree().create_timer(1.0).timeout
	stunned = false


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

	if has_animation(death_animation):
		play_animation(death_animation)
		await wait_for_animation(death_animation)

	queue_free()


func apply_damage_to(target):
	if target.has_method("take_damage"):
		target.take_damage(damage)


func _on_hitbox_body_entered(body):
	if dying or not attacking:
		return
	var target := resolve_player_target(body)
	if target:
		apply_damage_to(target)


func _on_hitbox_area_entered(area):
	if dying or not attacking:
		return
	var target := resolve_player_target(area)
	if target:
		apply_damage_to(target)


func _on_attack_receiver_area_entered(area):
	if area == null or dying:
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


func resolve_player_target(node: Node) -> Node:
	var current := node
	while current != null:
		if current.is_in_group(player_group):
			return current
		if current.has_method("take_damage") and current is CharacterBody2D:
			return current
		current = current.get_parent()
	return null


func deal_damage_to_player(target: Node) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(damage)


func update_animation():
	if sprite == null or dying:
		return

	if attacking:
		play_attack_animation()
	elif abs(velocity.x) > 5:
		play_walk_animation()
	else:
		play_idle_animation()


func play_idle_animation():
	play_animation(idle_animation)

func play_walk_animation():
	play_animation(walk_animation)

func play_attack_animation():
	play_animation(attack_animation)


func wait_for_animation(anim):
	if not has_animation(anim):
		return

	var duration = get_animation_duration(anim)
	if duration > 0:
		await get_tree().create_timer(duration).timeout


func wait_for_attack_hitbox_start():
	var total = get_animation_duration(attack_animation)
	var delay = maxf(total - hitbox_active_time, 0)
	if delay > 0:
		await get_tree().create_timer(delay).timeout


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
