# Player.gd
extends CharacterBody2D
# =========================================================
#  PLAYER CONTROLLER
#  - Máquina de estados (idle/walk/jump/attack/dash/etc)
#  - Formas (normal/bubble/super)
#  - Dois modos de jogo (Plataforma vs Metroidvania)
#  - Dano, invencibilidade, respawn e morte
#  - Combos, ataque especial, defesa
# =========================================================


# ==========================
# ====== ENUMS / EXPORTS ===
# ==========================
# Estados da máquina (o que o player está fazendo)
enum State {
	IDLE, WALK, JUMP, ATTACK, CROUCH, DASH, TRANSFORM, DEAD, SWIM, SPECIAL_ATTACK, DEFEND
}

# Formas do player (afeta gravidade, pulo, etc)
enum Form { NORMAL, BUBBLE, SUPER }

# Regras do jogo (Plataforma = vidas, Metroidvania = HP)
enum GameMode { PLATAFORMA, METROIDVANIA }

# Parâmetros principais de movimento e referências de nodes
@export var speed := 150.0
@export var jump_force := -450.0
@export var super_jump_force := -350.0
@export var gravity := 900.0
@export var dash_speed := 400.0
@export var dash_time := 0.2
@export var animation_player: AnimationPlayer
@export var audio_normal: AudioStreamPlayer
@export var audio_super: AudioStreamPlayer
@export var hud: CanvasLayer

# Ajustes de morte
@export_group("Death Settings")
@export_range(0.0, 5.0) var death_delay: float = 1.0

# Ajustes do dash
@export_group("Dash Settings")
@export var dash_stops_fall: bool = false            # se true, dash não cai
@export_range(0.0, 1.0) var dash_fall_factor: float = 0.3  # quão lenta é a queda no dash
@export_range(0.0, 2.0) var dash_cooldown: float = 0.3     # tempo mínimo entre dashes

# Ajustes de dano
@export_group("Damage Settings")
@export_range(0.0, 5.0) var invincibility_time: float = 1.0  # tempo imune após tomar hit

# Spawn/checkpoint + stats (HP, etc)
@export var respawn_position: Vector2 = Vector2(288, 207)
@export var stats: Node = null


# ==========================
# ====== NODES ONREADY =====
# ==========================
# Área de ataque: liga/desliga colisão para acertar inimigos
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D


# ==========================
# ====== STATE VARS ========
# ==========================
# Timers e flags gerais de gameplay
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var on_ground := false

# Estado atual + forma atual
var form: Form = Form.NORMAL
var state: State = State.IDLE

# Flags contextuais
var in_water: bool = false
var target_form: Form = Form.NORMAL
var is_bouncing_from_enemy := false

# Sistema simples de combo/defesa
var combo_lock := false
var defending := false

# Modo de jogo atual
var mode: GameMode = GameMode.PLATAFORMA

# Quais formas já foram desbloqueadas
var unlocked_forms = {
	Form.NORMAL: true,
	Form.BUBBLE: false,
	Form.SUPER: false
}

# Controle de “multi-pulos” da forma bolha
var bubble_jump_count := 0
var max_bubble_jumps := 40

# Invencibilidade temporária após dano/respawn
var is_invincible: bool = false


# ==============================
# ========= READY ==============
# ==============================
func _ready() -> void:
	# Conecta sinal custom do Sprite2D para saber quando a animação de ataque terminou
	if $Sprite2D and $Sprite2D.has_signal("attack_finished"):
		# Garante que o método exista (evita crash por nome errado)
		if not has_method("_on_attack_finished"):
			push_error("Player: método _on_attack_finished não encontrado!")
		else:
			$Sprite2D.attack_finished.connect(_on_attack_finished)

	# Começa com hitbox de ataque desligada
	if attack_collision:
		attack_collision.disabled = true

	# Conecta “hurtbox” (detecção de dano) se o nó existir
	if has_node("Hurtbox"):
		var hurtbox = $Hurtbox
		if hurtbox and not hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
			hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	# Ajusta áudio conforme forma inicial
	update_audio_by_form()


