class_name PlayerAnimais
extends CharacterBody2D

# Estados do jogo
enum State { IDLE, WALK, JUMP, FALL, ATTACK, SWIM, TRANSFORM, DEAD }

# Formas animais
enum Forma { 
	JACARE = 0,  # Transformacao 1 (Q)
	COBRA = 1,   # Transformacao 2 (W)
	ONCA = 2,    # Transformacao 3 (E)
	CAVALO = 3   # Transformacao 4 (R)
}

# ===== CONFIGURAÇÕES EXPORTADAS =====

@export_group("Movement")
@export var speed: float = 150.0
@export var jump_force: float = -350.0
@export var gravity: float = 900.0

@export_group("Water Physics")
@export var in_water: bool = false
@export var swim_speed_multiplier: float = 0.7

@export_group("Transform")
@export var transform_duration: float = 0.8

@export_group("Attack")
@export var attack_duration: float = 0.4  # ✅ NOVO: Duração do ataque
@export var attack_area: Area2D  # ✅ NOVO: Área de ataque (Stomper)

# ===== REFERÊNCIAS (busca automaticamente) =====

@export var animated_sprite: AnimatedSprite2D
@export var stats: Node

# ===== ESTADO ATUAL =====

var state: State = State.IDLE
var forma: Forma = Forma.JACARE
var target_forma: Forma = Forma.JACARE

# ✅ Timers
var transform_timer: float = 0.0
var is_transforming: bool = false

var attack_timer: float = 0.0  # ✅ NOVO: Timer de ataque
var is_attacking: bool = false  # ✅ NOVO: Flag de ataque

# ===== FORMAS DESBLOQUEADAS =====

var formas_desbloqueadas := {
	Forma.JACARE: true,
	Forma.COBRA: false,
	Forma.ONCA: false,
	Forma.CAVALO: false
}

# ===== ESTATÍSTICAS POR FORMA =====

var forma_speeds := {
	Forma.JACARE: 120.0,
	Forma.COBRA: 140.0,
	Forma.ONCA: 180.0,
	Forma.CAVALO: 200.0
}

var forma_jumps := {
	Forma.JACARE: -300.0,
	Forma.COBRA: -250.0,
	Forma.ONCA: -400.0,
	Forma.CAVALO: -380.0
}

var forma_swim_efficiency := {
	Forma.JACARE: 1.2,
	Forma.COBRA: 0.9,
	Forma.ONCA: 0.6,
	Forma.CAVALO: 0.5
}

# ===== INICIALIZAÇÃO =====

func _ready() -> void:
	add_to_group("player")
	
	# Validação
	if not animated_sprite:
		push_error("AnimatedSprite2D não encontrado!")
	if not stats:
		push_error("Stats não encontrado!")
	
	# ✅ NOVO: Busca attack_area se não definida
	if not attack_area:
		attack_area = get_node_or_null("../Stomper")
		if attack_area:
			print("✅ Attack Area encontrada automaticamente: Stomper")
		else:
			push_warning("⚠️ Attack Area não encontrada! Ataque não causará dano.")
	
	# ✅ NOVO: Desativa attack_area no início
	if attack_area:
		attack_area.monitoring = false
		attack_area.add_to_group("killer")  # Grupo para matar inimigos
	
	# Conecta signals do AnimatedSprite2D
	if animated_sprite and not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	print("🐊 Player Animais inicializado!")
	print("  Forma inicial: %s" % Forma.keys()[forma])
	update_stats_by_forma()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	
	# ✅ NOVO: Timer de ataque
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			complete_attack()
	
	# Timer de transformação
	if is_transforming:
		transform_timer -= delta
		if transform_timer <= 0:
			complete_transform()
	
	# Aplica gravidade (exceto se nadando)
	if not in_water or state != State.SWIM:
		if not is_on_floor():
			velocity.y += gravity * delta
	
	# Processa estado atual
	handle_input()
	handle_state(delta)
	update_animation()
	
	move_and_slide()

# ===== INPUT =====

