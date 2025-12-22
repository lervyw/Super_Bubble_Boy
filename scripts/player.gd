# Player.gd
extends CharacterBody2D

# ==========================
# ====== ENUMS / EXPORTS ===
# ==========================
enum State {
	IDLE, WALK, JUMP, ATTACK, CROUCH, DASH, TRANSFORM, DEAD, SWIM, SPECIAL_ATTACK, DEFEND
}
enum Form { NORMAL, BUBBLE, SUPER }
enum GameMode { PLATAFORMA, METROIDVANIA }

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
# Itens exportados

@export_group("Death Settings")
@export_range(0.0, 5.0) var death_delay: float = 1.0

@export_group("Dash Settings")
@export var dash_stops_fall: bool = false
@export_range(0.0, 1.0) var dash_fall_factor: float = 0.3
@export_range(0.0, 2.0) var dash_cooldown: float = 0.3

@export_group("Damage Settings")
@export_range(0.0, 5.0) var invincibility_time: float = 1.0

# Referências exportáveis (assigne no nível)
@export var respawn_position: Vector2 = Vector2(288, 207)
@export var stats: Node = null

# ==========================
# ====== NODES ONREADY =====
# ==========================
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

# ==========================
# ====== STATE VARS ========
# ==========================
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var on_ground := false
var form: Form = Form.NORMAL
var state: State = State.IDLE
var in_water: bool = false
var target_form: Form = Form.NORMAL
var is_bouncing_from_enemy := false
var combo_lock := false
var defending := false

var mode: GameMode = GameMode.PLATAFORMA

var unlocked_forms = {
	Form.NORMAL: true,
	Form.BUBBLE: false,
	Form.SUPER: false
}

var bubble_jump_count := 0
var max_bubble_jumps := 40

var is_invincible: bool = false

# ==============================
# ========= READY ==============
# ==============================
func _ready() -> void:

	# Conecta sinal de fim de animação do sprite -> _on_attack_finished
	if $Sprite2D and $Sprite2D.has_signal("attack_finished"):
		# assegura que método exista (foi erro antes)
		if not has_method("_on_attack_finished"):
			push_error("Player: método _on_attack_finished não encontrado!")
		else:
			$Sprite2D.attack_finished.connect(_on_attack_finished)

	# Inicializa attack_area
	if attack_collision:
		attack_collision.disabled = true

	# Conecta hurtbox (se existir)
	if has_node("Hurtbox"):
		var hurtbox = $Hurtbox
		if hurtbox and not hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
			hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	update_audio_by_form()
	
# Menu Panel
# Input global (HUD, especiais, defesa, seleção rápida)
func _input(event):

	# HUD
	if event.is_action_pressed("hud_menu"):
		hud.show_menu()
	if event.is_action_released("hud_menu"):
		hud.hide_menu()

	# Ataque especial
	if event.is_action_pressed("attack_special"):
		start_special_attack()

	# Defesa / escudo
	if event.is_action_pressed("defend"):
		start_defense()
	if event.is_action_released("defend"):
		stop_defense()

# Processamento contínuo (combos e seleção de forma)
func _process(delta: float) -> void:
	check_attack_combos()
	check_quick_form_selection()

# Inicia ataque especial
func start_special_attack() -> void:
	if state in [State.ATTACK, State.SPECIAL_ATTACK, State.DEAD]:
		return
	state = State.SPECIAL_ATTACK
	activate_attack_area()

# Inicia defesa
func start_defense() -> void:
	if state == State.DEAD:
		return
	defending = true
	state = State.DEFEND

# Finaliza defesa
func stop_defense() -> void:
	defending = false
	if state == State.DEFEND:
		change_state(State.IDLE)

# Detecta combos de ataque
func check_attack_combos() -> void:
	if combo_lock or state == State.DEAD:
		return

	if Input.is_action_pressed("attack") and Input.is_action_pressed("attack_special"):
		execute_combo(1)

	elif Input.is_action_pressed("attack") and Input.is_action_pressed("defend"):
		execute_combo(2)

	elif Input.is_action_pressed("attack_special") and Input.is_action_pressed("defend"):
		execute_combo(3)

	elif Input.is_action_pressed("attack") and Input.is_action_pressed("jump"):
		execute_combo(4)

# Executa combo
func execute_combo(id: int) -> void:
	combo_lock = true
	state = State.ATTACK
	activate_attack_area()
	print("Combo executado:", id)

	await get_tree().create_timer(0.25).timeout
	combo_lock = false

# Seleção rápida de forma
func check_quick_form_selection() -> void:
	if not Input.is_action_pressed("form_select"):
		return
	if state == State.TRANSFORM or not can_transform():
		return

	if Input.is_action_pressed("right_stick_up"):
		start_transform(Form.BUBBLE)

	elif Input.is_action_pressed("right_stick_right"):
		start_transform(Form.SUPER)

	elif Input.is_action_pressed("right_stick_down"):
		start_transform(Form.NORMAL)

# Estado de ataque especial
func special_attack_state() -> void:
	velocity = Vector2.ZERO

