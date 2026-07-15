extends CharacterBody2D

const ATTACK_META_DAMAGE := &"attack_damage"

enum Form { NORMAL, SECOND }

signal form_changed(new_form: Form)

@export_group("Target")
@export var player_group: StringName = "jogador"
@export var player_hurtbox_group: StringName = "player_hurtbox"

@export_group("Movement")
@export var speed: float = 70.0
@export var gravity: float = 900.0
@export var jump_force: float = -260.0
@export var jump_interval: float = 0.7

@export_group("Water")
@export_range(0.05, 1.0, 0.05) var water_speed_multiplier: float = 0.55
@export_range(0.05, 1.0, 0.05) var water_gravity_multiplier: float = 0.35
@export_range(0.05, 1.0, 0.05) var water_jump_multiplier: float = 0.65

@export_group("AI")
@export var aggro_range: float = 260.0
@export var stop_distance: float = 28.0
@export var turn_horizontal_threshold: float = 24.0

@export_group("Attack")
@export var damage: int = 1
@export var attack_range: float = 36.0
@export var attack_vertical_range: float = 48.0
@export var hitbox_active_time: float = 0.12
@export var attack_cooldown: float = 0.85
@export_range(0.0, 5.0, 0.05) var hit_reaction_time: float = 1.0
@export_range(-1, 99, 1) var attack_hitbox_start_frame: int = -1
@export_range(-1, 99, 1) var attack_hitbox_end_frame: int = -1

@export_group("Coin Drop")
@export var coin_scene: PackedScene = preload("res://Cenas/coin.tscn")
@export var coin_count: int = 5
@export var coin_spread: float = 24.0
@export_range(0.0, 1.0) var coin_drop_chance: float = 1.0

@export_group("Health")
@export var max_health: int = 4
var health: int = max_health

@export_group("Nodes")
@export var sprite_path: NodePath = NodePath("AnimatedSprite2D")
@export var hitbox_path: NodePath = NodePath("AttackHitbox")
@export var attack_receiver_path: NodePath = NodePath("AttackReceiver")
@export var hurtbox_path: NodePath = NodePath("Hurtbox")
@export var sprite_frames_normal: SpriteFrames
@export var sprite_frames_second: SpriteFrames
@export var sprite_faces_left_by_default: bool = true
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var attack_animation: StringName = &"attack"
@export var got_hit_animation: StringName = &"got_hit"
@export var death_animation: StringName = &"death"
@export var jump_animation: StringName = &"jump"
@export var transform_animation: StringName = &"transform"

@onready var sprite: AnimatedSprite2D = get_node_or_null(sprite_path)
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)
@onready var hitbox_shape: CollisionShape2D = hitbox.get_node_or_null("CollisionShape2D") if hitbox else null
@onready var attack_receiver: Area2D = get_node_or_null(attack_receiver_path)
@onready var hurtbox: Area2D = get_node_or_null(hurtbox_path)
@onready var glow_node: AnimatedSprite2D = $Glow if has_node("Glow") else null

var player: Node2D
var cooldown_t: float = 0.0
var jump_t: float = 0.0
var attacking: bool = false
var stunned: bool = false
var dying: bool = false
var hit_reaction_active: bool = false
var hit_reaction_serial: int = 0
var attack_serial: int = 0
var facing_dir: int = -1
var attack_hitbox_base_position: Vector2 = Vector2.ZERO
var current_form: Form = Form.NORMAL
var in_water: bool = false
var water_zone_overlap_count: int = 0
var time_frozen: bool = false
var time_frozen_velocity: Vector2 = Vector2.ZERO
var time_frozen_sprite_was_playing: bool = false
var is_night: bool = false


func _ready():
	if not is_in_group("inimigo_lopes"):
		add_to_group("inimigo_lopes")

	player = get_tree().get_first_node_in_group(player_group)

	if hitbox_shape:
		attack_hitbox_base_position = hitbox_shape.position
		hitbox_shape.disabled = true

	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	if attack_receiver and not attack_receiver.area_entered.is_connected(_on_attack_receiver_area_entered):
		attack_receiver.area_entered.connect(_on_attack_receiver_area_entered)

	if hurtbox and not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	var day_cycle = get_tree().get_first_node_in_group("dayAndNightCycle")
	if day_cycle:
		day_cycle.changeDayTime.connect(_on_day_time_changed)
		is_night = day_cycle.is_night()
		if is_night:
			set_form(Form.SECOND, true)
	else:
		var scene = get_tree().current_scene
		if scene:
			day_cycle = scene.find_child("DayAndNightCycle", true, false)
			if day_cycle and day_cycle.has_signal("changeDayTime"):
				day_cycle.changeDayTime.connect(_on_day_time_changed)
				if day_cycle.has_method("is_night") and day_cycle.is_night():
					is_night = true
					set_form(Form.SECOND, true)

	update_sprite_direction(facing_dir)
	play_idle_animation()


