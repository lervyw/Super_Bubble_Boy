extends AnimatedSprite2D
# =========================================================
#  PLAYER SPRITES / ANIMATION CONTROLLER
#  Responsável por:
#  - Escolher qual animação tocar baseado em:
#    estado do player, forma, direção e queda
#  - Virar o sprite (flip) e espelhar hitboxes/areas
#  - Emitir sinal quando ataque termina (para o Player.gd)
#  - Finalizar transformações no fim da animação
#  - Ativar a hitbox correta por forma/estado
#  - Permitir uso futuro de AnimationPlayer para especiais
# =========================================================

signal attack_finished

# ================================
#            REFERÊNCIAS
# ================================
@export var player: Node
@export var stats: Node
@export var nivel: Node

# AnimationPlayer opcional para futuros especiais / efeitos
@export var special_animation_player: AnimationPlayer

# ----------------
# Special Attack
# ----------------
@export_group("Special Attack")
@export var special_attack_area_normal: Area2D
@export var special_attack_area_bubble: Area2D
@export var special_attack_area_super: Area2D

@export var special_attack_anim_normal: StringName = &"special_attack_normal"
@export var special_attack_anim_bubble: StringName = &"special_attack_bubble"
@export var special_attack_anim_super: StringName = &"special_attack_super"

# ----------------
# Hitboxes do corpo
# ----------------
@export_group("Body Hitboxes - Normal")
@export var body_idle_normal: CollisionShape2D
@export var body_walk_normal: CollisionShape2D
@export var body_jump_normal: CollisionShape2D
@export var body_fall_normal: CollisionShape2D
@export var body_crouch_normal: CollisionShape2D
@export var body_dash_normal: CollisionShape2D
@export var body_swim_normal: CollisionShape2D
@export var body_attack_normal: CollisionShape2D
@export var body_defend_normal: CollisionShape2D
@export var body_dead_normal: CollisionShape2D

@export_group("Body Hitboxes - Bubble")
@export var body_idle_bubble: CollisionShape2D
@export var body_walk_bubble: CollisionShape2D
@export var body_jump_bubble: CollisionShape2D
@export var body_fall_bubble: CollisionShape2D
@export var body_crouch_bubble: CollisionShape2D
@export var body_dash_bubble: CollisionShape2D
@export var body_swim_bubble: CollisionShape2D
@export var body_attack_bubble: CollisionShape2D
@export var body_defend_bubble: CollisionShape2D
@export var body_dead_bubble: CollisionShape2D

@export_group("Body Hitboxes - Super")
@export var body_idle_super: CollisionShape2D
@export var body_walk_super: CollisionShape2D
@export var body_jump_super: CollisionShape2D
@export var body_fall_super: CollisionShape2D
@export var body_crouch_super: CollisionShape2D
@export var body_dash_super: CollisionShape2D
@export var body_swim_super: CollisionShape2D
@export var body_attack_super: CollisionShape2D
@export var body_defend_super: CollisionShape2D
@export var body_dead_super: CollisionShape2D

# ----------------
# Áreas de ataque
# ----------------
@export_group("Attack Areas")
@export var attack_area_normal: Area2D
@export var attack_area_bubble: Area2D
@export var attack_area_super: Area2D

# ================================
#              READY
# ================================
func _ready() -> void:
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)

	ensure_run_animations()
	disable_all_hitboxes()
	deactivate_all_attack_areas()
	deactivate_all_special_attack_areas()
	refresh_hitbox_for_current_state()


func ensure_run_animations() -> void:
	duplicate_animation_if_missing(&"walk", &"run", 13.0)
	duplicate_animation_if_missing(&"walk_super", &"run_super", 13.0)
	duplicate_animation_if_missing(&"idle_bubble", &"bubble_run", 13.0)


