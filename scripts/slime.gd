extends CharacterBody2D

# Referências
@onready var animation_sprite = $AnimatedSprite2D
@onready var particles = $CPUParticles2D
@onready var hit_area = $Hit
@onready var raycast_right: RayCast2D = get_node_or_null("RaycastRight")
@onready var raycast_left: RayCast2D = get_node_or_null("RaycastLeft")

# Configurações de movimento
@export_group("Movement")
@export var patrol_speed: float = 20.0
@export var chase_speed: float = 40.0
@export var jump_force: float = -250.0
@export var gravity_strength: float = 900.0

# Configurações de IA
@export_group("AI")
@export var detection_range: float = 100.0
@export var stop_chase_distance: float = 10.0
@export var use_raycast_detection: bool = true
@export var detect_ledges: bool = true  # ✅ ATIVADO por padrão agora

# Estado
var player: Node2D = null
var is_chasing: bool = false
var move_direction: float = 1.0
var is_dead: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_warning("Slime: Player não encontrado no grupo 'player'")
	
	# Validação
	assert(animation_sprite != null, "AnimatedSprite2D não encontrado!")
	assert(hit_area != null, "Hit area não encontrada!")
	
	# ✅ Configurar Raycasts se não existirem
	setup_edge_detection()

func setup_edge_detection() -> void:
	"""Configura detecção de bordas automaticamente"""
	if detect_ledges:
		# Se não tem raycasts, cria automaticamente
		if not raycast_right:
			raycast_right = create_edge_raycast("RaycastRight", Vector2(12, 0))
		
		if not raycast_left:
			raycast_left = create_edge_raycast("RaycastLeft", Vector2(-12, 0))
		
		# Configura os raycasts existentes
		if raycast_right:
			configure_raycast(raycast_right, Vector2(15, 20))
		
		if raycast_left:
			configure_raycast(raycast_left, Vector2(-15, 20))
		
		print("✅ Slime: Detecção de bordas configurada")

func create_edge_raycast(raycast_name: String, offset: Vector2) -> RayCast2D:
	"""Cria um raycast para detecção de bordas"""
	var raycast = RayCast2D.new()
	raycast.name = raycast_name
	raycast.position = offset
	raycast.enabled = true
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	raycast.collision_mask = 1  # Layer 1 = chão
	add_child(raycast)
	return raycast

func configure_raycast(raycast: RayCast2D, target_pos: Vector2) -> void:
	"""Configura um raycast existente"""
	raycast.enabled = true
	raycast.target_position = target_pos
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	raycast.collision_mask = 1  # Layer 1 = chão
	raycast.exclude_parent = false

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Aplica gravidade
	if not is_on_floor():
		velocity.y += gravity_strength * delta
	
	# IA: Patrulha ou Perseguição
	if player:
		update_ai()
	else:
		patrol()
	
	handle_animation()
	
	move_and_slide()

func update_ai() -> void:
	"""Atualiza comportamento baseado na distância do player"""
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Verifica se deve perseguir
	if distance_to_player <= detection_range:
		if use_raycast_detection and not can_see_player():
			is_chasing = false
			patrol()
		else:
			is_chasing = true
			chase_player()
	else:
		is_chasing = false
		patrol()

func can_see_player() -> bool:
	"""Verifica se tem linha de visão para o player (sem paredes)"""
	if not player:
		return false
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)
	query.exclude = [self]
	query.collision_mask = 1  # Layer das paredes
	
	var result = space_state.intersect_ray(query)
	
	# Se não colidiu com nada, tem linha de visão
	return result.is_empty()

func chase_player() -> void:
	"""Persegue o player"""
	var distance = global_position.distance_to(player.global_position)
	
	# Para se muito próximo
	if distance < stop_chase_distance:
		velocity.x = 0
		return
	
	# Calcula direção
	var direction = sign(player.global_position.x - global_position.x)
	
	# Move em direção ao player
	velocity.x = direction * chase_speed
	update_flip(direction)
	
	# Pula se encontrar parede enquanto persegue
	if is_on_wall() and is_on_floor():
		velocity.y = jump_force

func patrol() -> void:
	"""Patrulha indo e voltando"""
	# Move na direção atual
	velocity.x = move_direction * patrol_speed
	update_flip(move_direction)
	
	# Inverte direção ao encontrar parede
	if is_on_wall():
		move_direction *= -1
		# Pula ao encontrar parede
		if is_on_floor():
			velocity.y = jump_force
	
	# ✅ Detecta borda (se detect_ledges ativo)
	if detect_ledges and is_on_floor():
		check_ledges()

func check_ledges() -> void:
	"""Detecta bordas usando raycasts"""
	# ✅ Melhorado: Verifica se raycasts existem E estão colidindo
	if move_direction > 0:  # Indo para direita
		if raycast_right and not raycast_right.is_colliding():
			# Não há chão à direita = BORDA!
			move_direction *= -1
			if is_on_floor():
				velocity.y = jump_force  # Pula ao inverter
	
	elif move_direction < 0:  # Indo para esquerda
		if raycast_left and not raycast_left.is_colliding():
			# Não há chão à esquerda = BORDA!
			move_direction *= -1
			if is_on_floor():
				velocity.y = jump_force  # Pula ao inverter

func update_flip(direction: float) -> void:
	"""Vira o sprite baseado na direção"""
	if direction > 0:
		animation_sprite.flip_h = true
	elif direction < 0:
		animation_sprite.flip_h = false

func handle_animation() -> void:
	"""Gerencia animações"""
	if is_dead:
		return
	
	if not is_on_floor():
		animation_sprite.play("fall")
	elif abs(velocity.x) > 0:
		animation_sprite.play("walk")
	else:
		animation_sprite.play("idle")

func take_damage() -> void:
	"""Lida com morte do slime"""
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	
	# Desativa colisão
	if hit_area:
		hit_area.set_deferred("monitoring", false)
	
	# Efeito visual
	animation_sprite.visible = false
	if particles:
		particles.emitting = true
	
	# Remove após partículas
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _on_hit_area_entered(area: Area2D) -> void:
	"""Detecta ataque do player"""
	if area.is_in_group("stomper"):
		take_damage()