func _physics_process(delta):
	if dying:
		return
	if time_frozen:
		velocity = Vector2.ZERO
		return

	if cooldown_t > 0:
		cooldown_t -= delta
	if jump_t > 0:
		jump_t -= delta

	if not is_on_floor():
		velocity.y += gravity * get_water_gravity_multiplier() * delta

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(player_group)

	if not is_instance_valid(player):
		velocity.x = 0
		move_and_slide()
		return

	var dist = global_position.distance_to(player.global_position)

	if dist > aggro_range:
		velocity.x = 0
		move_and_slide()
		return

	if not stunned and not attacking and cooldown_t <= 0 and is_player_in_attack_range():
		start_attack()
		return

	if attacking:
		velocity.x = 0
		move_and_slide()
		update_animation()
		return

	move_towards_player(dist)
	move_and_slide()
	update_animation()


func move_towards_player(dist):
	if dist <= stop_distance:
		velocity.x = 0
		return

	var dir: int = get_horizontal_chase_direction()
	if dir == 0:
		velocity.x = 0
		return

	if dir != 0:
		facing_dir = dir
		update_sprite_direction(dir)

	velocity.x = dir * get_water_speed()
	if is_on_floor() and jump_t <= 0:
		velocity.y = jump_force * get_water_jump_multiplier()
		jump_t = jump_interval


func get_horizontal_chase_direction() -> int:
	if not is_instance_valid(player):
		return 0

	var horizontal_delta: float = player.global_position.x - global_position.x
	if absf(horizontal_delta) < turn_horizontal_threshold:
		return 0

	return int(sign(horizontal_delta))


func is_player_in_attack_range() -> bool:
	if not is_instance_valid(player):
		return false

	var to_player := player.global_position - global_position
	if to_player.length() <= attack_range:
		return true

	return absf(to_player.x) <= attack_range and absf(to_player.y) <= attack_vertical_range


func update_sprite_direction(dir: int) -> void:
	if not sprite or dir == 0:
		return

	if sprite_faces_left_by_default:
		sprite.flip_h = dir > 0
	else:
		sprite.flip_h = dir < 0

	update_attack_hitbox_direction(dir)


func update_attack_hitbox_direction(dir: int) -> void:
	if not hitbox_shape:
		return

	hitbox_shape.position = Vector2(
		-attack_hitbox_base_position.x if sprite and sprite.flip_h else attack_hitbox_base_position.x,
		attack_hitbox_base_position.y
	)


func start_attack():
	if attacking or stunned or dying:
		return

	attacking = true
	attack_serial += 1
	var current_attack_serial := attack_serial
	cooldown_t = attack_cooldown
	velocity.x = 0

	play_attack_animation(true)

	if uses_frame_based_hitbox():
		await run_attack_hitbox_by_frames(attack_animation, current_attack_serial)
	else:
		var animation_duration: float = get_animation_duration(attack_animation)
		var hitbox_start_delay: float = get_attack_hitbox_start_delay()

		if hitbox_start_delay > 0:
			await get_tree().create_timer(hitbox_start_delay).timeout
			if not is_current_attack(current_attack_serial):
				return

		if hitbox_shape:
			hitbox_shape.disabled = false

		await get_tree().create_timer(hitbox_active_time).timeout
		if not is_current_attack(current_attack_serial):
			if hitbox_shape:
				hitbox_shape.disabled = true
			return

		if hitbox_shape:
			hitbox_shape.disabled = true

		var remaining_animation_time: float = maxf(animation_duration - hitbox_start_delay - hitbox_active_time, 0.0)
		if remaining_animation_time > 0:
			await get_tree().create_timer(remaining_animation_time).timeout
			if not is_current_attack(current_attack_serial):
				return

	attacking = false
	update_animation()


func is_current_attack(serial: int) -> bool:
	return attacking and not dying and not stunned and serial == attack_serial


func take_damage(amount, _source: Node = null):
	if dying:
		return

	health -= max(amount, 1)
	stunned = true
	attacking = false
	attack_serial += 1
	hit_reaction_serial += 1
	var current_hit_reaction := hit_reaction_serial

	if hitbox_shape:
		hitbox_shape.disabled = true

	if health <= 0:
		die()
		return
	if time_frozen:
		stunned = false
		return

	await play_hit_reaction(current_hit_reaction)

	if dying or current_hit_reaction != hit_reaction_serial:
		return

	stunned = false