# Estado de defesa
func defend_state() -> void:
	velocity = Vector2.ZERO



# ====== MODO DE JOGO =========
func enable_metroidvania_mode() -> void:
	mode = GameMode.METROIDVANIA
	print("🔥 Modo Metroidvania ativado!")
	if stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()
	# dash habilitado por can_dash() logic

func enable_plataforma_mode() -> void:
	mode = GameMode.PLATAFORMA
	print("🎮 Modo Plataforma ativado!")
	# no modo plataforma, HP não é usado (HUD mostra corações)
	if stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()

func can_transform() -> bool:
	if mode != GameMode.METROIDVANIA:
		return false
	return unlocked_forms.get(Form.BUBBLE, false) or unlocked_forms.get(Form.SUPER, false)

func can_dash_global() -> bool:
	# Dash somente em Metroidvania
	return mode == GameMode.METROIDVANIA

# ====== PHYSICS PROCESS =======
func _physics_process(delta: float) -> void:
	# zera flag de bounce logo depois do frame (evita ficar travado)
	if is_bouncing_from_enemy:
		is_bouncing_from_enemy = false

	on_ground = is_on_floor()
	if on_ground:
		bubble_jump_count = 0

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if in_water:
		apply_water_physics(delta)
	else:
		apply_normal_gravity(delta)

	handle_input()
	handle_state(delta)
	move_and_slide()

# ====== INPUT (APENAS jump) ==
func handle_input() -> void:
	# Pulo SÓ pelo botão "jump"
	if Input.is_action_just_pressed("jump"):
		handle_jump()

	# Transformações apenas em metroidvania
	if mode == GameMode.METROIDVANIA:
		if Input.is_action_just_pressed("forma1"):
			toggle_transform(Form.BUBBLE)
		elif Input.is_action_just_pressed("forma2"):
			toggle_transform(Form.SUPER)
		elif Input.is_action_just_pressed("normal"):
			toggle_transform(Form.NORMAL)

# ====== GRAVIDADE / DASH =======
func apply_normal_gravity(delta: float) -> void:
	# Se estiver em DASH, aplicar queda lenta (aplica-se aos dois modos)
	if state == State.DASH:
		if dash_stops_fall:
			return
		velocity.y += gravity * dash_fall_factor * delta
		return

	# comportamento normal
	if form == Form.BUBBLE:
		velocity.y += 50 * delta
	else:
		velocity.y += gravity * delta

func apply_water_physics(delta: float) -> void:
	var water_grav := 150.0
	match form:
		Form.BUBBLE:
			water_grav = 50.0
		Form.SUPER:
			water_grav = 250.0
	
	velocity.y += water_grav * delta
	velocity.y -= 80.0 * delta  # buoyancy
	velocity.y *= 0.92
	velocity.x *= 0.92

func handle_jump() -> void:
	match form:
		Form.BUBBLE:
			if in_water:
				velocity.y = -100
				bubble_jump_count += 1
			elif bubble_jump_count < max_bubble_jumps:
				velocity.y = -50
				bubble_jump_count += 1
		Form.SUPER:
			if in_water:
				velocity.y = -120
			elif is_on_floor():
				velocity.y = super_jump_force
		_:
			if in_water:
				velocity.y = -150
			elif is_on_floor():
				velocity.y = jump_force

# ====== TRANSFORMAÇÃO =========
func toggle_transform(target: Form) -> void:
	if state == State.TRANSFORM:
		return
	if not can_transform():
		return
	if form == target:
		start_transform(Form.NORMAL)
	elif unlocked_forms.get(target, false):
		start_transform(target)

func start_transform(new_form: Form) -> void:
	state = State.TRANSFORM
	target_form = new_form

# ====== DASH CONTROL =========
func can_dash() -> bool:
	if not can_dash_global():
		return false
	return dash_cooldown_timer <= 0

# ====== STATE MACHINE =========
# Máquina de estados
func handle_state(delta: float) -> void:
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


func idle_state() -> void:
	handle_horizontal_input()
	if Input.is_action_just_pressed("jump") and on_ground:
		change_state(State.JUMP)
	elif abs(Input.get_axis("ui_left", "ui_right")) > 0:
		change_state(State.WALK)
	# Ataque por botão somente no modo Metroidvania
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
	if Input.is_action_just_pressed("dash") and can_dash():
		change_state(State.DASH)
	# quando volta ao chão, muda para IDLE
	if is_on_floor():
		change_state(State.IDLE)

func attack_state() -> void:
	velocity = Vector2.ZERO

func crouch_state() -> void:
	velocity.x = 0
	if not Input.is_action_pressed("crouch"):
		change_state(State.IDLE)

func dash_state() -> void:
	if dash_timer <= 0.0:
		dash_timer = dash_time
		dash_cooldown_timer = dash_cooldown
		var dir: int = int(sign(Input.get_axis("ui_left", "ui_right")))
		if dir == 0:
			dir = -1 if $Sprite2D.flip_h else 1
		velocity.x = dir * dash_speed

	dash_timer -= get_physics_process_delta_time()
	if dash_timer <= 0:
		if is_on_floor():
			change_state(State.IDLE)
		else:
			change_state(State.JUMP)

