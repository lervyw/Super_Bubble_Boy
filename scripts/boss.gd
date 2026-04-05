# BossSimple.gd
extends CharacterBody2D

signal boss_defeated

# =========================================================
#  BOSS SIMPLES
#  - Move até o player (andar/pular/voar)
#  - Ataca ativando uma hitbox (Area2D) por alguns ms
#  - Usa animações de idle/walk/attack conforme a ação
# =========================================================

enum MoveMode { WALK, JUMP, FLY }

@export_group("Target")
@export var player_group: StringName = "player"

@export_group("Movement")
@export var move_mode: MoveMode = MoveMode.WALK
@export var speed: float = 90.0
@export var gravity: float = 900.0
@export var jump_force: float = -320.0
@export var jump_interval: float = 0.55
@export var fly_vertical_follow: bool = true
@export var fly_y_speed: float = 60.0

@export_group("AI")
@export var aggro_range: float = 450.0
@export var stop_distance: float = 60.0

@export_group("Attack")
@export var damage: int = 2
@export var attack_range: float = 70.0
@export var hitbox_active_time: float = 0.12
@export var attack_cooldown: float = 1.0

@export_group("Health")
@export var max_health: int = 3
var health: int = max_health

@export_group("Nodes")
@export var sprite_path: NodePath = NodePath("AnimatedSprite2D")
@export var hitbox_path: NodePath = NodePath("AttackHitbox")
@export var hurtbox_path: NodePath = NodePath("Hurtbox")

@onready var sprite: AnimatedSprite2D = get_node_or_null(sprite_path)
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)
@onready var hitbox_shape: CollisionShape2D = (
	hitbox.get_node_or_null("CollisionShape2D") if hitbox else null
)
@onready var hurtbox: Area2D = get_node_or_null(hurtbox_path)

var player: Node2D
var cooldown_t: float = 0.0
var jump_t: float = 0.0
var attacking: bool = false
var stunned: bool = false
var dying: bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group(player_group) as Node2D

	if hitbox_shape:
		hitbox_shape.disabled = true

	if hitbox:
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)
	if hurtbox and not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	play_animation(&"idle")


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
		play_animation(&"idle")
		move_and_slide()
		return

	var dist := global_position.distance_to(player.global_position)
	if dist > aggro_range:
		velocity.x = 0.0
		play_animation(&"idle")
		move_and_slide()
		return

	if not stunned and not attacking and cooldown_t <= 0.0 and dist <= attack_range:
		start_attack()
		velocity.x = 0.0
		move_and_slide()
		return

	move_towards_player(dist)
	move_and_slide()
	update_animation()


func move_towards_player(dist: float) -> void:
	var dir: int = int(sign(player.global_position.x - global_position.x))
	if dir == 0:
		dir = 1

	if sprite:
		sprite.flip_h = dir < 0

	if dist <= stop_distance:
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


func start_attack() -> void:
	attacking = true
	cooldown_t = attack_cooldown
	play_animation(&"attack")

	if hitbox_shape:
		hitbox_shape.disabled = false

	await get_tree().create_timer(hitbox_active_time).timeout

	if hitbox_shape:
		hitbox_shape.disabled = true

	attacking = false
	update_animation()


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
	update_animation()


func die() -> void:
	if dying:
		return

	dying = true

	if $CollisionShape2D:
		$CollisionShape2D.disabled = true
	if hitbox_shape:
		hitbox_shape.disabled = true
	if hurtbox and hurtbox.get_node("CollisionShape2D"):
		hurtbox.get_node("CollisionShape2D").disabled = true

	if sprite:
		sprite.stop()

	emit_signal("boss_defeated")
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
				print("player pisou no boss")
		return

	if area.is_in_group("killer"):
		var attack_damage := resolve_attack_damage(area)
		if attack_damage > 0:
			take_damage(attack_damage)
			print("levou dano do player")


func resolve_attack_damage(area: Area2D) -> int:
	if area == null:
		return 0
	if area.has_meta("attack_damage"):
		return int(area.get_meta("attack_damage"))
	return 0


func update_animation() -> void:
	if sprite == null or dying:
		return
	if attacking:
		play_animation(&"attack")
		return
	if abs(velocity.x) > 5.0:
		play_animation(&"walk")
		return
	play_animation(&"idle")


func play_animation(anim_name: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation != anim_name:
		sprite.play(anim_name)
