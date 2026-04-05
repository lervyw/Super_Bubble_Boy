# EnemySimple.gd
extends CharacterBody2D

# =========================================================
#  INIMIGO COMUM SIMPLES
#  - Move até o player (andar/pular/voar)
#  - Pode atacar por contato/pulo ou por hitbox
#  - Só morre por ataque válido do player ou stomp válido
# =========================================================

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
@export_range(0.0, 128.0, 1.0) var separation_distance: float = 20.0
@export_range(0.0, 200.0, 1.0) var separation_strength: float = 45.0

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
@onready var hitbox_shape: CollisionShape2D = (
	hitbox.get_node_or_null("CollisionShape2D") if hitbox else null
)
@onready var attack_receiver: Area2D = get_node_or_null(attack_receiver_path)
@onready var hurtbox: Area2D = get_node_or_null(hurtbox_path)

var player: Node2D
var cooldown_t: float = 0.0
var jump_t: float = 0.0
var attacking: bool = false
var stunned: bool = false
var dying: bool = false
var attack_hitbox_base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	player = get_tree().get_first_node_in_group(player_group) as Node2D

	if hitbox_shape:
		attack_hitbox_base_position = hitbox_shape.position
		hitbox_shape.disabled = true
		update_attack_hitbox_facing(get_facing_direction_to_player())

	if hitbox:
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)

	if attack_receiver and not attack_receiver.area_entered.is_connected(_on_attack_receiver_area_entered):
		attack_receiver.area_entered.connect(_on_attack_receiver_area_entered)

	if hurtbox and not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	play_idle_animation()


func _physics_process(delta: float) -> void:
	if dying:
		return

	if cooldown_t > 0.0:
		cooldown_t -= delta
	if jump_t > 0.0:
		jump_t -= delta

	if move_mode != MoveMode.FLY and not is_on_floor():
		velocity.y += gravity * delta
	elif move_mode == MoveMode.FLY:
		velocity.y = 0.0

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(player_group) as Node2D

	if not is_instance_valid(player):
		velocity.x = 0.0
		play_idle_animation()
		move_and_slide()
		return

	var dist := global_position.distance_to(player.global_position)
	if dist > aggro_range:
		velocity.x = 0.0
		play_idle_animation()
		move_and_slide()
		return

	if attack_mode == AttackMode.HITBOX and not stunned and not attacking and cooldown_t <= 0.0 and dist <= attack_range:
		start_attack()
		velocity.x = 0.0
		move_and_slide()
		return

	move_towards_player(dist)
	apply_slime_separation()
	move_and_slide()
	process_contact_attack()
	update_animation()


func move_towards_player(dist: float) -> void:
	var dir := get_facing_direction_to_player()

	if sprite:
		sprite.flip_h = dir > 0 if sprite_faces_left_by_default else dir < 0
	update_attack_hitbox_facing(dir)

	if dist <= stop_distance and attack_mode == AttackMode.HITBOX:
		velocity.x = 0.0
		return

	match move_mode:
		MoveMode.WALK:
			velocity.x = dir * speed

		MoveMode.JUMP:
			velocity.x = dir * speed
			if is_on_floor() and jump_t <= 0.0:
				velocity.y = jump_force
				jump_t = jump_interval

		MoveMode.FLY:
			velocity.x = dir * speed
			if fly_vertical_follow:
				var dy := player.global_position.y - global_position.y
				velocity.y = clamp(dy, -1.0, 1.0) * fly_y_speed


func apply_slime_separation() -> void:
	if not avoid_other_slimes:
		return

	var push: float = 0.0
	for node in get_tree().get_nodes_in_group("slime"):
		if node == self:
			continue
		if not (node is CharacterBody2D):
			continue

		var other_slime: CharacterBody2D = node as CharacterBody2D
		var diff: Vector2 = global_position - other_slime.global_position
		var dist: float = absf(diff.x)
		if dist <= 0.001 or dist > separation_distance:
			continue

		push += signf(diff.x) * ((separation_distance - dist) / separation_distance) * separation_strength

	velocity.x += push


func process_contact_attack() -> void:
	if attack_mode != AttackMode.CONTACT:
		return
	if cooldown_t > 0.0 or stunned or attacking:
		return

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue

		var collider := collision.get_collider()
		if collider and collider.is_in_group(player_group):
			if contact_attack_requires_fall and velocity.y < contact_attack_min_speed_y:
				continue

			apply_damage_to(collider)
			cooldown_t = attack_cooldown
			attacking = true
			play_attack_animation()
			_finish_contact_attack()
			return


func _finish_contact_attack() -> void:
	await wait_for_attack_animation()
	attacking = false


func start_attack() -> void:
	attacking = true
	cooldown_t = attack_cooldown
	play_attack_animation()
	update_attack_hitbox_facing(get_facing_direction_to_player())
	await wait_for_attack_hitbox_start()

	if hitbox_shape:
		hitbox_shape.disabled = false

	await get_tree().create_timer(hitbox_active_time).timeout

	if hitbox_shape:
		hitbox_shape.disabled = true

	await wait_for_attack_animation()
	attacking = false


