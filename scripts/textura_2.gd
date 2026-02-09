extends Sprite2D
# =========================================================
#  PLAYER SPRITES / ANIMATION CONTROLLER
#  Responsável por:
#  - Escolher qual animação tocar baseado em:
#    estado do player, forma, direção e queda
#  - Virar o sprite (flip) e espelhar a área de ataque
#  - Emitir sinal quando ataque termina (para o Player.gd)
#  - Finalizar transformações no fim da animação (troca de forma)
# =========================================================

# Sinal usado pelo Player.gd para desligar hitbox e voltar ao idle
signal attack_finished

# ================================
#            REFERÊNCIAS
# ================================
@export var player: Node                 # referência do player (que tem state/form/velocity)
@export var animation: AnimationPlayer   # AnimationPlayer que toca as animações
@export var stats: Node                  # (não usado aqui, mas deixado como referência)
@export var nivel: Node                  # (não usado aqui, mas deixado como referência)
@export var attack_area: Area2D          # área do ataque (espelhada junto com o sprite)

# ================================
#            PROCESS
# ================================
func _process(delta: float) -> void:
	# Se não tiver player, não faz nada
	if not player:
		return

	# Lê direção do input (x/y) para movimentação/flip/nado
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	# Atualiza flip do sprite + lado da hitbox de ataque
	verify_position(dir)

	# Decide qual animação tocar
	update_animation(dir)

# ================================
#     TOCAR ANIMAÇÃO COM SAFE
# ================================
func play_if_different(anim: String) -> void:
	# Evita ficar reiniciando a mesma animação todo frame
	if animation.current_animation != anim:
		animation.play(anim)

# ================================
#     SELETOR PRINCIPAL DE ANIMAÇÃO
# ================================
func update_animation(direction: Vector2) -> void:
	# Regra de prioridade: QUEDA sempre ganha (quando está caindo no ar)
	if player.velocity.y > 0 and not player.is_on_floor():
		match player.form:
			player.Form.NORMAL: play_if_different("Fall")
			player.Form.BUBBLE: play_if_different("Bubble_Swim")
			player.Form.SUPER: play_if_different("S_Fall")
		return

	# Caso não esteja caindo, decide pelo estado atual do player
	match player.state:
		player.State.TRANSFORM: handle_transform_animation()
		player.State.DEAD: handle_death_animation()
		player.State.DASH: handle_dash_animation()
		player.State.CROUCH: handle_crouch_animation()

		# Estados “normais” de movimento usam direção para walk/idle
		player.State.JUMP, player.State.WALK, player.State.IDLE:
			handle_movement_animation(direction)

		# Nado tem lógica própria
		player.State.SWIM:
			handle_swim_animation(direction)

		# Ataques (normal e especial) reutilizam a mesma função
		player.State.ATTACK:
			handle_attack_animation()
		player.State.SPECIAL_ATTACK:
			handle_attack_animation()

		# Defesa usa animação de parry do super (fixo aqui)
		player.State.DEFEND:
			play_if_different("S_parry")

# ================================
#         ANIMAÇÕES POR ESTADO
# ================================
func handle_dash_animation() -> void:
	# Dash muda animação dependendo da forma
	match player.form:
		player.Form.SUPER: play_if_different("S_Jump")
		player.Form.BUBBLE: play_if_different("Bubble_Swim")
		_: play_if_different("Dash")

func handle_attack_animation() -> void:
	# Ataque muda nome da animação dependendo da forma
	var anim := "Attack"
	match player.form:
		player.Form.SUPER: anim = "S_attack"
		player.Form.BUBBLE: anim = "B_attack"
	play_if_different(anim)

func handle_movement_animation(direction: Vector2) -> void:
	# Movimento padrão: idle/walk (super tem versão própria)
	match player.form:
		player.Form.NORMAL:
			if direction.x != 0:
				play_if_different("Walk")
			else:
				play_if_different("Idle")

		# Bolha parece ter animação “única” fora da água
		player.Form.BUBBLE:
			play_if_different("Bubble_only")

		player.Form.SUPER:
			if direction.x != 0:
				play_if_different("S_Walk")
			else:
				play_if_different("S_Idle")

func handle_swim_animation(direction: Vector2) -> void:
	# Nado depende da forma
	match player.form:
		player.Form.BUBBLE: play_if_different("Bubble_Swim")
		player.Form.SUPER: play_if_different("S_Swim")
		_: play_if_different("Swim")

func handle_transform_animation() -> void:
	# Decide qual animação tocar com base na forma atual e na forma alvo
	var cur = player.form
	var tgt = player.target_form
	if tgt == null: return

	var anim := ""

	match [cur, tgt]:
		[player.Form.NORMAL, player.Form.BUBBLE]: anim = "Normal_Bolha"
		[player.Form.NORMAL, player.Form.SUPER]: anim = "Normal_Super"
		[player.Form.BUBBLE, player.Form.NORMAL]: anim = "Bolha_Normal"
		[player.Form.BUBBLE, player.Form.SUPER]: anim = "Bolha_Super"
		[player.Form.SUPER, player.Form.NORMAL]: anim = "Super_Normal"
		[player.Form.SUPER, player.Form.BUBBLE]: anim = "Super_Bolha"
		_: anim = "Born" # fallback caso não bata nenhuma combinação

	play_if_different(anim)

func handle_crouch_animation() -> void:
	# Agachar por forma
	match player.form:
		player.Form.SUPER: play_if_different("S_crouch_hold")
		player.Form.NORMAL: play_if_different("N_c_loop")
		player.Form.BUBBLE: play_if_different("Bubble_only")

func handle_death_animation() -> void:
	# Morte por forma
	match player.form:
		player.Form.NORMAL: play_if_different("Dead")
		player.Form.BUBBLE: play_if_different("B_dead")
		player.Form.SUPER: play_if_different("S_dead")

# ================================
#         FLIP / HITBOX
# ================================
func verify_position(direction: Vector2) -> void:
	# Vira o sprite e espelha a área de ataque conforme direção horizontal
	if direction.x > 0:
		flip_h = false
		if attack_area: attack_area.scale.x = 1
	elif direction.x < 0:
		flip_h = true
		if attack_area: attack_area.scale.x = -1

# ================================
#     CALLBACK: FIM DA ANIMAÇÃO
# ================================
func _on_animacao_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		# Quando ataque/parry acaba, avisa o Player.gd
		"Attack", "S_attack", "B_attack", "S_parry":
			emit_signal("attack_finished")

		# ---- Transformações: ao terminar, aplica a forma nova ----
		"Normal_Bolha":
			player.form = player.Form.BUBBLE
			player.change_state(player.State.IDLE)
			player.update_audio_by_form()

		"Normal_Super":
			player.form = player.Form.SUPER
			player.change_state(player.State.IDLE)
			player.update_audio_by_form()

		"Bolha_Normal", "Super_Normal":
			player.form = player.Form.NORMAL
			player.change_state(player.State.IDLE)
			player.update_audio_by_form()

		"Bolha_Super":
			player.form = player.Form.SUPER
			player.change_state(player.State.IDLE)
			player.update_audio_by_form()

		"Super_Bolha":
			player.form = player.Form.BUBBLE
			player.change_state(player.State.IDLE)
			player.update_audio_by_form()

		_:
			# Fallback: se estava transformando e terminou qualquer outra animação, volta pro idle
			if player.state == player.State.TRANSFORM:
				player.change_state(player.State.IDLE)