func duplicate_animation_if_missing(source: StringName, target: StringName, target_speed: float) -> void:
	if not sprite_frames:
		return
	if sprite_frames.has_animation(target):
		return
	if not sprite_frames.has_animation(source):
		return

	sprite_frames.add_animation(target)
	sprite_frames.set_animation_loop(target, sprite_frames.get_animation_loop(source))
	sprite_frames.set_animation_speed(target, target_speed)

	for i in range(sprite_frames.get_frame_count(source)):
		sprite_frames.add_frame(target, sprite_frames.get_frame_texture(source, i), sprite_frames.get_frame_duration(source, i))

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
	if direction.x == 0.0:
		direction.x = Input.get_axis("left", "right")

	if not is_player_using_hud_menu():
		verify_position(direction)
	update_animation(direction)

# ================================
#     TOCAR ANIMAÇÃO COM SAFE
# ================================
func play_if_different(anim_name: StringName) -> void:
	if animation != anim_name:
		play(anim_name)


func is_player_using_hud_menu() -> bool:
	return "hud_menu_open" in player and player.hud_menu_open

func play_special_animation_if_exists(anim_name: StringName) -> void:
	if is_instance_valid(special_animation_player):
		if special_animation_player.has_animation(anim_name):
			if special_animation_player.current_animation != anim_name:
				special_animation_player.play(anim_name)

# ================================
#     SELETOR PRINCIPAL DE ANIMAÇÃO
# ================================
func update_animation(direction: Vector2) -> void:
	if "ground_stomp_anim_override" in player and player.ground_stomp_anim_override != &"":
		return

	match player.state:
		player.State.TRANSFORM:
			handle_transform_animation()
			return

		player.State.DEAD:
			handle_death_animation()
			return

		player.State.HURT:
			handle_hurt_animation()
			return

	if player.state == player.State.SWIM:
		handle_swim_animation(direction)
		return

	match player.state:
		player.State.ATTACK:
			handle_attack_animation()
			return

		player.State.SPECIAL_ATTACK:
			handle_special_attack_animation()
			return

		player.State.DEFEND:
			handle_defend_animation()
			return

	if player.state == player.State.DASH:
		handle_dash_animation()
		return

	if player.state == player.State.CROUCH:
		handle_crouch_animation()
		return

	if not player.is_on_floor():
		if player.velocity.y < 0.0:
			handle_jump_animation()
			return
		elif player.velocity.y > 0.0:
			handle_fall_animation()
			return

	handle_movement_animation(direction)

# ================================
#         ANIMAÇÕES POR ESTADO
# ================================
func handle_jump_animation() -> void:
	activate_hitbox_for_state("jump")

	match player.form:
		player.Form.NORMAL:
			play_if_different(&"jump")
		player.Form.BUBBLE:
			play_if_different(&"idle_bubble")
		player.Form.SUPER:
			play_if_different(&"jump_super")

func handle_fall_animation() -> void:
	activate_hitbox_for_state("fall")

	match player.form:
		player.Form.NORMAL:
			play_if_different(&"fall")
		player.Form.BUBBLE:
			play_if_different(&"idle_bubble")
		player.Form.SUPER:
			play_if_different(&"fall_super")

func handle_dash_animation() -> void:
	activate_hitbox_for_state("dash")

	match player.form:
		player.Form.SUPER:
			play_if_different(&"jump_super")
		player.Form.BUBBLE:
			play_if_different(&"idle_bubble")
		_:
			play_if_different(&"dash")

func handle_attack_animation() -> void:
	activate_hitbox_for_state("attack")

	var anim_name: StringName = &"attack"

	match player.form:
		player.Form.SUPER:
			anim_name = &"attack_super"
		player.Form.BUBBLE:
			anim_name = &"attack_bubble"

	play_if_different(anim_name)

