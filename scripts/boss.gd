extends CharacterBody2D

# Referências
@onready var animation_sprite = $AnimatedSprite2D
@onready var particles = $CPUParticles2D
@onready var hurt_area = $HurtArea  # Detecta ataques do player
@onready var damage_area = $DamageArea  # Causa dano no player

# RayCasts para detecção de bordas e buracos
@onready var edge_detector: RayCast2D
@onready var ground_ahead_detector: RayCast2D

# Configurações
@export_group("Stats")
@export var max_health: int = 5
@export var current_health: int = 5

@export_group("Movement")
@export var patrol_speed: float = 80.0
@export var chase_speed: float = 160.0
@export var jump_force: float = -400.0
@export var gravity_strength: float = 900.0

@export_group("AI")
@export var detection_range: float = 80.0
@export var attack_range: float = 50.0
@export var jump_interval: float = 2.0  # Pula a cada 2 segundos

@export_group("Jump Pattern")
@export var jumps_per_combo: int = 3
@export var combo_cooldown: float = 4.0

@export_group("Edge Detection")
@export var edge_check_distance: float = 40.0  # Distância para verificar chão à frente
@export var gap_jump_distance: float = 120.0  # Distância máxima para pular sobre buraco

@export_group("Particles")
@export var particle_duration: float = 2.0  # Duração das partículas após hit

# Estado
enum State { IDLE, PATROL, CHASE, JUMP_ATTACK, HURT, DEAD }
var state: State = State.PATROL

var player: Node2D = null
var move_direction: float = 1.0
var jump_count: int = 0
var is_invincible: bool = false

# Timers internos
var jump_timer: float = 0.0
var combo_timer: float = 0.0
var particle_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_warning("Boss: Player não encontrado!")
	
	# Cria RayCasts programaticamente se não existirem
	setup_raycasts()
	
	# Desliga partículas inicialmente
	if particles:
		particles.emitting = false
	
	print("🦖 Boss spawned! HP: %d/%d" % [current_health, max_health])

func setup_raycasts() -> void:
	"""Configura raycasts para detecção de bordas"""
	# RayCast para detectar borda (aponta para baixo, à frente)
	if not has_node("EdgeDetector"):
		edge_detector = RayCast2D.new()
		edge_detector.name = "EdgeDetector"
		add_child(edge_detector)
		edge_detector.target_position = Vector2(edge_check_distance, 50)  # Para frente e para baixo
		edge_detector.enabled = true
		edge_detector.collision_mask = 1  # Layer do chão
	else:
		edge_detector = $EdgeDetector
	
	# RayCast para detectar chão à frente (mais longe)
	if not has_node("GroundAheadDetector"):
		ground_ahead_detector = RayCast2D.new()
		ground_ahead_detector.name = "GroundAheadDetector"
		add_child(ground_ahead_detector)
		ground_ahead_detector.target_position = Vector2(gap_jump_distance, 50)
		ground_ahead_detector.enabled = true
		ground_ahead_detector.collision_mask = 1
	else:
		ground_ahead_detector = $GroundAheadDetector

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	
	# Aplica gravidade
	if not is_on_floor():
		velocity.y += gravity_strength * delta
	
	# Atualiza timers
	jump_timer -= delta
	combo_timer -= delta
	
	# Sistema de partículas temporárias
	if particle_timer > 0:
		particle_timer -= delta
		if particle_timer <= 0 and particles:
			particles.emitting = false
	
	# Atualiza direção dos raycasts baseado na direção do movimento
	update_raycast_direction()
	
	# Máquina de estados
	match state:
		State.IDLE:
			idle_state()
		State.PATROL:
			patrol_state()
		State.CHASE:
			chase_state()
		State.JUMP_ATTACK:
			jump_attack_state()
		State.HURT:
			hurt_state()
	
	# Animações
	handle_animation()
	
	move_and_slide()

func update_raycast_direction() -> void:
	"""Atualiza direção dos raycasts baseado no movimento"""
	if edge_detector:
		edge_detector.target_position = Vector2(edge_check_distance * move_direction, 50)
	if ground_ahead_detector:
		ground_ahead_detector.target_position = Vector2(gap_jump_distance * move_direction, 50)

func check_edge_ahead() -> bool:
	"""Verifica se há uma borda/buraco à frente"""
	if not edge_detector:
		return false
	
	# Se o raycast NÃO está colidindo, significa que há um buraco
	return not edge_detector.is_colliding()

func check_gap_jumpable() -> bool:
	"""Verifica se há chão após o buraco (para pular)"""
	if not ground_ahead_detector:
		return false
	
	# Se este raycast colide, há chão do outro lado
	return ground_ahead_detector.is_colliding()

func idle_state() -> void:
	"""Boss parado pensando"""
	velocity.x = 0
	
	if player and global_position.distance_to(player.global_position) < detection_range:
		change_state(State.CHASE)
	else:
		# Volta a patrulhar após 1 segundo
		await get_tree().create_timer(1.0).timeout
		if state == State.IDLE:
			change_state(State.PATROL)

func patrol_state() -> void:
	"""Patrulha indo e voltando com detecção de bordas"""
	velocity.x = move_direction * patrol_speed
	update_flip(move_direction)
	
	# Verifica borda à frente
	if is_on_floor() and check_edge_ahead():
		# Há um buraco! Verifica se pode pular
		if check_gap_jumpable():
			# Tem chão do outro lado, pula!
			print("🦖 Boss: Pulando sobre buraco!")
			velocity.y = jump_force
		else:
			# Buraco muito grande, inverte direção
			print("🦖 Boss: Buraco detectado, virando!")
			move_direction *= -1
	
	# Inverte ao encontrar parede
	if is_on_wall():
		move_direction *= -1
	
	# Persegue se detectar player
	if player and global_position.distance_to(player.global_position) < detection_range:
		change_state(State.CHASE)