func handle_input() -> void:
	"""Processa inputs do jogador"""
	
	# Não aceita input se morto ou transformando
	if state in [State.DEAD, State.TRANSFORM]:
		return
	
	# ✅ CORRIGIDO: Não aceita input durante ataque
	if is_attacking:
		return
	
	# Transformações (Q, W, E, R)
	if Input.is_action_just_pressed("transformacao1"):
		try_transform(Forma.JACARE)
	elif Input.is_action_just_pressed("transformacao2"):
		try_transform(Forma.COBRA)
	elif Input.is_action_just_pressed("transformacao3"):
		try_transform(Forma.ONCA)
	elif Input.is_action_just_pressed("transformacao4"):
		try_transform(Forma.CAVALO)
	
	# Pulo/Nadar para cima
	if Input.is_action_just_pressed("ui_up") and state != State.ATTACK:
		if in_water:
			velocity.y = -150
		elif is_on_floor():
			velocity.y = forma_jumps[forma]
			change_state(State.JUMP)
	
	# ✅ CORRIGIDO: Ataque
	if Input.is_action_just_pressed("attack"):
		start_attack()

# ===== ATAQUE =====

func start_attack() -> void:
	"""Inicia ataque"""
	# Só pode atacar se estiver no chão ou nadando
	if not is_on_floor() and not in_water:
		return
	
	change_state(State.ATTACK)
	velocity.x = 0  # Para de se mover
	
	# ✅ Inicia timer de ataque
	is_attacking = true
	attack_timer = attack_duration
	
	# ✅ Ativa área de ataque
	activate_attack_area()
	
	print("⚔️ Ataque iniciado!")

func complete_attack() -> void:
	"""Completa o ataque"""
	is_attacking = false
	attack_timer = 0.0
	
	# ✅ Desativa área de ataque
	deactivate_attack_area()
	
	# Volta ao estado IDLE
	change_state(State.IDLE)
	
	print("✅ Ataque completo!")

func activate_attack_area() -> void:
	"""Ativa a área de ataque"""
	if not attack_area:
		return
	
	attack_area.monitoring = true
	
	# ✅ Ativa colisão física
	var shape = attack_area.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = false
	
	position_attack_area()
	print("💥 Área de ataque ativada!")



func deactivate_attack_area() -> void:
	"""Desativa a área de ataque"""
	if not attack_area:
		return
	
	attack_area.monitoring = false
	
	# ✅ Desativa colisão física
	var shape = attack_area.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = true
	
	print("🔒 Área de ataque desativada")

func position_attack_area() -> void:
	"""Posiciona a área de ataque na frente do player"""
	if not attack_area or not animated_sprite:
		return
	
	# ✅ Posiciona baseado na direção que está olhando
	var offset_x = 20.0  # Distância na frente
	
	if animated_sprite.flip_h:
		# Olhando para esquerda
		attack_area.position.x = -offset_x
	else:
		# Olhando para direita
		attack_area.position.x = offset_x

# ===== TRANSFORMAÇÕES =====

func try_transform(nova_forma: Forma) -> void:
	"""Tenta transformar em outra forma"""
	if state == State.TRANSFORM:
		return
	
	if forma == nova_forma:
		print("⚠️ Já está em forma %s" % Forma.keys()[nova_forma])
		return
	
	if not formas_desbloqueadas[nova_forma]:
		print("🔒 Forma %s ainda não desbloqueada!" % Forma.keys()[nova_forma])
		return
	
	start_transform(nova_forma)

func start_transform(nova_forma: Forma) -> void:
	"""Inicia processo de transformação"""
	target_forma = nova_forma
	change_state(State.TRANSFORM)
	velocity = Vector2.ZERO
	
	is_transforming = true
	transform_timer = transform_duration
	
	print("✨ Transformando: %s → %s" % [Forma.keys()[forma], Forma.keys()[target_forma]])