func handle_special_attack_animation() -> void:
	activate_hitbox_for_state("attack")

	if "special_attack_animation_override" in player:
		var override_anim: StringName = player.special_attack_animation_override
		if override_anim != &"" and sprite_frames.has_animation(override_anim):
			if override_anim in [&"bubble_throw", &"bubble_throw_arrive"]:
				if animation != override_anim:
					play(override_anim)
			else:
				play_if_different(override_anim)
			return

	var anim_name: StringName = &""

	match player.form:
		player.Form.NORMAL:
			anim_name = special_attack_anim_normal

		player.Form.BUBBLE:
			# Bubble agora usa o especial do SUPER
			anim_name = special_attack_anim_super

		player.Form.SUPER:
			anim_name = special_attack_anim_super

	if anim_name != &"" and sprite_frames.has_animation(anim_name):
		play_if_different(anim_name)

	if player.super_shield_active and animation == &"super_shield" and not is_playing() and frame >= 6:
		play(&"super_shield")
		frame = 6
	else:
		match player.form:
			player.Form.NORMAL:
				play_if_different(&"attack_super")
			player.Form.BUBBLE:
				play_if_different(&"attack_super")
			player.Form.SUPER:
				play_if_different(&"attack_super")
func handle_defend_animation() -> void:
	activate_hitbox_for_state("defend")

	var anim_name: StringName = &"parry_super"

	if player.super_shield_active and sprite_frames.has_animation(&"super_shield"):
		anim_name = &"super_shield"
	else:
		match player.form:
			player.Form.NORMAL:
				if sprite_frames.has_animation(&"parry"):
					anim_name = &"parry"
			player.Form.BUBBLE:
				if sprite_frames.has_animation(&"parry_bubble"):
					anim_name = &"parry_bubble"
			player.Form.SUPER:
				if sprite_frames.has_animation(&"parry_super"):
					anim_name = &"parry_super"

	play_if_different(anim_name)

	if player.super_shield_active and animation == &"super_shield" and not is_playing() and frame >= 6:
		play(&"super_shield")
		frame = 6


func handle_movement_animation(direction: Vector2) -> void:
	var use_run: bool = player.has_method("is_passive_run_boosting") and player.is_passive_run_boosting()

	match player.form:
		player.Form.NORMAL:
			if direction.x != 0.0:
				activate_hitbox_for_state("walk")
				if use_run and sprite_frames.has_animation(&"bubble_run"):
					play_if_different(&"bubble_run")
				elif use_run and sprite_frames.has_animation(&"run"):
					play_if_different(&"run")
				else:
					play_if_different(&"walk")
			else:
				activate_hitbox_for_state("idle")
				play_if_different(&"idle")

		player.Form.BUBBLE:
			if direction.x != 0.0:
				activate_hitbox_for_state("walk")
			else:
				activate_hitbox_for_state("idle")
			play_if_different(&"idle_bubble")

		player.Form.SUPER:
			if direction.x != 0.0:
				activate_hitbox_for_state("walk")
				if use_run and sprite_frames.has_animation(&"run_super"):
					play_if_different(&"run_super")
				elif use_run and sprite_frames.has_animation(&"run"):
					play_if_different(&"run")
				else:
					play_if_different(&"walk_super")
			else:
				activate_hitbox_for_state("idle")
				play_if_different(&"idle_super")

func handle_swim_animation(_direction: Vector2) -> void:
	activate_hitbox_for_state("swim")

	match player.form:
		player.Form.BUBBLE:
			play_if_different(&"idle_bubble")
		player.Form.SUPER:
			play_if_different(&"swim_super")
		_:
			play_if_different(&"swim")

func handle_transform_animation() -> void:
	disable_all_hitboxes()
	deactivate_all_attack_areas()
	deactivate_all_special_attack_areas()

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

func deactivate_all_special_attack_areas() -> void:
	var areas: Array[Area2D] = [
		special_attack_area_normal,
		special_attack_area_bubble,
		special_attack_area_super
	]

	for area in areas:
		if is_instance_valid(area):
			area.monitoring = false
			area.monitorable = false

			for child in area.get_children():
				if child is CollisionShape2D:
					child.disabled = true

func handle_crouch_animation() -> void:
	activate_hitbox_for_state("crouch")

	match player.form:
		player.Form.SUPER:
			play_if_different(&"crouch_super")
		player.Form.NORMAL:
			play_if_different(&"crouch")
		player.Form.BUBBLE:
			play_if_different(&"idle_bubble")

