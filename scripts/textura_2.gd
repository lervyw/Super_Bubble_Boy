extends Sprite2D

@export var player: Node
@export var animation: AnimationPlayer
@export var stats: Node
@export var nivel: Node
@export var attack_area: Area2D

var crouch_off: bool = false

# ---------------------------------------------------
func _process(delta: float) -> void:
	if not player:
		return
	
	# Captura a direção atual (usada nas animações de movimento)
	var direction := Vector2.ZERO
	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	verify_position(direction)
	update_animation(direction)
# ---------------------------------------------------

func update_animation(direction: Vector2) -> void:
	match player.state:
		player.State.TRANSFORM:
			handle_transform_animation()
		player.State.DEAD:
			handle_death_animation()
		player.State.ATTACK:
			handle_attack_animation()
		player.State.DASH:
			animation.play("dash")
		player.State.CROUCH:
			handle_crouch_animation()
		player.State.JUMP, player.State.WALK, player.State.IDLE:
			handle_movement_animation(direction)
		player.State.SWIM:
			animation.play("Swim")
		_:
			pass
# ---------------------------------------------------

# 🔹 Movimento (Idle / Walk / Jump / Fall)
func handle_movement_animation(direction: Vector2) -> void:
	match player.form:
		player.Form.NORMAL:
			if not player.is_on_floor():
				if direction.y > 0:
					animation.play("Fall")
				elif direction.y < 0:
					animation.play("Jump")
				else:
					animation.play("Idle")
			elif abs(direction.x) > 0:
				animation.play("Walk")
			else:
				animation.play("Idle")

		player.Form.BUBBLE:
			animation.play("Bubble_only")

		player.Form.SUPER:
			if not player.is_on_floor():
				if direction.y > 0:
					animation.play("S_Fall")
				elif direction.y < 0:
					animation.play("S_Jump")
				else:
					animation.play("S_Idle")
			elif abs(direction.x) > 0:
				animation.play("S_Walk")
			else:
				animation.play("S_Idle")
# ---------------------------------------------------

# 🔹 Transformações (Normal <-> Bubble <-> Super)
func handle_transform_animation() -> void:
	var current_form = player.form
	var target_form = player.target_form if "target_form" in player else null
	var anim_name := ""

	if target_form == null:
		return

	match [current_form, target_form]:
		[player.Form.NORMAL, player.Form.BUBBLE]:
			anim_name = "Normal_Bolha"
		[player.Form.NORMAL, player.Form.SUPER]:
			anim_name = "Normal_Super"
		[player.Form.BUBBLE, player.Form.NORMAL]:
			anim_name = "Bolha_Normal"
		[player.Form.BUBBLE, player.Form.SUPER]:
			anim_name = "Bolha_Super"
		[player.Form.SUPER, player.Form.BUBBLE]:
			anim_name = "Super_Bolha"
		[player.Form.SUPER, player.Form.NORMAL]:
			anim_name = "Super_Normal"
		_:
			anim_name = "Transform"

	animation.play(anim_name)
# ---------------------------------------------------

# 🔹 Ataques
func handle_attack_animation() -> void:
	match player.form:
		player.Form.SUPER:
			animation.play("S_attack")
		_:
			animation.play("T_attack")
# ---------------------------------------------------

# 🔹 Agachar
func handle_crouch_animation() -> void:
	match player.form:
		player.Form.SUPER:
			animation.play("S_crouch")
		player.Form.NORMAL:
			animation.play("N_c_loop")
		player.Form.BUBBLE:
			animation.play("Bubble_only")
# ---------------------------------------------------

# 🔹 Morte
func handle_death_animation() -> void:
	match player.form:
		player.Form.NORMAL:
			animation.play("Dead_normal")
		player.Form.BUBBLE:
			animation.play("B_dead")
		player.Form.SUPER:
			animation.play("S_dead")
# ---------------------------------------------------

# 🔹 Espelhar sprite e área de ataque
func verify_position(direction: Vector2) -> void:
	if direction.x > 0:
		flip_h = false
		if attack_area:
			attack_area.scale.x = 1
	elif direction.x < 0:
		flip_h = true
		if attack_area:
			attack_area.scale.x = -1
# ---------------------------------------------------

func _on_animacao_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Normal_Bolha":
			player.form = player.Form.BUBBLE
		"Normal_Super":
			player.form = player.Form.SUPER
		"Bolha_Normal":
			player.form = player.Form.NORMAL
		"Bolha_Super":
			player.form = player.Form.SUPER
		"Super_Normal":
			player.form = player.Form.NORMAL
		"Super_Bolha":
			player.form = player.Form.BUBBLE
		"Hit", "Hit_Bolha", "Hit_Super":
			player.on_hit = false
		"Dead_normal", "S_dead", "B_dead":
			get_tree().reload_current_scene()
		"T_attack", "S_attack", "S_parry", "dash":
			player.set_physics_process(true)
			player.attacking = false
			player.dash = false