# ==============================
# ===== INPUT GLOBAL (HUD etc)
# ==============================
func _input(event):
	# Abre/fecha HUD menu enquanto segura a ação
	if event.is_action_pressed("hud_menu"):
		hud.show_menu()
	if event.is_action_released("hud_menu"):
		hud.hide_menu()

	# Dispara ataque especial
	if event.is_action_pressed("attack_special"):
		start_special_attack()

	# Liga/desliga defesa (segurar para defender)
	if event.is_action_pressed("defend"):
		start_defense()
	if event.is_action_released("defend"):
		stop_defense()


# ==============================
# ===== PROCESS (não-física)
# ==============================
func _process(delta: float) -> void:
	# Verifica combinações de botões para combos
	check_attack_combos()

	# Seleção rápida de forma (stick/atalho)
	check_quick_form_selection()


# ==============================
# ===== AÇÕES: ESPECIAL/DEFESA
# ==============================
func start_special_attack() -> void:
	# Não deixa iniciar se já estiver atacando/especial/morto
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEAD]:
		return
	state = State.SPECIAL_ATTACK
	activate_attack_area()

func start_defense() -> void:
	# Defesa não funciona morto
	if state == State.DEAD:
		return
	defending = true
	state = State.DEFEND

func stop_defense() -> void:
	# Soltou o botão de defesa → volta ao normal
	defending = false
	if state == State.DEFEND:
		change_state(State.IDLE)


# ==============================
# ===== COMBOS
# ==============================
func check_attack_combos() -> void:
	# Trava combos se já executou um recentemente ou se está morto
	if combo_lock or state == State.DEAD:
		return

	# Combos baseados em pressionar duas ações juntas
	if Input.is_action_pressed("attack") and Input.is_action_pressed("attack_special"):
		execute_combo(1)
	elif Input.is_action_pressed("attack") and Input.is_action_pressed("defend"):
		execute_combo(2)
	elif Input.is_action_pressed("attack_special") and Input.is_action_pressed("defend"):
		execute_combo(3)
	elif Input.is_action_pressed("attack") and Input.is_action_pressed("jump"):
		execute_combo(4)

func execute_combo(id: int) -> void:
	# Trava para não spammar combo
	combo_lock = true
	state = State.ATTACK
	activate_attack_area()
	print("Combo executado:", id)

	# Pequeno cooldown do combo
	await get_tree().create_timer(0.25).timeout
	combo_lock = false


# ==============================
# ===== SELEÇÃO RÁPIDA DE FORMA
# ==============================
func check_quick_form_selection() -> void:
	# Só funciona enquanto segurando "form_select"
	if not Input.is_action_pressed("form_select"):
		return
	# Não troca durante TRANSFORM e só se puder transformar
	if state == State.TRANSFORM or not can_transform():
		return

	# Mapeia direções do stick para cada forma
	if Input.is_action_pressed("right_stick_up"):
		start_transform(Form.BUBBLE)
	elif Input.is_action_pressed("right_stick_right"):
		start_transform(Form.SUPER)
	elif Input.is_action_pressed("right_stick_down"):
		start_transform(Form.NORMAL)


# ==============================
# ===== ESTADOS “TRAVADOS”
# ==============================
func special_attack_state() -> void:
	# No especial, você para o movimento (animação manda)
	velocity = Vector2.ZERO

func defend_state() -> void:
	# Na defesa, você para o movimento (fica “travado defendendo”)
	velocity = Vector2.ZERO


# ==============================
# ===== MODO DE JOGO
# ==============================
func enable_metroidvania_mode() -> void:
	# Metroidvania = HP e habilidades (dash/transform)
	mode = GameMode.METROIDVANIA
	print("🔥 Modo Metroidvania ativado!")
	if stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()

func enable_plataforma_mode() -> void:
	# Plataforma = sistema de vidas (sem HP)
	mode = GameMode.PLATAFORMA
	print("🎮 Modo Plataforma ativado!")
	if stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()

func can_transform() -> bool:
	# Transform só no modo metroidvania e se alguma forma estiver desbloqueada
	if mode != GameMode.METROIDVANIA:
		return false
	return unlocked_forms.get(Form.BUBBLE, false) or unlocked_forms.get(Form.SUPER, false)

func can_dash_global() -> bool:
	# Dash só no modo metroidvania
	return mode == GameMode.METROIDVANIA