func set_time_frozen(frozen: bool) -> void:
	if time_frozen == frozen or dying:
		return
	time_frozen = frozen

	if frozen:
		time_frozen_velocity = velocity
		velocity = Vector2.ZERO
		attacking = false
		attack_serial += 1
		if hitbox_shape:
			hitbox_shape.set_deferred("disabled", true)
		if sprite:
			time_frozen_sprite_was_playing = sprite.is_playing()
			sprite.pause()
	else:
		velocity = time_frozen_velocity
		if sprite and time_frozen_sprite_was_playing:
			sprite.play()


func play_hit_reaction(reaction_serial: int) -> void:
	hit_reaction_active = true

	if has_animation(got_hit_animation):
		play_animation(got_hit_animation)

	var reaction_time := hit_reaction_time
	if has_animation(got_hit_animation):
		reaction_time = maxf(reaction_time, get_animation_duration(got_hit_animation))

	if reaction_time > 0:
		await get_tree().create_timer(reaction_time).timeout

	if reaction_serial == hit_reaction_serial:
		hit_reaction_active = false


func die():
	if dying:
		return

	dying = true

	set_physics_process(false)
	set_collision_layer(0)
	set_collision_mask(0)

	if $CollisionShape2D:
		$CollisionShape2D.set_deferred("disabled", true)

	if hitbox_shape:
		hitbox_shape.set_deferred("disabled", true)

	if hurtbox:
		hurtbox.set_deferred("monitoring", false)

	if attack_receiver:
		attack_receiver.set_deferred("monitoring", false)

	attacking = false

	call_deferred("spawn_coins")

	if has_animation(death_animation):
		play_animation(death_animation)
		await wait_for_animation(death_animation)

	queue_free()


func spawn_coins() -> void:
	if coin_scene == null or coin_count <= 0:
		return
	if randf() > coin_drop_chance:
		return

	var parent := get_tree().current_scene
	if parent == null:
		return

	for i in range(coin_count):
		var coin := coin_scene.instantiate()
		var offset := Vector2(
			randf_range(-coin_spread, coin_spread),
			randf_range(-coin_spread * 0.3, 0.0)
		)
		coin.global_position = global_position + offset
		parent.add_child(coin)


func apply_damage_to(target):
	if target.has_method("take_damage"):
		target.take_damage(damage, self)


func _on_hitbox_body_entered(body):
	if dying or not attacking:
		return
	var target := resolve_damage_target(body)
	if target:
		apply_damage_to(target)


func _on_hitbox_area_entered(area):
	if dying or not attacking:
		return
	var target := resolve_damage_target(area)
	if target:
		apply_damage_to(target)


func _on_attack_receiver_area_entered(area):
	if area == null or dying:
		return

	if area.has_meta(&"projectile_direct_damage"):
		return

	if area.is_in_group("player_attack"):
		take_damage(get_damage_from_area(area, 1))


func _on_hurtbox_area_entered(area):
	if area == null or dying:
		return

	if area.is_in_group("player_stomper"):
		take_damage(get_damage_from_area(area, 1))


func get_damage_from_area(area: Area2D, fallback: int = 1) -> int:
	if area and area.has_meta(ATTACK_META_DAMAGE):
		return max(int(area.get_meta(ATTACK_META_DAMAGE)), 1)
	return max(fallback, 1)


func resolve_damage_target(node: Node) -> Node:
	var current := node
	while current != null:
		if current.is_in_group(player_hurtbox_group):
			return current.get_parent()
		current = current.get_parent()
	return null


func uses_frame_based_hitbox() -> bool:
	return attack_hitbox_start_frame >= 0 and attack_hitbox_end_frame >= attack_hitbox_start_frame


func run_attack_hitbox_by_frames(anim: StringName, serial: int) -> void:
	if not sprite or not has_animation(anim):
		return

	if hitbox_shape:
		hitbox_shape.disabled = true

	var last_frame := -1
	while is_current_attack(serial) and sprite.animation == anim and sprite.is_playing():
		var frame := sprite.frame
		if frame != last_frame:
			update_attack_hitbox_frame_state(frame)
			last_frame = frame
		await get_tree().process_frame

	if hitbox_shape:
		hitbox_shape.disabled = true


func update_attack_hitbox_frame_state(frame: int) -> void:
	if not hitbox_shape:
		return

	var inside_window := frame >= attack_hitbox_start_frame and frame <= attack_hitbox_end_frame
	hitbox_shape.disabled = not inside_window


# ================================
#       FORM / NIGHT SYSTEM
# ================================
func _on_day_time_changed(day_time):
	var is_now_night = (day_time == 1)
	if is_now_night and not is_night:
		is_night = true
		start_transform_to_second()
	elif not is_now_night and is_night:
		is_night = false
		start_transform_to_normal()


