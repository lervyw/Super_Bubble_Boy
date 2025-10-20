extends CharacterBody2D

# Referências dos nós (configuráveis no Inspector)
@onready var animated_sprite = $AnimatedSprite2D
@onready var blood_particles = $CPUParticles2D

# ⚙️ CONFIGURE AQUI NO INSPECTOR ⚙️
@export var hit_area: Area2D  # Area2D que detecta pisadas do player
@export var damage_area: Area2D  # Area2D que causa dano ao player

# Constantes de movimento
@export_group("Movement Settings")
@export var SPEED = 120.0
@export var JUMP_FORCE = -350.0
@export var GRAVITY = 980.0

# Variáveis do boss
@export_group("Boss Settings")
@export var life = 5
@export var detection_range = 400.0  # Distância para começar a perseguir
@export var attack_range = 80.0  # Distância para atacar
@export var flip_left_when_moving_left = true  # Se true: vira para esquerda quando vai para esquerda

var player = null
var is_dead = false
var can_attack = true

# Estados do boss
enum State { IDLE, CHASING, ATTACKING, HURT }
var current_state = State.IDLE

func _ready():
	# Conecta sinais apenas se os nós existirem
	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)
	else:
		push_warning("HitArea não configurada! Arraste o nó Area2D no Inspector.")
	
	if damage_area:
		damage_area.body_entered.connect(_on_damage_area_body_entered)
	else:
		push_warning("DamageArea não configurada! Arraste o nó Area2D no Inspector.")
	
	# Procura o player
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dead:
		return
	
	# Aplica gravidade
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# Executa comportamento baseado no estado
	match current_state:
		State.IDLE:
			handle_idle()
		State.CHASING:
			handle_chasing()
		State.ATTACKING:
			handle_attacking()
		State.HURT:
			handle_hurt()
	
	# Move o boss
	move_and_slide()
	
	# Atualiza animação
	update_animation()

func handle_idle():
	velocity.x = 0
	
	# Procura o player se não encontrou ainda
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return
	
	# Se o player está próximo, começa a perseguir
	var distance = global_position.distance_to(player.global_position)
	if distance < detection_range:
		current_state = State.CHASING

func handle_chasing():
	if player == null:
		current_state = State.IDLE
		return
	
	# Calcula direção até o player
	var direction = sign(player.global_position.x - global_position.x)
	var distance = global_position.distance_to(player.global_position)
	
	# Move em direção ao player
	velocity.x = direction * SPEED
	
	# Vira o sprite
	if direction != 0:
		update_flip(direction)
	
	# Se chegou perto, ataca
	if distance < attack_range and can_attack:
		current_state = State.ATTACKING
	
	# Pula se encontrar obstáculo ou se o player estiver acima
	if is_on_floor() and should_jump():
		velocity.y = JUMP_FORCE

func handle_attacking():
	velocity.x = 0
	can_attack = false
	
	# Toca animação de ataque
	animated_sprite.play("Attack")
	await animated_sprite.animation_finished
	
	# Cooldown de ataque
	await get_tree().create_timer(1.0).timeout
	can_attack = true
	current_state = State.CHASING

func handle_hurt():
	# Estado de stun quando leva dano
	velocity.x = 0
	await get_tree().create_timer(0.3).timeout
	
	if not is_dead:
		current_state = State.CHASING

func move(direction: float, speed: float):
	velocity.x = direction * speed
	if direction != 0:
		update_flip(direction)

func update_flip(direction: float):
	"""Vira o sprite baseado na direção do movimento"""
	if not animated_sprite:
		return
	
	if flip_left_when_moving_left:
		# Vira para esquerda quando direction < 0
		animated_sprite.flip_h = (direction > 0)
	else:
		# Vira para direita quando direction > 0
		animated_sprite.flip_h = (direction < 0)

func should_jump() -> bool:
	# Verifica se deve pular (player está acima ou há obstáculo)
	if player == null:
		return false
	
	var player_is_above = player.global_position.y < global_position.y - 50
	return player_is_above

func update_animation():
	if is_dead or current_state == State.ATTACKING:
		return
	
	if not is_on_floor():
		animated_sprite.play("Fall")
	elif abs(velocity.x) > 10:
		animated_sprite.play("Walk")
	else:
		animated_sprite.play("Idle")

func check_for_self(node):
	if node == self:
		return true
	else:
		return false

func random_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_FORCE

func play_attack(body):
	# Função vazia para compatibilidade
	pass

func take_damage():
	if is_dead:
		return
	
	life -= 1
	current_state = State.HURT
	
	# Efeito de sangue
	if blood_particles:
		blood_particles.emitting = true
	
	# Flash vermelho
	if animated_sprite:
		animated_sprite.modulate = Color(1, 0.3, 0.3)
		await get_tree().create_timer(0.1).timeout
		animated_sprite.modulate = Color(1, 1, 1)
	
	# Para o sangue
	await get_tree().create_timer(0.3).timeout
	if blood_particles:
		blood_particles.emitting = false
	
	# Verifica se morreu
	if life <= 0:
		die()

func die():
	is_dead = true
	velocity = Vector2.ZERO
	
	# Efeito de morte
	if blood_particles:
		blood_particles.emitting = true
	
	if animated_sprite:
		animated_sprite.play("Fall")  # Ou crie uma animação "Death"
	
	# Desabilita colisões
	if hit_area:
		hit_area.monitoring = false
	if damage_area:
		damage_area.monitoring = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	# Fade out
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.5)
		await tween.finished
	
	# Vai para os créditos ou remove o boss
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://Cenas/Final_Credits.tscn")
	# Ou use: queue_free()

# Sinal: Quando o player pisa no boss (HitArea)
func _on_hit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_dead:
		take_damage()
		
		# Empurra o player para cima (efeito de pulo)
		if body.has_method("bounce"):
			body.bounce()

# Sinal: Quando o boss encosta no player (DamageArea)
func _on_damage_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_dead:
		# Causa dano ao player
		if body.has_method("take_damage"):
			body.take_damage(1)
		
		# Empurra o player para trás
		var knockback_direction = sign(body.global_position.x - global_position.x)
		if body.has_method("apply_knockback"):
			body.apply_knockback(knockback_direction)