func handle_death_animation() -> void:
	activate_hitbox_for_state("dead")
	deactivate_all_attack_areas()
	deactivate_all_special_attack_areas()

	match player.form:
		player.Form.NORMAL:
			play_if_different(&"death")
		player.Form.BUBBLE:
			play_if_different(&"death_bubble")
		player.Form.SUPER:
			play_if_different(&"death_super")


func handle_hurt_animation() -> void:
	activate_hitbox_for_state("dead")
	deactivate_all_attack_areas()
	deactivate_all_special_attack_areas()

	if sprite_frames.has_animation(&"hurt"):
		play_if_different(&"hurt")
		return

	handle_death_animation()
# ================================
#       HITBOXES / ATTACK AREAS
# ================================
func disable_all_hitboxes() -> void:
	var all_hitboxes: Array[CollisionShape2D] = [
		body_idle_normal, body_walk_normal, body_jump_normal, body_fall_normal, body_crouch_normal,
		body_dash_normal, body_swim_normal, body_attack_normal, body_defend_normal, body_dead_normal,

		body_idle_bubble, body_walk_bubble, body_jump_bubble, body_fall_bubble, body_crouch_bubble,
		body_dash_bubble, body_swim_bubble, body_attack_bubble, body_defend_bubble, body_dead_bubble,

		body_idle_super, body_walk_super, body_jump_super, body_fall_super, body_crouch_super,
		body_dash_super, body_swim_super, body_attack_super, body_defend_super, body_dead_super
	]

	for hitbox in all_hitboxes:
		if is_instance_valid(hitbox):
			hitbox.disabled = true

func set_hitbox_enabled(hitbox: CollisionShape2D, enabled: bool) -> void:
	if is_instance_valid(hitbox):
		hitbox.disabled = not enabled

func get_hitbox_for_state(form_value: int, state_name: String) -> CollisionShape2D:
	match form_value:
		player.Form.NORMAL:
			match state_name:
				"idle": return body_idle_normal
				"walk": return body_walk_normal
				"jump": return body_jump_normal
				"fall": return body_fall_normal
				"crouch": return body_crouch_normal
				"dash": return body_dash_normal
				"swim": return body_swim_normal
				"attack": return body_attack_normal
				"defend": return body_defend_normal
				"dead": return body_dead_normal

		player.Form.BUBBLE:
			match state_name:
				"idle": return body_idle_bubble
				"walk": return body_walk_bubble
				"jump": return body_jump_bubble
				"fall": return body_fall_bubble
				"crouch": return body_crouch_bubble
				"dash": return body_dash_bubble
				"swim": return body_swim_bubble
				"attack": return body_attack_bubble
				"defend": return body_defend_bubble
				"dead": return body_dead_bubble

		player.Form.SUPER:
			match state_name:
				"idle": return body_idle_super
				"walk": return body_walk_super
				"jump": return body_jump_super
				"fall": return body_fall_super
				"crouch": return body_crouch_super
				"dash": return body_dash_super
				"swim": return body_swim_super
				"attack": return body_attack_super
				"defend": return body_defend_super
				"dead": return body_dead_super

	return null

func activate_hitbox_for_state(state_name: String) -> void:
	if not is_instance_valid(player):
		return

	disable_all_hitboxes()
	var hitbox := get_hitbox_for_state(player.form, state_name)
	set_hitbox_enabled(hitbox, true)

func refresh_hitbox_for_current_state() -> void:
	if not is_instance_valid(player):
		return

	match player.state:
		player.State.DEAD:
			activate_hitbox_for_state("dead")

		player.State.CROUCH:
			activate_hitbox_for_state("crouch")

		player.State.DASH:
			activate_hitbox_for_state("dash")

		player.State.SWIM:
			activate_hitbox_for_state("swim")

		player.State.ATTACK, player.State.SPECIAL_ATTACK:
			activate_hitbox_for_state("attack")

		player.State.DEFEND:
			activate_hitbox_for_state("defend")

		player.State.JUMP:
			if not player.is_on_floor():
				if player.velocity.y < 0.0:
					activate_hitbox_for_state("jump")
				else:
					activate_hitbox_for_state("fall")
			else:
				activate_hitbox_for_state("idle")

		_:
			if not player.is_on_floor():
				if player.velocity.y < 0.0:
					activate_hitbox_for_state("jump")
				else:
					activate_hitbox_for_state("fall")
			else:
				if abs(player.velocity.x) > 0.0:
					activate_hitbox_for_state("walk")
				else:
					activate_hitbox_for_state("idle")