func start_transform_to_second():
	if current_form == Form.SECOND or dying:
		return
	stunned = true
	attacking = false
	velocity = Vector2.ZERO

	if has_animation(transform_animation):
		play_animation(transform_animation)
		await wait_for_animation(transform_animation)

	set_form(Form.SECOND)
	stunned = false


func start_transform_to_normal():
	if current_form == Form.NORMAL or dying:
		return
	stunned = true
	attacking = false
	velocity = Vector2.ZERO

	if has_animation(transform_animation):
		play_animation(transform_animation)
		await wait_for_animation(transform_animation)

	set_form(Form.NORMAL)
	stunned = false


func set_form(new_form: Form, instant: bool = false):
	current_form = new_form

	match new_form:
		Form.NORMAL:
			if sprite_frames_normal:
				sprite.sprite_frames = sprite_frames_normal
			set_glow_visible(false)
			speed = 70.0
		Form.SECOND:
			if sprite_frames_second:
				sprite.sprite_frames = sprite_frames_second
			set_glow_visible(true)
			speed = 90.0

	form_changed.emit(new_form)
	update_animation()


func set_glow_visible(visible: bool):
	if glow_node:
		glow_node.visible = visible
		if visible:
			sync_glow_animation()
			start_glow_pulse()
		else:
			stop_glow_pulse()


func sync_glow_animation():
	if not glow_node or not sprite:
		return
	if glow_node.animation != sprite.animation:
		glow_node.animation = sprite.animation
		glow_node.play()
	if glow_node.frame != sprite.frame:
		glow_node.frame = sprite.frame
	if glow_node.flip_h != sprite.flip_h:
		glow_node.flip_h = sprite.flip_h


func start_glow_pulse():
	if not glow_node:
		return
	if glow_node.has_meta(&"pulse_tween"):
		var old = glow_node.get_meta(&"pulse_tween")
		if old and old.is_valid():
			old.kill()
	var tween = create_tween().set_loops()
	tween.tween_method(_set_glow_alpha, 0.2, 0.45, 0.8)
	tween.tween_method(_set_glow_alpha, 0.45, 0.2, 0.8)
	glow_node.set_meta(&"pulse_tween", tween)


func stop_glow_pulse():
	if not glow_node:
		return
	if glow_node.has_meta(&"pulse_tween"):
		var old = glow_node.get_meta(&"pulse_tween")
		if old and old.is_valid():
			old.kill()


func _set_glow_alpha(alpha: float):
	if glow_node:
		var c = glow_node.modulate
		c.a = alpha
		glow_node.modulate = c


# ================================
#      WATER
# ================================
func enter_water_zone(_water: Node = null) -> void:
	water_zone_overlap_count += 1
	in_water = true


func exit_water_zone(_water: Node = null) -> void:
	water_zone_overlap_count = max(water_zone_overlap_count - 1, 0)
	in_water = water_zone_overlap_count > 0


func get_water_speed_multiplier() -> float:
	return water_speed_multiplier if in_water else 1.0


func get_water_gravity_multiplier() -> float:
	return water_gravity_multiplier if in_water else 1.0


func get_water_jump_multiplier() -> float:
	return water_jump_multiplier if in_water else 1.0


func get_water_speed() -> float:
	return speed * get_water_speed_multiplier()


# ================================
#      ANIMATIONS
# ================================
func update_animation():
	if sprite == null or dying:
		return

	if hit_reaction_active:
		play_animation(got_hit_animation)
	elif attacking:
		play_attack_animation()
	elif not is_on_floor():
		play_animation(jump_animation)
	elif abs(velocity.x) > 5:
		play_walk_animation()
	else:
		play_idle_animation()

	if glow_node and glow_node.visible:
		sync_glow_animation()


func play_idle_animation():
	play_animation(idle_animation)


func play_walk_animation():
	play_animation(walk_animation)


func play_attack_animation(restart: bool = false):
	if restart:
		restart_animation(attack_animation)
		return
	play_animation(attack_animation)


func wait_for_animation(anim):
	if not has_animation(anim):
		return

	var duration = get_animation_duration(anim)
	if duration > 0:
		await get_tree().create_timer(duration).timeout


func get_attack_hitbox_start_delay() -> float:
	var total = get_animation_duration(attack_animation)
	return maxf(total - hitbox_active_time, 0)


func get_animation_duration(anim):
	if not has_animation(anim):
		return 0

	var frames = sprite.sprite_frames.get_frame_count(anim)
	var speed = maxf(sprite.sprite_frames.get_animation_speed(anim), 1.0)

	return float(frames) / speed


func has_animation(anim):
	return sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim)


func play_animation(anim):
	if has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


func restart_animation(anim: StringName) -> void:
	if not has_animation(anim):
		return
	sprite.stop()
	sprite.animation = anim
	sprite.set_frame_and_progress(0, 0.0)
	sprite.play(anim)
