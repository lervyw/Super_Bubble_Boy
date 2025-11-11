extends CharacterBody2D

# ============================
# 🔧 CONFIGURAÇÕES
# ============================

@onready var sprite = $AnimatedSprite2D
@onready var hurt_area = $HurtArea
@onready var player = get_tree().get_first_node_in_group("player")
@export var damage_particles = CPUParticles2D  # CPUParticles2D

@export_group("Movimento")
@export var move_speed: float = 100.0
@export var chase_speed: float = 160.0
@export var gravity: float = 900.0
@export var jump_force: float = -400.0

@export_group("Detecção")
@export var detection_range: float = 300.0
@export var attack_range: float = 140.0
@export var min_distance_from_player: float = 60.0
@export var resume_chase_delay: float = 1.5

@export_group("Vida")
@export var max_health: int = 3

@export_group("Debug")
@export var show_debug: bool = false

# ============================
# 🔒 VARIÁVEIS DE ESTADO
# ============================

var current_health: int
var move_dir: float = 1.0
var attack_cooldown: float = 0.0
var resume_chase_timer: float = 0.0
var edge_check: RayCast2D
var wall_check: RayCast2D
var is_hurt: bool = false
var can_flip: bool = true

# ============================
# 🧩 FUNÇÕES PRINCIPAIS
# ============================

func _ready() -> void:
	current_health = max_health
	create_rays()
	
	if hurt_area:
		hurt_area.connect("area_entered", Callable(self, "_on_hurt_area_area_entered"))
	
	if not player:
		push_warning("Boss: player não encontrado!")

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

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return
	
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if resume_chase_timer > 0:
		resume_chase_timer -= delta

	update_rays_direction()

	if not player:
		patrol(delta)
	elif resume_chase_timer > 0:
		patrol(delta)
	else:
		chase_and_attack(delta)

	move_and_slide()
	handle_animation()

func update_rays_direction() -> void:
	if edge_check:
		edge_check.position.x = 20 * move_dir
	if wall_check:
		wall_check.position.x = 20 * move_dir
		wall_check.target_position.x = 20 * move_dir

# ============================
# 🤖 LÓGICA DE MOVIMENTO
# ============================

func patrol(delta: float) -> void:
	if not can_flip:
		velocity.x = move_dir * move_speed
		return

	velocity.x = move_dir * move_speed

	if wall_check and wall_check.is_colliding():
		debug_print("🧱 Parede detectada!")
		yield_flip()
		return

	if edge_check and not edge_check.is_colliding() and is_on_floor():
		debug_print("⚠️ Borda detectada!")
		yield_flip()
		return

func yield_flip() -> void:
	can_flip = false
	move_dir *= -1
	update_flip()
	velocity.x = 0
	await get_tree().create_timer(0.3).timeout
	can_flip = true

func chase_and_attack(delta: float) -> void:
	var dist = global_position.distance_to(player.global_position)
	var dir_to_player = sign(player.global_position.x - global_position.x)

	# SALTO PARA LONGE SE EM CIMA DO PLAYER
	if abs(global_position.y - player.global_position.y) < 50 and is_on_floor():
		debug_print("↩️ Boss está em cima do player, pula para longe!")
		can_flip = false
		velocity.y = jump_force
		velocity.x = -dir_to_player * chase_speed
		resume_chase_timer = resume_chase_delay
		await get_tree().create_timer(resume_chase_delay).timeout
		can_flip = true
		return

	move_dir = dir_to_player
	update_flip()

	if dist > attack_range:
		velocity.x = dir_to_player * chase_speed
		return

	if dist < min_distance_from_player and is_on_floor():
		debug_print("↩️ Fugindo do player")
		velocity.x = -dir_to_player * chase_speed * 0.7
		velocity.y = jump_force
		resume_chase_timer = resume_chase_delay
		return

	if attack_cooldown <= 0 and is_on_floor():
		debug_print("💥 Pulo de ataque!")
		attack_cooldown = 1.2
		velocity.x = dir_to_player * chase_speed
		velocity.y = jump_force
		return

	velocity.x = dir_to_player * move_speed

# ============================
# 💥 DANO E MORTE
# ============================

func _on_hurt_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("killer") or area.is_in_group("player_attack"):
		take_damage(1)

func take_damage(amount: int) -> void:
	if is_hurt or current_health <= 0:
		return

	current_health -= amount
	debug_print("🩸 Boss HP: %d/%d" % [current_health, max_health])
	is_hurt = true
	
	# Piscar vermelho
	var original_modulate = sprite.modulate
	sprite.modulate = Color(1, 0, 0, 1)
	
	# Ativar partículas de dano
	if damage_particles:
		damage_particles.emitting = true
	
	sprite.play("hurt")
	
	velocity.y = -200
	velocity.x = -move_dir * 150
	
	# Espera 0.6s do efeito de dano
	await get_tree().create_timer(0.6).timeout
	
	# Desliga partículas e volta à cor normal
	if damage_particles:
		damage_particles.emitting = false
	sprite.modulate = original_modulate
	
	is_hurt = false
	
	if current_health <= 0:
		die()

signal boss_defeated

func die() -> void:
	debug_print("💀 Boss derrotado!")

	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		sprite.play("hurt")

	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if hurt_area:
		hurt_area.monitoring = false

	emit_signal("boss_defeated")
	await get_tree().create_timer(1.5).timeout
	queue_free()

# ============================
# 🎞️ ANIMAÇÕES
# ============================

func handle_animation() -> void:
	if current_health <= 0:
		return
	
	if is_hurt:
		return
	
	if not is_on_floor():
		if sprite.sprite_frames.has_animation("jump"):
			sprite.play("jump")
		else:
			sprite.play("idle")
	elif abs(velocity.x) > 20:
		if sprite.sprite_frames.has_animation("walk"):
			sprite.play("walk")
		else:
			sprite.play("idle")
	else:
		sprite.play("idle")

func update_flip() -> void:
	sprite.flip_h = move_dir < 0

# ============================
# 🧰 DEBUG
# ============================

func debug_print(msg: String) -> void:
	if show_debug:
		print(msg)