func deactivate_all_attack_areas() -> void:
	var areas: Array[Area2D] = [
		attack_area_normal,
		attack_area_bubble,
		attack_area_super
	]

	for area in areas:
		if is_instance_valid(area):
			area.monitoring = false
			area.monitorable = false

			for child in area.get_children():
				if child is CollisionShape2D:
					child.disabled = true

func activate_attack_area(area: Area2D) -> void:
	if not is_instance_valid(area):
		return

	area.monitoring = true
	area.monitorable = true

	for child in area.get_children():
		if child is CollisionShape2D:
			child.disabled = false

func activate_attack_area_for_current_form() -> void:
	match player.form:
		player.Form.NORMAL:
			activate_attack_area(attack_area_normal)
		player.Form.BUBBLE:
			activate_attack_area(attack_area_bubble)
		player.Form.SUPER:
			activate_attack_area(attack_area_super)

func get_current_attack_area() -> Area2D:
	match player.form:
		player.Form.NORMAL:
			return attack_area_normal
		player.Form.BUBBLE:
			return attack_area_bubble
		player.Form.SUPER:
			return attack_area_super
	return null

func get_current_special_attack_area() -> Area2D:
	match player.form:
		player.Form.NORMAL:
			return special_attack_area_normal
		player.Form.BUBBLE:
			# Bubble agora compartilha a área especial do SUPER
			return special_attack_area_super
		player.Form.SUPER:
			return special_attack_area_super
	return null

# ================================
#         FLIP / HITBOX
# ================================
func verify_position(direction: Vector2) -> void:
	if direction.x > 0.0:
		flip_h = false
		flip_attack_areas(false)
	elif direction.x < 0.0:
		flip_h = true
		flip_attack_areas(true)

func flip_attack_areas(facing_left: bool) -> void:
	var areas: Array[Area2D] = [
		attack_area_normal,
		attack_area_bubble,
		attack_area_super,
		special_attack_area_normal,
		special_attack_area_bubble,
		special_attack_area_super
	]

	for area in areas:
		if is_instance_valid(area):
			if facing_left:
				area.scale.x = -abs(area.scale.x)
			else:
				area.scale.x = abs(area.scale.x)

# ================================
#     CALLBACK: FIM DA ANIMAÇÃO
# ================================
func _on_animation_finished() -> void:
	if not is_instance_valid(player):
		return

	var anim_name: StringName = animation

	var special_anims: Array[StringName] = [
		special_attack_anim_normal,
		special_attack_anim_bubble,
		special_attack_anim_super
	]

	match anim_name:
		&"attack", &"attack_super", &"attack_bubble", &"attack_projectile", &"parry_super", &"parry", &"parry_bubble", &"super_shield":
			deactivate_all_attack_areas()
			deactivate_all_special_attack_areas()
			refresh_hitbox_for_current_state()
			attack_finished.emit()

		&"bubble_throw", &"bubble_throw_arrive":
			refresh_hitbox_for_current_state()
			deactivate_all_attack_areas()
			deactivate_all_special_attack_areas()
			attack_finished.emit()

		_:
			if anim_name in special_anims:
				deactivate_all_attack_areas()
				deactivate_all_special_attack_areas()
				refresh_hitbox_for_current_state()
				attack_finished.emit()
				
			elif player.state == player.State.TRANSFORM:
				player.form = player.target_form
				player.change_state(player.State.IDLE)
				refresh_hitbox_for_current_state()

				if player.has_method("refresh_stompers_for_current_form"):
					player.refresh_stompers_for_current_form()

				if player.has_method("update_audio_by_form"):
					player.update_audio_by_form()