# ==============================
# ===== FÍSICA PRINCIPAL
# ==============================
func _physics_process(delta: float) -> void:
	# Reseta flag de bounce para não ficar preso no estado
	if is_bouncing_from_enemy:
		is_bouncing_from_enemy = false

	# Atualiza chão / reset de pulos extras da bolha
	on_ground = is_on_floor()
	if on_ground:
		bubble_jump_count = 0

	# Cooldown do dash
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Aplica física de água ou gravidade normal
	if in_water:
		apply_water_physics(delta)
	else:
		apply_normal_gravity(delta)

	# Inputs e estados
	handle_input()
	handle_state(delta)

	# Move de fato
	move_and_slide()


# ==============================
# ===== INPUT (pulo + formas)
# ==============================
func handle_input() -> void:
	# Pulo sempre pelo "jump"
	if Input.is_action_just_pressed("jump"):
		handle_jump()

	# Troca de forma só no modo metroidvania
	if mode == GameMode.METROIDVANIA:
		if Input.is_action_just_pressed("forma1"):
			toggle_transform(Form.BUBBLE)
		elif Input.is_action_just_pressed("forma2"):
			toggle_transform(Form.SUPER)
		elif Input.is_action_just_pressed("normal"):
			toggle_transform(Form.NORMAL)


# ==============================
# ===== GRAVIDADE / ÁGUA / DASH
# ==============================
func apply_normal_gravity(delta: float) -> void:
	# Durante dash: queda especial (ou zero, se dash_stops_fall)
	if state == State.DASH:
		if dash_stops_fall:
			return
		velocity.y += gravity * dash_fall_factor * delta
		return

	# Gravidade normal (bolha cai bem mais lento)
	if form == Form.BUBBLE:
		velocity.y += 50 * delta
	else:
		velocity.y += gravity * delta

func apply_water_physics(delta: float) -> void:
	# Física simplificada da água: gravidade menor + flutuação + “arrasto”
	var water_grav := 150.0
	match form:
		Form.BUBBLE:
			water_grav = 50.0
		Form.SUPER:
			water_grav = 250.0

	velocity.y += water_grav * delta
	velocity.y -= 80.0 * delta  # buoyancy (empurra pra cima)
	velocity.y *= 0.92          # drag
	velocity.x *= 0.92          # drag


# ==============================
# ===== PULO (por forma)
# ==============================
func handle_jump() -> void:
	match form:
		Form.BUBBLE:
			# Bolha: pulos “curtos” repetíveis (muitos) e pulo diferente na água
			if in_water:
				velocity.y = -100
				bubble_jump_count += 1
			elif bubble_jump_count < max_bubble_jumps:
				velocity.y = -50
				bubble_jump_count += 1

		Form.SUPER:
			# Super: pulo mais controlado (e só do chão fora da água)
			if in_water:
				velocity.y = -120
			elif is_on_floor():
				velocity.y = super_jump_force

		_:
			# Normal: pulo padrão (só do chão fora da água)
			if in_water:
				velocity.y = -150
			elif is_on_floor():
				velocity.y = jump_force


# ==============================
# ===== TRANSFORMAÇÃO
# ==============================
func toggle_transform(target: Form) -> void:
	# Evita troca enquanto já está transformando
	if state == State.TRANSFORM:
		return
	# Só transforma se permitido
	if not can_transform():
		return

	# Se já está na forma escolhida, volta ao NORMAL
	if form == target:
		start_transform(Form.NORMAL)
	# Só permite formas desbloqueadas
	elif unlocked_forms.get(target, false):
		start_transform(target)

func start_transform(new_form: Form) -> void:
	# Entra em estado TRANSFORM e guarda a forma alvo
	state = State.TRANSFORM
	target_form = new_form


# ==============================
# ===== DASH
# ==============================
func can_dash() -> bool:
	# Dash só se o modo permitir e cooldown estiver ok
	if not can_dash_global():
		return false
	return dash_cooldown_timer <= 0


# ==============================
# ===== MÁQUINA DE ESTADOS
# ==============================
func handle_state(delta: float) -> void:
	# Direciona o comportamento baseado no estado atual
	match state:
		State.IDLE: idle_state()
		State.WALK: walk_state()
		State.JUMP: jump_state()
		State.ATTACK: attack_state()
		State.SPECIAL_ATTACK: special_attack_state()
		State.DEFEND: defend_state()
		State.CROUCH: crouch_state()
		State.DASH: dash_state()
		State.TRANSFORM: transform_state()
		State.DEAD: dead_state()
		State.SWIM: swim_state()