func take_damage(amount: int) -> void:
	if dying:
		return

	health -= amount
	stunned = true
	attacking = false

	if hitbox_shape:
		hitbox_shape.disabled = true

	if health <= 0:
		die()
		return

	await get_tree().create_timer(1.0).timeout
	stunned = false


func die() -> void:
	if dying:
		return

	dying = true

	if $CollisionShape2D:
		$CollisionShape2D.set_deferred("disabled", true)
	if hitbox_shape:
		hitbox_shape.set_deferred("disabled", true)
	if hurtbox and hurtbox.get_node("CollisionShape2D"):
		hurtbox.get_node("CollisionShape2D").set_deferred("disabled", true)
	if attack_receiver and attack_receiver.get_node("CollisionShape2D"):
		attack_receiver.get_node("CollisionShape2D").set_deferred("disabled", true)

	if has_animation(death_animation):
		play_animation(death_animation)
		await wait_for_animation(death_animation)

	queue_free()


func apply_damage_to(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
		return

	if target.has_node("Stats"):
		var stats = target.get_node("Stats")
		if stats and stats.has_method("take_damage"):
			stats.take_damage(damage)


func _on_hitbox_body_entered(body: Node) -> void:
	if not attacking:
		return
	if body and body.is_in_group(player_group):
		apply_damage_to(body)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not attacking:
		return
	if not area:
		return

	var p := area.get_parent()
	if p and p.is_in_group(player_group):
		apply_damage_to(p)


func _on_attack_receiver_area_entered(area: Area2D) -> void:
	if area == null or dying:
		return

	if area.is_in_group("player_attack") or (area.is_in_group("killer") and area.has_meta("attack_damage")):
		var attack_damage := resolve_attack_damage(area)
		if attack_damage > 0:
			take_damage(attack_damage)
			print("levou dano do player")


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area == null or dying:
		return

	if area.is_in_group("player_stomper"):
		var p := area.get_parent()
		if p and p.is_in_group(player_group):
			var dy: float = p.global_position.y - global_position.y
			var player_velocity: Vector2 = p.get("velocity") if p.get("velocity") != null else Vector2.ZERO
			var player_velocity_y := player_velocity.y
			if dy < -10.0 and player_velocity_y > 0.0:
				die()
				print("player pisou no inimigo")


func resolve_attack_damage(area: Area2D) -> int:
	if area == null:
		return 0
	if area.has_meta("attack_damage"):
		return int(area.get_meta("attack_damage"))
	return 0


func get_facing_direction_to_player() -> int:
	if not is_instance_valid(player):
		return 1

	var dir: int = int(sign(player.global_position.x - global_position.x))
	if dir == 0:
		return 1
	return dir


func update_attack_hitbox_facing(dir: int) -> void:
	if hitbox_shape == null:
		return

	var hitbox_offset_x := absf(attack_hitbox_base_position.x)
	if is_zero_approx(hitbox_offset_x):
		var rectangle_shape := hitbox_shape.shape as RectangleShape2D
		if rectangle_shape:
			hitbox_offset_x = rectangle_shape.size.x * 0.5

	if is_zero_approx(hitbox_offset_x):
		return

	hitbox_shape.position = Vector2(hitbox_offset_x * dir, attack_hitbox_base_position.y)


func update_animation() -> void:
	if sprite == null:
		return
	if dying:
		return
	if attacking:
		play_attack_animation()
		return
	if abs(velocity.x) > 5.0:
		play_walk_animation()
		return
	play_idle_animation()


func play_idle_animation() -> void:
	play_animation(idle_animation)


func play_attack_animation() -> void:
	play_animation(attack_animation)


func play_walk_animation() -> void:
	play_animation(walk_animation)


func wait_for_attack_animation() -> void:
	if not has_animation(attack_animation):
		await get_tree().create_timer(hitbox_active_time).timeout
		return
	await wait_for_animation(attack_animation)


func wait_for_attack_hitbox_start() -> void:
	var attack_anim_duration := get_animation_duration(attack_animation)
	var hitbox_delay := maxf(attack_anim_duration - hitbox_active_time, 0.0)
	if hitbox_delay <= 0.0:
		return
	await get_tree().create_timer(hitbox_delay).timeout


func wait_for_animation(anim_name: StringName) -> void:
	if not has_animation(anim_name):
		return
	if sprite.animation != anim_name:
		play_animation(anim_name)

	var anim_duration := get_animation_duration(anim_name)
	if anim_duration <= 0.0:
		return
	await get_tree().create_timer(anim_duration).timeout


func get_animation_duration(anim_name: StringName) -> float:
	if not has_animation(anim_name):
		return 0.0

	var frame_count: int = sprite.sprite_frames.get_frame_count(anim_name)
	var speed: float = maxf(sprite.sprite_frames.get_animation_speed(anim_name), 1.0)
	return maxf(float(frame_count) / speed, 0.0)


func has_animation(anim_name: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)


func play_animation(anim_name: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation != anim_name:
		sprite.play(anim_name)