func chase_state() -> void:
	"""Persegue o player"""
	if not player:
		change_state(State.PATROL)
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Muito perto? Ataca!
	if distance < attack_range:
		change_state(State.JUMP_ATTACK)
		return
	
	# Muito longe? Para de perseguir
	if distance > detection_range * 1.5:
		change_state(State.PATROL)
		return
	
	# Move em direção ao player
	var direction = sign(player.global_position.x - global_position.x)
	move_direction = direction  # Atualiza direção para os raycasts
	velocity.x = direction * chase_speed
	update_flip(direction)
	
	# Verifica borda durante perseguição
	if is_on_floor() and check_edge_ahead():
		if check_gap_jumpable():
			# Pula para continuar perseguição
			velocity.y = jump_force
		else:
			# Buraco muito grande, desiste da perseguição
			change_state(State.PATROL)
			return
	
	# Pula se encontrar parede
	if is_on_wall() and is_on_floor():
		velocity.y = jump_force

func jump_attack_state() -> void:
	"""Combo de pulos agressivos"""
	# Executa combo de pulos
	if jump_count < jumps_per_combo and combo_timer <= 0:
		if is_on_floor() and jump_timer <= 0:
			perform_jump()
			jump_timer = jump_interval
	
	# Move levemente em direção ao player durante pulos
	if player:
		var direction = sign(player.global_position.x - global_position.x)
		move_direction = direction
		velocity.x = direction * (chase_speed * 0.5)
		update_flip(direction)
	
	# Terminou combo?
	if jump_count >= jumps_per_combo:
		jump_count = 0
		combo_timer = combo_cooldown
		change_state(State.IDLE)

func hurt_state() -> void:
	"""Boss tomou dano"""
	velocity.x = 0
	
	# Retorna ao estado anterior após animação
	await get_tree().create_timer(0.5).timeout
	if state == State.HURT:
		change_state(State.CHASE if player else State.PATROL)

func perform_jump() -> void:
	"""Executa um pulo"""
	velocity.y = jump_force
	jump_count += 1
	print("🦖 Boss pulo %d/%d" % [jump_count, jumps_per_combo])

func take_damage(amount: int = 1) -> void:
	"""Boss toma dano"""
	if is_invincible or state == State.DEAD:
		return
	
	current_health -= amount
	print("🦖 Boss HP: %d/%d (-%d)" % [current_health, max_health, amount])
	
	# Efeito visual com partículas temporárias
	if particles:
		particles.emitting = true
		particle_timer = particle_duration  # Partículas por X segundos
	
	# Knockback
	if player:
		var knockback_dir = sign(global_position.x - player.global_position.x)
		velocity.x = knockback_dir * 200
		velocity.y = -100
	
	# Verifica morte
	if current_health <= 0:
		die()
	else:
		# Invencibilidade temporária
		is_invincible = true
		change_state(State.HURT)
		
		await get_tree().create_timer(1.0).timeout
		is_invincible = false

func die() -> void:
	"""Boss morre - VITÓRIA!"""
	state = State.DEAD
	velocity = Vector2.ZERO
	
	print("🎉 Boss derrotado!")
	
	# Desativa colisões
	if hurt_area:
		hurt_area.monitoring = false
	if damage_area:
		damage_area.monitoring = false
	
	# Animação épica de morte
	animation_sprite.play("death")  # Criar essa animação!
	
	# Efeito visual máximo
	if particles:
		particles.emitting = true
		particles.amount = 50
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(animation_sprite, "modulate:a", 0.0, 1.0)
	
	await get_tree().create_timer(2.0).timeout
	
	# Transição épica para créditos
	get_tree().change_scene_to_file("res://Cenas/Final_Credits.tscn")

func change_state(new_state: State) -> void:
	"""Troca de estado"""
	var old_state = State.keys()[state]
	state = new_state
	var new_state_name = State.keys()[new_state]
	print("🦖 Boss: %s → %s" % [old_state, new_state_name])

func update_flip(direction: float) -> void:
	"""Vira o sprite"""
	if direction > 0:
		animation_sprite.flip_h = false
	elif direction < 0:
		animation_sprite.flip_h = true

func handle_animation() -> void:
	"""Gerencia animações"""
	match state:
		State.DEAD:
			return  # Animação de morte já tocando
		
		State.HURT:
			animation_sprite.play("hurt")
		
		State.JUMP_ATTACK:
			if not is_on_floor():
				animation_sprite.play("jump")
			else:
				animation_sprite.play("idle")
		
		_:
			if not is_on_floor():
				animation_sprite.play("fall")
			elif abs(velocity.x) > 0:
				animation_sprite.play("walk")
			else:
				animation_sprite.play("idle")

# ===== CALLBACKS =====

func _on_hurt_area_area_entered(area: Area2D) -> void:
	"""Boss recebe ataque do player"""
	if area.is_in_group("killer"):
		take_damage(1)

func _on_damage_area_body_entered(body: Node2D) -> void:
	"""Boss causa dano no player"""
	if body.is_in_group("player") and body.has_method("take_damage"):
		# Player deve ter um método take_damage ou conectar ao stats
		pass  # O sistema de dano do player já funciona via Area2D "ebody"