func complete_transform() -> void:
	"""Completa a transformação"""
	forma = target_forma
	is_transforming = false
	transform_timer = 0.0
	
	update_stats_by_forma()
	change_state(State.IDLE)
	
	print("✅ Transformação completa! Agora é: %s" % Forma.keys()[forma])

func update_stats_by_forma() -> void:
	"""Atualiza estatísticas baseado na forma atual"""
	speed = forma_speeds[forma]
	jump_force = forma_jumps[forma]
	
	if stats and stats.has_method("update_max_health_by_forma"):
		stats.update_max_health_by_forma(forma)

func desbloquear_forma(nova_forma: Forma) -> void:
	"""Desbloqueia uma nova forma"""
	formas_desbloqueadas[nova_forma] = true
	print("🎉 Nova forma desbloqueada: %s!" % Forma.keys()[nova_forma])

# ===== MÁQUINA DE ESTADOS =====

func handle_state(_delta: float) -> void:
	"""Processa o estado atual"""
	match state:
		State.IDLE:
			idle_state()
		State.WALK:
			walk_state()
		State.JUMP:
			jump_state()
		State.FALL:
			fall_state()
		State.ATTACK:
			attack_state()
		State.SWIM:
			swim_state()
		State.TRANSFORM:
			transform_state()
		State.DEAD:
			dead_state()

func idle_state() -> void:
	"""Estado parado"""
	var input_x = Input.get_axis("ui_left", "ui_right")
	
	if in_water:
		change_state(State.SWIM)
		return
	
	if input_x != 0:
		change_state(State.WALK)
	elif not is_on_floor():
		change_state(State.FALL)

func walk_state() -> void:
	"""Estado andando"""
	var input_x = Input.get_axis("ui_left", "ui_right")
	
	velocity.x = input_x * speed
	
	if input_x != 0 and animated_sprite:
		animated_sprite.flip_h = input_x < 0
	
	if in_water:
		change_state(State.SWIM)
	elif input_x == 0:
		change_state(State.IDLE)
	elif not is_on_floor():
		change_state(State.FALL)

func jump_state() -> void:
	"""Estado pulando"""
	var input_x = Input.get_axis("ui_left", "ui_right")
	velocity.x = input_x * speed
	
	if input_x != 0 and animated_sprite:
		animated_sprite.flip_h = input_x < 0
	
	if in_water:
		change_state(State.SWIM)
	elif velocity.y > 0:
		change_state(State.FALL)
	elif is_on_floor():
		change_state(State.IDLE)

func fall_state() -> void:
	"""Estado caindo"""
	var input_x = Input.get_axis("ui_left", "ui_right")
	velocity.x = input_x * speed
	
	if input_x != 0 and animated_sprite:
		animated_sprite.flip_h = input_x < 0
	
	if in_water:
		change_state(State.SWIM)
	elif is_on_floor():
		change_state(State.IDLE)

func attack_state() -> void:
	"""Estado atacando"""
	velocity.x = 0
	# ✅ O timer cuida de voltar ao IDLE

func swim_state() -> void:
	"""Estado nadando"""
	if not in_water:
		change_state(State.IDLE)
		return
	
	var input_x = Input.get_axis("ui_left", "ui_right")
	
	var input_y = 0.0
	if Input.is_action_pressed("ui_up"):
		input_y = -1.0
	elif Input.is_action_pressed("ui_down"):
		input_y = 1.0
	
	var swim_speed = speed * swim_speed_multiplier * forma_swim_efficiency[forma]
	
	velocity.x = input_x * swim_speed
	velocity.y = input_y * swim_speed * 0.6
	
	velocity *= 0.95
	
	if input_x != 0 and animated_sprite:
		animated_sprite.flip_h = input_x < 0

func transform_state() -> void:
	"""Estado transformando"""
	velocity = Vector2.ZERO

func dead_state() -> void:
	"""Estado morto"""
	velocity = Vector2.ZERO

func change_state(new_state: State) -> void:
	"""Muda o estado"""
	if state == new_state:
		return
	
	state = new_state
	
	if OS.is_debug_build():
		print("🔄 Estado: %s" % State.keys()[state])

