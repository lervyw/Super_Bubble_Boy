extends CharacterBody2D

# --- Referências
@onready var animated_sprite = $AnimatedSprite2D
@onready var blood_particles = $CPUParticles2D

# --- Áreas exportáveis (configure no Inspector)
@export var hit_area: Area2D          # Player pisa no sapo
@export var damage_area: Area2D       # Player encosta e leva dano

# --- Movimento
@export_group("Movimento")
@export var SPEED: float = 120.0
@export var JUMP_FORCE: float = -350.0
@export var GRAVITY: float = 980.0

# --- Configuração do sapo
@export_group("Configuração")
@export var life: int = 3
@export var detection_range: float = 100.0
@export var idle_time: float = 2.0
@export var flip_left_when_moving_left: bool = true

# --- Estado interno
var player: Node2D
var is_dead := false
var direction := 1  # 1 = direita, -1 = esquerda
var can_jump := true
var in_idle_pause := false

enum State { PATROL, CHASING }
var current_state := State.PATROL


# ----------------------------------------------------------
func _ready():
	# Conecta sinais das áreas (se existirem)
	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)
	if damage_area:
		damage_area.body_entered.connect(_on_damage_area_body_entered)

	player = get_tree().get_first_node_in_group("player")


# ----------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravidade
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match current_state:
		State.PATROL:
			handle_patrol()
		State.CHASING:
			handle_chasing()

	move_and_slide()
	update_animation()


# ----------------------------------------------------------
func handle_patrol() -> void:
	if in_idle_pause:
		velocity.x = 0
		return

	# Pula alternando direção
	if is_on_floor() and can_jump:
		velocity.x = direction * SPEED
		velocity.y = JUMP_FORCE
		update_flip(direction)
		can_jump = false
		await get_tree().create_timer(0.8).timeout
		can_jump = true

	# Pausa aleatória entre pulos
	if randf() < 0.01 and is_on_floor():
		in_idle_pause = true
		await get_tree().create_timer(idle_time).timeout
		in_idle_pause = false
		direction *= -1  # Vira após pausa

	# Detecta o player
	if player and global_position.distance_to(player.global_position) <= detection_range:
		current_state = State.CHASING


# ----------------------------------------------------------
func handle_chasing() -> void:
	if not player:
		current_state = State.PATROL
		return

	var distance = global_position.distance_to(player.global_position)
	var dir = sign(player.global_position.x - global_position.x)
	update_flip(dir)

	# Pula em direção ao player
	if is_on_floor() and can_jump:
		velocity.x = dir * SPEED * 1.2
		velocity.y = JUMP_FORCE * 1.2
		can_jump = false
		await get_tree().create_timer(1.0).timeout
		can_jump = true

	# Sai do modo perseguição se o player se afastar
	if distance > detection_range * 1.5:
		current_state = State.PATROL


# ----------------------------------------------------------
func update_flip(dir: float) -> void:
	if not animated_sprite:
		return
	animated_sprite.flip_h = dir < 0 if flip_left_when_moving_left else dir > 0


# ----------------------------------------------------------
func update_animation() -> void:
	if is_dead:
		return

	if not is_on_floor():
		animated_sprite.play("Jump")
	elif abs(velocity.x) > 10:
		animated_sprite.play("Walk")
	else:
		animated_sprite.play("Idle")


# ----------------------------------------------------------
func take_damage() -> void:
	if is_dead:
		return

	life -= 1
	if blood_particles:
		blood_particles.emitting = true

	# Flash vermelho rápido
	animated_sprite.modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = Color(1, 1, 1)

	if blood_particles:
		blood_particles.emitting = false

	if life <= 0:
		die()


# ----------------------------------------------------------
func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO

	if animated_sprite:
		animated_sprite.play("Death")

	if hit_area:
		hit_area.monitoring = false
	if damage_area:
		damage_area.monitoring = false

	await get_tree().create_timer(1.0).timeout
	queue_free()


# ----------------------------------------------------------
# Player pisa no sapo → sapo leva dano
func _on_hit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_dead:
		take_damage()
		# Se o player tiver método de "bounce", faz ele quicar
		if body.has_method("bounce"):
			body.bounce()


# ----------------------------------------------------------
# Player encosta no sapo → player leva dano
func _on_damage_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_dead:
		if body.has_method("take_damage"):
			body.take_damage(1)