# ==============================
# ===== ESTADOS BÁSICOS
# ==============================
func idle_state() -> void:
	# Lê movimento horizontal
	handle_horizontal_input()

	# Transições por input
	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif abs(Input.get_axis("ui_left", "ui_right")) > 0:
		change_state(State.WALK)
	# Ataque só no modo metroidvania
	elif mode == GameMode.METROIDVANIA and Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
		activate_attack_area()
	elif Input.is_action_pressed("crouch"):
		change_state(State.CROUCH)
	elif Input.is_action_just_pressed("dash") and can_dash():
		change_state(State.DASH)

func walk_state() -> void:
	handle_horizontal_input()

	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif mode == GameMode.METROIDVANIA and Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
		activate_attack_area()
	elif Input.is_action_pressed("crouch"):
		change_state(State.CROUCH)
	elif Input.is_action_just_pressed("dash") and can_dash():
		change_state(State.DASH)
	elif velocity.x == 0:
		change_state(State.IDLE)

func jump_state() -> void:
	handle_horizontal_input()

	# Dash no ar, se permitido
	if Input.is_action_just_pressed("dash") and can_dash():
		change_state(State.DASH)

	# Ao tocar o chão, volta para IDLE
	if is_on_floor():
		change_state(State.IDLE)

func attack_state() -> void:
	# Durante ataque normal, trava movimento
	velocity = Vector2.ZERO

func crouch_state() -> void:
	# Agachado: sem movimento horizontal
	velocity.x = 0
	if not Input.is_action_pressed("crouch"):
		change_state(State.IDLE)


# ==============================
# ===== DASH STATE
# ==============================
func dash_state() -> void:
	# Inicializa dash no começo do estado
	if dash_timer <= 0.0:
		dash_timer = dash_time
		dash_cooldown_timer = dash_cooldown

		# Direção do dash: input, ou direção que está olhando se parado
		var dir: int = int(sign(Input.get_axis("ui_left", "ui_right")))
		if dir == 0:
			dir = -1 if $Sprite2D.flip_h else 1

		velocity.x = dir * dash_speed

	# Conta o tempo do dash
	dash_timer -= get_physics_process_delta_time()

	# Ao terminar, volta para IDLE se no chão, senão JUMP
	if dash_timer <= 0:
		if is_on_floor():
			change_state(State.IDLE)
		else:
			change_state(State.JUMP)

func transform_state() -> void:
	# Transformação trava movimento (a troca real provavelmente acontece via animação/outro ponto)
	velocity = Vector2.ZERO

func dead_state() -> void:
	# Estado dead só executa morte (e bloqueia ações)
	die()


# ==============================
# ===== NADO
# ==============================
func swim_state() -> void:
	# Movimento em 2 eixos na água
	var dir_x := Input.get_axis("ui_left", "ui_right")
	var dir_y := Input.get_axis("ui_up", "ui_down")

	# Velocidade na água depende da forma
	var swim_speed := speed * 0.5
	match form:
		Form.NORMAL:
			swim_speed *= 0.6
		Form.BUBBLE:
			swim_speed *= 0.9
		Form.SUPER:
			swim_speed *= 0.5

	velocity.x = dir_x * swim_speed
	velocity.y += dir_y * swim_speed * 0.6

	# Se saiu da água, volta ao idle
	if not in_water:
		change_state(State.IDLE)


# ==============================
# ===== MOVIMENTO HORIZONTAL
# ==============================
func handle_horizontal_input() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")

	# Velocidade base, com ajuste na água por forma
	var current_speed := speed
	if in_water:
		match form:
			Form.NORMAL: current_speed *= 0.6
			Form.BUBBLE: current_speed *= 0.9
			Form.SUPER: current_speed *= 0.5

	velocity.x = dir * current_speed

	# Vira sprite para o lado do movimento
	if dir != 0:
		$Sprite2D.flip_h = dir < 0

func change_state(new_state: State) -> void:
	# Troca simples de estado (sem validações extras)
	state = new_state