# ===== ANIMAÇÕES =====

func update_animation() -> void:
	"""Atualiza animação baseada no estado e forma"""
	if not animated_sprite:
		return
	
	var anim_name = get_animation_name()
	
	if animated_sprite.animation != anim_name:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)
		else:
			if "transform" in anim_name or "attack" in anim_name:
				var fallback_anim = get_forma_prefix() + "idle"
				if animated_sprite.sprite_frames.has_animation(fallback_anim):
					animated_sprite.play(fallback_anim)
			else:
				push_warning("Animação '%s' não existe!" % anim_name)

func get_animation_name() -> String:
	"""Retorna o nome da animação baseado em estado e forma"""
	var forma_prefix = get_forma_prefix()
	
	match state:
		State.IDLE:
			return forma_prefix + "idle"
		State.WALK:
			return forma_prefix + "walk"
		State.JUMP:
			return forma_prefix + "jump"
		State.FALL:
			return forma_prefix + "fall"
		State.ATTACK:
			return forma_prefix + "attack"
		State.SWIM:
			return forma_prefix + "swim"
		State.TRANSFORM:
			return get_transform_animation()
		State.DEAD:
			return forma_prefix + "dead"
		_:
			return forma_prefix + "idle"

func get_forma_prefix() -> String:
	"""Retorna prefixo da forma atual"""
	match forma:
		Forma.JACARE:
			return "jacare_"
		Forma.COBRA:
			return "cobra_"
		Forma.ONCA:
			return "onca_"
		Forma.CAVALO:
			return "cavalo_"
		_:
			return "jacare_"

func get_transform_animation() -> String:
	"""Retorna animação de transformação"""
	var from_name = Forma.keys()[forma].to_lower()
	var to_name = Forma.keys()[target_forma].to_lower()
	return "transform_%s_to_%s" % [from_name, to_name]

func _on_animation_finished() -> void:
	"""Callback quando animação termina"""
	# ✅ NOTA: Ataque e Transformação não dependem mais deste signal
	# Eles usam timers independentes
	pass

# ===== DEBUG =====

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	
	if event.is_action_pressed("ui_text_backspace"):
		desbloquear_todas_formas()
	
	if event.is_action_pressed("ui_home"):
		print_debug_info()

func desbloquear_todas_formas() -> void:
	"""DEBUG: Desbloqueia todas as transformações"""
	for forma_key in Forma.values():
		formas_desbloqueadas[forma_key] = true
	print("🔓 [DEBUG] Todas as formas desbloqueadas!")

func print_debug_info() -> void:
	"""DEBUG: Mostra informações do player"""
	#print("=" * 50)
	print("🐾 PLAYER ANIMAIS DEBUG")
	print("  Estado: %s" % State.keys()[state])
	print("  Forma: %s" % Forma.keys()[forma])
	if stats and "current_health" in stats:
		print("  Vida: %d/%d" % [stats.current_health, stats.max_health])
	print("  Velocidade: %.1f" % speed)
	print("  Na água: %s" % in_water)
	print("  Transformando: %s" % is_transforming)
	print("  Atacando: %s" % is_attacking)
	if is_transforming:
		print("  Timer transformação: %.2fs" % transform_timer)
	if is_attacking:
		print("  Timer ataque: %.2fs" % attack_timer)
	print("  Attack Area: %s" % ("✅" if attack_area else "❌"))
	print("  Formas desbloqueadas:")
	for forma_key in Forma.values():
		var desbloqueado = formas_desbloqueadas[forma_key]
		var status = "✅" if desbloqueado else "🔒"
		print("    %s %s" % [status, Forma.keys()[forma_key]])
	#print("=" * 50)

# ===== HELPERS =====

func get_forma_name() -> String:
	"""Retorna nome da forma atual"""
	return Forma.keys()[forma]

func is_forma_desbloqueada(check_forma: Forma) -> bool:
	"""Verifica se uma forma está desbloqueada"""
	return formas_desbloqueadas[check_forma]
