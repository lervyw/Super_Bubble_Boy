extends Sprite2D

signal attack_finished

@export var player: Node
@export var animation: AnimationPlayer
@export var stats: Node
@export var nivel: Node
@export var attack_area: Area2D

func _process(delta: float) -> void:
	if not player:
		return

	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	verify_position(dir)
	update_animation(dir)

func play_if_different(anim: String) -> void:
	if animation.current_animation != anim:
		animation.play(anim)

func update_animation(direction: Vector2) -> void:

	# 🔥 FORÇA ANIMAÇÃO DE QUEDA
	if player.velocity.y > 0 and not player.is_on_floor():
		match player.form:
			player.Form.NORMAL: play_if_different("Fall")
			player.Form.BUBBLE: play_if_different("Bubble_Swim")
			player.Form.SUPER: play_if_different("S_Fall")
		return

	match player.state:
		player.State.TRANSFORM: handle_transform_animation()
		player.State.DEAD: handle_death_animation()
		player.State.DASH: handle_dash_animation()
		player.State.CROUCH: handle_crouch_animation()
		player.State.JUMP, player.State.WALK, player.State.IDLE:
			handle_movement_animation(direction)
		player.State.SWIM: handle_swim_animation(direction)
		player.State.ATTACK: handle_attack_animation()

func handle_dash_animation() -> void:
	match player.form:
		player.Form.SUPER: play_if_different("S_Jump")
		player.Form.BUBBLE: play_if_different("Bubble_Swim")
		_: play_if_different("Dash")

func handle_attack_animation() -> void:
	var anim := "Attack"
	match player.form:
		player.Form.SUPER: anim = "S_attack"
		player.Form.BUBBLE: anim = "B_attack"
	play_if_different(anim)

func handle_movement_animation(direction: Vector2) -> void:
	match player.form:
		player.Form.NORMAL:
			if direction.x != 0:
				play_if_different("Walk")
			else:
				play_if_different("Idle")

		player.Form.BUBBLE:
			play_if_different("Bubble_only")

		player.Form.SUPER:
			if direction.x != 0:
				play_if_different("S_Walk")
			else:
				play_if_different("S_Idle")

func handle_swim_animation(direction: Vector2) -> void:
	match player.form:
		player.Form.BUBBLE: play_if_different("Bubble_Swim")
		player.Form.SUPER: play_if_different("S_Swim")
		_: play_if_different("Swim")

func handle_transform_animation() -> void:
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
		_: anim = "Born"

	play_if_different(anim)

func handle_crouch_animation() -> void:
	match player.form:
		player.Form.SUPER: play_if_different("S_crouch")
		player.Form.NORMAL: play_if_different("N_c_loop")
		player.Form.BUBBLE: play_if_different("Bubble_only")

func handle_death_animation() -> void:
	match player.form:
		player.Form.NORMAL: play_if_different("Dead")
		player.Form.BUBBLE: play_if_different("B_dead")
		player.Form.SUPER: play_if_different("S_dead")

func verify_position(direction: Vector2) -> void:
	if direction.x > 0:
		flip_h = false
		if attack_area: attack_area.scale.x = 1
	elif direction.x < 0:
		flip_h = true
		if attack_area: attack_area.scale.x = -1

func _on_animacao_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Attack", "S_attack", "B_attack", "S_parry":
			emit_signal("attack_finished")

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
			if player.state == player.State.TRANSFORM:
				player.change_state(player.State.IDLE)