# ==============================
# ===== DANO / VIDAS / HP
# ==============================
func take_damage(amount: int = 1) -> void:
	# Ignora hit se invencível ou já morto
	if is_invincible or state == State.DEAD:
		return

	# Modo plataforma: qualquer hit conta como “fatal” (perde vida)
	if mode == GameMode.PLATAFORMA:
		_on_fatal_hit()
		return

	# Modo metroidvania: usa stats/HP
	if stats and stats.has_method("take_damage"):
		stats.take_damage(amount)
		if stats.current_health <= 0:
			_on_fatal_hit()
	else:
		# Sem stats → trata como fatal
		_on_fatal_hit()

	# Invencibilidade após tomar dano (se não morreu)
	if state != State.DEAD:
		start_invincibility()

func start_invincibility() -> void:
	# Liga invencibilidade por tempo
	is_invincible = true

	var tree := get_tree()
	if tree == null:
		is_invincible = false
		return

	var timer := tree.create_timer(invincibility_time)
	if timer == null:
		is_invincible = false
		return

	await timer.timeout
	is_invincible = false

func _on_fatal_hit() -> void:
	# Metroidvania: morte direta quando HP zera
	if mode == GameMode.METROIDVANIA:
		die()
		return

	# Plataforma: perde vida e respawna (ou morre se acabou)
	GameManager.lose_life()
	if GameManager.get_lives() <= 0:
		die()
	else:
		await respawn_player()

func respawn_player() -> void:
	# Respawn no ponto definido
	global_position = respawn_position
	velocity = Vector2.ZERO
	change_state(State.IDLE)

	# Se for metroidvania, restaura HP (se existir)
	if mode == GameMode.METROIDVANIA and stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()

	# Invencibilidade após spawn
	is_invincible = true
	var tree := get_tree()
	if tree:
		var timer := tree.create_timer(invincibility_time)
		if timer:
			await timer.timeout
	is_invincible = false


# ==============================
# ===== ATAQUE (HITBOX)
# ==============================
func activate_attack_area() -> void:
	# Liga colisão do ataque para acertar inimigos
	if attack_collision:
		attack_collision.disabled = false

func deactivate_attack_area() -> void:
	# Desliga colisão do ataque para não acertar fora da animação
	if attack_collision:
		attack_collision.disabled = true

# Chamado pelo Sprite2D quando a animação de ataque termina
func _on_attack_finished() -> void:
	deactivate_attack_area()
	if state != State.DEAD:
		change_state(State.IDLE)


# ==============================
# ===== ÁUDIO POR FORMA
# ==============================
func update_audio_by_form() -> void:
	# Alterna trilha/áudio dependendo da forma
	if not audio_normal or not audio_super:
		return
	match form:
		Form.NORMAL, Form.BUBBLE:
			if audio_super.playing: audio_super.stop()
			if not audio_normal.playing: audio_normal.play()
		Form.SUPER:
			if audio_normal.playing: audio_normal.stop()
			if not audio_super.playing: audio_super.play()


# ==============================
# ===== MORTE / CONTINUE
# ==============================
func die() -> void:
	# Marca estado dead e toca animação
	state = State.DEAD
	if animation_player:
		animation_player.play("Dead")

	# Para totalmente o player
	velocity = Vector2.ZERO

	# Para áudio
	if audio_normal: audio_normal.stop()
	if audio_super: audio_super.stop()

	var tree := get_tree()
	if tree == null:
		# Sem árvore → troca de cena de forma segura (deferred)
		GameManager.call_deferred("goto_continue")
		return

	# Delay para deixar a animação/efeito acontecer
	var timer := tree.create_timer(death_delay)
	if timer == null:
		GameManager.call_deferred("goto_continue")
		return

	await timer.timeout

	# Evita agir se o nó já saiu da cena
	if not is_inside_tree():
		return

	# Vai para tela de continue
	GameManager.goto_continue()


# ==============================
# ===== BOUNCE / HURTBOX
# ==============================
func bounce_from_enemy() -> void:
	# “Quicada” ao acertar inimigo (stomp)
	is_bouncing_from_enemy = true
	velocity.y = -260

func _on_hurtbox_body_entered(body: Area2D) -> void:
	# Se está invencível, ignora qualquer dano
	if is_invincible:
		return

	# Compat: se a área souber causar dano diretamente, ela chama a própria lógica
	if body.has_method("deal_damage_to_player"):
		body.deal_damage_to_player(self)
		return

	# Inimigos comuns
	if body.is_in_group("enemy"):
		take_damage(1)
		return

	# Boss
	if body.is_in_group("boss"):
		take_damage(1)
		return
