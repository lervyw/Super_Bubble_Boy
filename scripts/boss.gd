extends CharacterBody2D

# ======================================================
# 🔧 CONFIGURAÇÕES
# ======================================================

@onready var sprite = $AnimatedSprite2D
@onready var hurt_area = $HurtArea
@onready var stomp_area = $StompArea
@onready var player = get_tree().get_first_node_in_group("player")

@export var damage_particles: CPUParticles2D
@export var move_speed: float = 80.0
@export var chase_speed: float = 150.0
@export var gravity: float = 900.0
@export var jump_force: float = -380.0

@export var detection_range: float = 260.0
@export var attack_cooldown_time: float = 1.0
@export var flee_distance: float = 80.0      # distância mínima para fugir
@export var flee_jump_force: float = -350.0  # força do pulo para fugir

@export var max_health: int = 3
@export var show_debug: bool = false

# ======================================================
# 🔒 VARIÁVEIS
# ======================================================

var current_health: int
var move_dir: int = 1
var attack_cooldown: float = 0.0
var is_hurt: bool = false
var can_flip: bool = true

var edge_check: RayCast2D
var wall_check: RayCast2D

# ======================================================
# 🧩 READY
# ======================================================

func _ready() -> void:
	current_health = max_health
	create_rays()

	if hurt_area:
		hurt_area.connect("area_entered", Callable(self, "_on_hurt_area_area_entered"))

	if stomp_area:
		stomp_area.connect("area_entered", Callable(self, "_on_stomp_area_entered"))

	if not player:
		push_warning("Boss: Player não encontrado!")

# ======================================================
# 🧰 RAYS
# ======================================================

func create_rays() -> void:
	if not has_node("EdgeCheck"):
		edge_check = RayCast2D.new()
		edge_check.name = "EdgeCheck"
		add_child(edge_check)
	edge_check.enabled = true
	edge_check.position = Vector2(20, 0)
	edge_check.target_position = Vector2(0, 40)
	edge_check.collision_mask = 1

	if not has_node("WallCheck"):
		wall_check = RayCast2D.new()
		wall_check.name = "WallCheck"
		add_child(wall_check)
	wall_check.enabled = true
	wall_check.position = Vector2(20, 0)
	wall_check.target_position = Vector2(20, 0)
	wall_check.collision_mask = 1

func update_rays_direction() -> void:
	edge_check.position.x = 20 * move_dir
	wall_check.position.x = 20 * move_dir
	wall_check.target_position.x = 20 * move_dir

# ======================================================
# 🔁 PHYSICS
# ======================================================

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return

	# gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	# cooldown de ataque
	if attack_cooldown > 0:
		attack_cooldown -= delta

	update_rays_direction()

	# comportamento principal
	if player:
		var dist = global_position.distance_to(player.global_position)

		if dist <= detection_range:
			chase_and_attack(delta, dist)
		else:
			patrol(delta)
	else:
		patrol(delta)

	move_and_slide()
	handle_animation()

# ======================================================
# 🤖 COMPORTAMENTO
# ======================================================

func patrol(delta: float) -> void:
	if not can_flip:
		velocity.x = move_dir * move_speed
		return

	velocity.x = move_dir * move_speed

	# 👇 vira em paredes
	if wall_check.is_colliding():
		debug_print("Parede → virar")
		yield_flip()
		return

	# 👇 vira em bordas
	if not edge_check.is_colliding() and is_on_floor():
		debug_print("Borda → virar")
		yield_flip()
		return

func chase_and_attack(delta: float, dist: float) -> void:
	var dir_to_player = sign(player.global_position.x - global_position.x)
	move_dir = dir_to_player
	update_flip()

	# 📌 Se estiver muito perto → FUGIR
	if dist < flee_distance and is_on_floor():
		debug_print("Fugindo para se preservar!")
		velocity.x = -dir_to_player * chase_speed * 0.6
		velocity.y = flee_jump_force
		return

	# 📌 Se estiver no chão e sem cooldown → pular em direção ao player
	if is_on_floor() and attack_cooldown <= 0:
		debug_print("Ataque de pulo!")
		velocity.y = jump_force
		velocity.x = dir_to_player * chase_speed
		attack_cooldown = attack_cooldown_time
		return

	# Caso contrário, anda em direção ao player
	velocity.x = dir_to_player * move_speed

# ======================================================
# 🔁 FLIP
# ======================================================

func yield_flip() -> void:
	can_flip = false
	move_dir *= -1
	update_flip()
	velocity.x = 0
	await get_tree().create_timer(0.25).timeout
	can_flip = true

func update_flip() -> void:
	sprite.flip_h = move_dir < 0

# ======================================================
# 💥 DANOS & STOMP
# ======================================================

func _on_hurt_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack") or area.is_in_group("killer"):
		take_damage(1)

func _on_stomp_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_stomp"):
		take_damage(1)

		# Player bounce estilo Mario
		if area.has_method("on_stomped_enemy"):
			area.on_stomped_enemy()

func take_damage(amount: int) -> void:
	if is_hurt or current_health <= 0:
		return

	current_health -= amount
	is_hurt = true

	debug_print("HP: %d / %d" % [current_health, max_health])

	# efeito de dano
	var original_modulate = sprite.modulate
	sprite.modulate = Color(1, 0, 0)
	if damage_particles:
		damage_particles.emitting = true

	sprite.play("hurt")

	# knockback
	velocity.y = -200
	velocity.x = -move_dir * 150

	await get_tree().create_timer(0.5).timeout

	sprite.modulate = original_modulate
	if damage_particles:
		damage_particles.emitting = false

	is_hurt = false

	if current_health <= 0:
		die()

signal boss_defeated

func die() -> void:
	debug_print("Boss derrotado!")

	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		sprite.play("hurt")

	hurt_area.monitoring = false
	stomp_area.monitoring = false

	emit_signal("boss_defeated")

	await get_tree().create_timer(1.2).timeout
	queue_free()

# ======================================================
# 🎞️ ANIMAÇÃO
# ======================================================

func handle_animation() -> void:
	if is_hurt:
		return

	if not is_on_floor():
		if sprite.sprite_frames.has_animation("jump"):
			sprite.play("jump")
		else:
			sprite.play("idle")
	elif abs(velocity.x) > 10:
		if sprite.sprite_frames.has_animation("walk"):
			sprite.play("walk")
		else:
			sprite.play("idle")
	else:
		sprite.play("idle")

# ======================================================
# 🧰 DEBUG
# ======================================================

func debug_print(msg: String) -> void:
	if show_debug:
		print(msg)
