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

	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"), 
		Input.get_axis("ui_up", "ui_down")
	)

	verify_position(direction)
	update_animation(direction)

func play_if_different(anim_name: String) -> void:
	if animation.current_animation != anim_name:
		animation.play(anim_name)

func update_animation(direction: Vector2) -> void:
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
		player.Form.SUPER:
			play_if_different("S_Jump")
		player.Form.BUBBLE:
			play_if_different("Bubble_Swim")
		_:
			play_if_different("Dash")

func handle_attack_animation() -> void:
	var anim_name := ""
	match player.form:
		player.Form.SUPER: anim_name = "S_attack"
		player.Form.BUBBLE: anim_name = "B_attack"
		_: anim_name = "Attack"

	if not animation.has_animation(anim_name):
		anim_name = "Attack"

	play_if_different(anim_name)

func handle_movement_animation(direction: Vector2) -> void:
	match player.form:
		player.Form.NORMAL:
			if not player.is_on_floor():
				if direction.y > 0: play_if_different("Fall")
				elif direction.y < 0: play_if_different("Jump")
				else: play_if_different("Idle")
			elif abs(direction.x) > 0:
				play_if_different("Walk")
			else:
				play_if_different("Idle")

		player.Form.BUBBLE:
			play_if_different("Bubble_only")

		player.Form.SUPER:
			if not player.is_on_floor():
				if direction.y > 0: play_if_different("S_Fall")
				elif direction.y < 0: play_if_different("S_Jump")
				else: play_if_different("S_Idle")
			elif abs(direction.x) > 0:
				play_if_different("S_Walk")
			else:
				play_if_different("S_Idle")

func handle_swim_animation(direction: Vector2) -> void:
	match player.form:
		player.Form.BUBBLE: play_if_different("Bubble_Swim")
		player.Form.SUPER: play_if_different("S_Swim")
		_: play_if_different("Swim")

func handle_transform_animation() -> void:
	var current_form = player.form
	var target_form = player.target_form

	if target_form == null:
		return

	var anim_name := ""

	match [current_form, target_form]:
		[player.Form.NORMAL, player.Form.BUBBLE]: anim_name = "Normal_Bolha"
		[player.Form.NORMAL, player.Form.SUPER]: anim_name = "Normal_Super"

		[player.Form.BUBBLE, player.Form.NORMAL]: anim_name = "Bolha_Normal"
		[player.Form.BUBBLE, player.Form.SUPER]: anim_name = "Bolha_Super"

		[player.Form.SUPER, player.Form.NORMAL]: anim_name = "Super_Normal"
		[player.Form.SUPER, player.Form.BUBBLE]: anim_name = "Super_Bolha"

		_: anim_name = "Born"

	play_if_different(anim_name)

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
		if attack_area:
			attack_area.scale.x = 1
	elif direction.x < 0:
		flip_h = true
		if attack_area:
			attack_area.scale.x = -1

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

		"Dead_normal", "S_dead", "B_dead":
			pass  # Player.gd controla morte agora

		_:
			if player.state == player.State.TRANSFORM:
				player.change_state(player.State.IDLE)