func transform_state() -> void:
	velocity = Vector2.ZERO

func dead_state() -> void:
	die()

func swim_state() -> void:
	var dir_x := Input.get_axis("ui_left", "ui_right")
	var dir_y := Input.get_axis("ui_up", "ui_down")
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
	if not in_water:
		change_state(State.IDLE)

func handle_horizontal_input() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	var current_speed := speed
	if in_water:
		match form:
			Form.NORMAL: current_speed *= 0.6
			Form.BUBBLE: current_speed *= 0.9
			Form.SUPER: current_speed *= 0.5
	velocity.x = dir * current_speed
	if dir != 0:
		$Sprite2D.flip_h = dir < 0

func change_state(new_state: State) -> void:
	state = new_state

# ====== DANO / VIDAS ==========
func take_damage(amount: int = 1) -> void:
	if is_invincible or state == State.DEAD:
		return

	# PLATAFORMA → cada hit é perda de 1 vida (sem HP)
	if mode == GameMode.PLATAFORMA:
		_on_fatal_hit()
		return

	# METROIDVANIA → usa stats/HP
	if stats and stats.has_method("take_damage"):
		stats.take_damage(amount)
		if stats.current_health <= 0:
			_on_fatal_hit()
	else:
		_on_fatal_hit()

	# ativa invencibilidade (se ainda não morreu)
	if state != State.DEAD:
		start_invincibility()

func start_invincibility() -> void:
	is_invincible = true
	var tree := get_tree()
	if tree == null:
		# se não tiver árvore, desliga invencibilidade e retorna
		is_invincible = false
		return
	var timer := tree.create_timer(invincibility_time)
	if timer == null:
		is_invincible = false
		return
	await timer.timeout
	is_invincible = false

func _on_fatal_hit() -> void:
	# METROIDVANIA → morrer direto (uma vida = HP)
	if mode == GameMode.METROIDVANIA:
		die()
		return

	# PLATAFORMA → perde vida e respawna
	GameManager.lose_life()
	if GameManager.get_lives() <= 0:
		die()
	else:
		await respawn_player()

func respawn_player() -> void:
	# posiciona no respawn point
	global_position = respawn_position
	velocity = Vector2.ZERO
	change_state(State.IDLE)

	# restaura HP no modo metroidvania caso seja necessário (componente stats disponibiliza)
	if mode == GameMode.METROIDVANIA and stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()

	# invencibilidade breve após spawn
	is_invincible = true
	var tree := get_tree()
	if tree:
		var timer := tree.create_timer(invincibility_time)
		if timer:
			await timer.timeout
	is_invincible = false


# ====== ATAQUE (área) ========
func activate_attack_area() -> void:
	if attack_collision:
		attack_collision.disabled = false

func deactivate_attack_area() -> void:
	if attack_collision:
		attack_collision.disabled = true

# Este método é chamado pelo Sprite2D quando a animação de ataque termina
# Fim de ataque (normal, especial ou combo)
func _on_attack_finished() -> void:
	deactivate_attack_area()
	if state != State.DEAD:
		change_state(State.IDLE)


# ====== ÁUDIO / UTIL ========
func update_audio_by_form() -> void:
	if not audio_normal or not audio_super:
		return
	match form:
		Form.NORMAL, Form.BUBBLE:
			if audio_super.playing: audio_super.stop()
			if not audio_normal.playing: audio_normal.play()
		Form.SUPER:
			if audio_normal.playing: audio_normal.stop()
			if not audio_super.playing: audio_super.play()

# ====== MORTE / CONTINUE ======
func die() -> void:
	# marca dead e toca animação
	state = State.DEAD
	if animation_player:
		animation_player.play("Dead")
	velocity = Vector2.ZERO

	if audio_normal: audio_normal.stop()
	if audio_super: audio_super.stop()

	var tree := get_tree()
	if tree == null:
		# se não tiver árvore (ex: durante callback), só chama goto_continue via deferred
		GameManager.call_deferred("goto_continue")
		return

	# aguarda a animação de morte (se houver)
	var timer := tree.create_timer(death_delay)
	if timer == null:
		GameManager.call_deferred("goto_continue")
		return
	await timer.timeout

	if not is_inside_tree():
		return

	# ir para continue (GameManager já faz call_deferred em change_scene)
	GameManager.goto_continue()

# ====== BOUNCE / HURTBOX ======
func bounce_from_enemy() -> void:
	is_bouncing_from_enemy = true
	velocity.y = -260

func _on_hurtbox_body_entered(body: Area2D) -> void:
	if is_invincible:
		return

	# Se for uma area que possui o método especializado (compat)
	if body.has_method("deal_damage_to_player"):
		body.deal_damage_to_player(self)
		return

	# inimigo normal
	if body.is_in_group("enemy"):
		# player toma dano (o sistema de inimigo deve executar stomp logic e chamar take_damage ou chamar bounce)
		take_damage(1)
		return

	# boss
	if body.is_in_group("boss"):
		take_damage(1)
		return
