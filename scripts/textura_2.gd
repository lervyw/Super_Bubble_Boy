extends AnimatedSprite2D
# =========================================================
#  PLAYER SPRITES / ANIMATION CONTROLLER
#  Responsável por:
#  - Escolher qual animação tocar baseado em:
#    estado do player, forma, direção e queda
#  - Virar o sprite (flip) e espelhar a área de ataque
#  - Emitir sinal quando ataque termina (para o Player.gd)
#  - Finalizar transformações no fim da animação (troca de forma)
# =========================================================

signal attack_finished

# ================================
#            REFERÊNCIAS
# ================================
@export var player: Node
@export var stats: Node
@export var nivel: Node
@export var attack_area: Area2D

# ================================
#              READY
# ================================
func _ready() -> void:
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)

# ================================
#            PROCESS
# ================================
func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return

	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	verify_position(direction)
	update_animation(direction)

# ================================
#     TOCAR ANIMAÇÃO COM SAFE
# ================================
func play_if_different(anim_name: StringName) -> void:
	if animation != anim_name:
		play(anim_name)

# ================================
#     SELETOR PRINCIPAL DE ANIMAÇÃO
# ================================
func update_animation(direction: Vector2) -> void:
	# Prioridade: queda no ar
	if player.velocity.y > 0.0 and not player.is_on_floor():
		match player.form:
			player.Form.NORMAL:
				play_if_different(&"fall")
			player.Form.BUBBLE:
				play_if_different(&"idle_bubble")
			player.Form.SUPER:
				play_if_different(&"fall")
		return

	match player.state:
		player.State.TRANSFORM:
			handle_transform_animation()

		player.State.DEAD:
			handle_death_animation()

		player.State.DASH:
			handle_dash_animation()

		player.State.CROUCH:
			handle_crouch_animation()

		player.State.JUMP, player.State.WALK, player.State.IDLE:
			handle_movement_animation(direction)

		player.State.SWIM:
			handle_swim_animation(direction)

		player.State.ATTACK, player.State.SPECIAL_ATTACK:
			handle_attack_animation()

		player.State.DEFEND:
			play_if_different(&"S_parry")

# ================================
#         ANIMAÇÕES POR ESTADO
# ================================
func handle_dash_animation() -> void:
	match player.form:
		player.Form.SUPER:
			play_if_different(&"S_Jump")
		player.Form.BUBBLE:
			play_if_different(&"Bubble_Swim")
		_:
			play_if_different(&"Dash")

func handle_attack_animation() -> void:
	var anim_name: StringName = &"attack"

	match player.form:
		player.Form.SUPER:
			anim_name = &"attack_super"
		player.Form.BUBBLE:
			anim_name = &"attack_bubble"

	play_if_different(anim_name)

func handle_movement_animation(direction: Vector2) -> void:
	match player.form:
		player.Form.NORMAL:
			if direction.x != 0.0:
				play_if_different(&"walk")
			else:
				play_if_different(&"idle")

		player.Form.BUBBLE:
			play_if_different(&"idle_bubble")

		player.Form.SUPER:
			if direction.x != 0.0:
				play_if_different(&"walk_super")
			else:
				play_if_different(&"idle_super")

func handle_swim_animation(_direction: Vector2) -> void:
	match player.form:
		player.Form.BUBBLE:
			play_if_different(&"iddle_bubble")
		player.Form.SUPER:
			play_if_different(&"swim_super")
		_:
			play_if_different(&"swim")

func handle_transform_animation() -> void:
	var cur = player.form
	var tgt = player.target_form
	var anim_name: StringName = &"born"

	match [cur, tgt]:
		[player.Form.NORMAL, player.Form.BUBBLE]:
			anim_name = &"normal_to_bubble"
		[player.Form.NORMAL, player.Form.SUPER]:
			anim_name = &"normal_to_super"
		[player.Form.BUBBLE, player.Form.NORMAL]:
			anim_name = &"bubble_to_normal"
		[player.Form.BUBBLE, player.Form.SUPER]:
			anim_name = &"bubble_to_super"
		[player.Form.SUPER, player.Form.NORMAL]:
			anim_name = &"super_to_normal"
		[player.Form.SUPER, player.Form.BUBBLE]:
			anim_name = &"super_to_bubble"

	play_if_different(anim_name)

func handle_crouch_animation() -> void:
	match player.form:
		player.Form.SUPER:
			play_if_different(&"croch_super")
		player.Form.NORMAL:
			play_if_different(&"crouch")
		player.Form.BUBBLE:
			play_if_different(&"idle_bubble")

func handle_death_animation() -> void:
	match player.form:
		player.Form.NORMAL:
			play_if_different(&"death")
		player.Form.BUBBLE:
			play_if_different(&"death_bubble")
		player.Form.SUPER:
			play_if_different(&"death_super")

# ================================
#         FLIP / HITBOX
# ================================
func verify_position(direction: Vector2) -> void:
	if direction.x > 0.0:
		flip_h = false
		if is_instance_valid(attack_area):
			attack_area.scale.x = abs(attack_area.scale.x)

	elif direction.x < 0.0:
		flip_h = true
		if is_instance_valid(attack_area):
			attack_area.scale.x = -abs(attack_area.scale.x)

# ================================
#     CALLBACK: FIM DA ANIMAÇÃO
# ================================
func _on_animation_finished() -> void:
	if not is_instance_valid(player):
		return

	var anim_name: StringName = animation

	match anim_name:
		# Ataques / parry
		&"attack", &"attack_super", &"idle_bubble", &"parry_super":
			attack_finished.emit()

		# ---- Transformações: ao terminar, aplica a forma nova ----
		&"normal_to_bubble":
			player.form = player.Form.BUBBLE
			player.change_state(player.State.IDLE)
			player.update_audio_by_form()

		&"normal_to_super":
			player.form = player.Form.SUPER
			player.change_state(player.State.IDLE)
			player.update_audio_by_form()

		&"bubble_to_normal", &"super_to_normal":
			player.form = player.Form.NORMAL
			player.change_state(player.State.IDLE)
			player.update_audio_by_form()

		&"bubble_to_super":
			player.form = player.Form.SUPER
			player.change_state(player.State.IDLE)
			player.update_audio_by_form()

		&"super_to_bubble":
			player.form = player.Form.BUBBLE
			player.change_state(player.State.IDLE)
			player.update_audio_by_form()

		_:
			if player.state == player.State.TRANSFORM:
				player.change_state(player.State.IDLE)
