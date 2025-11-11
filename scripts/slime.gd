extends CharacterBody2D

@onready var animation_sprite = $AnimatedSprite2D
@onready var particles = $CPUParticles2D
@onready var hit_area = $Hit
@onready var damage_area = $DamageArea
@onready var raycast_right: RayCast2D = get_node_or_null("RaycastRight")
@onready var raycast_left: RayCast2D = get_node_or_null("RaycastLeft")

@export_group("Movement")
@export var patrol_speed: float = 20.0
@export var chase_speed: float = 40.0
@export var jump_force: float = -250.0
@export var gravity_strength: float = 900.0

@export_group("AI")
@export var detection_range: float = 100.0
@export var stop_chase_distance: float = 10.0
@export var use_raycast_detection: bool = true
@export var detect_ledges: bool = true

@export_group("Bounce System")
@export var bounce_on_hit: bool = true
@export var bounce_force: float = -200.0
@export var bounce_distance: float = 100.0
@export var min_distance_to_player: float = 30.0

@export_group("Attack")
@export var damage_amount: int = 1
@export var attack_cooldown: float = 1.0
@export var jump_attack_force: float = -300.0
@export var jump_attack_horizontal_speed: float = 80.0

var player: Node2D = null
var is_chasing: bool = false
var move_direction: float = 1.0
var is_dead: bool = false
var is_bouncing: bool = false
var attack_cooldown_timer: float = 0.0
var is_attacking: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Slime: Player não encontrado no grupo 'player'")
	setup_edge_detection()

	if damage_area:
		if not damage_area.body_entered.is_connected(_on_damage_area_body_entered):
			damage_area.body_entered.connect(_on_damage_area_body_entered)
		if not damage_area.area_entered.is_connected(_on_damage_area_area_entered):
			damage_area.area_entered.connect(_on_damage_area_area_entered)

func setup_edge_detection() -> void:
	if detect_ledges:
		if not raycast_right:
			raycast_right = create_edge_raycast("RaycastRight", Vector2(12, 0))
		if not raycast_left:
			raycast_left = create_edge_raycast("RaycastLeft", Vector2(-12, 0))
		if raycast_right:
			configure_raycast(raycast_right, Vector2(15, 20))
		if raycast_left:
			configure_raycast(raycast_left, Vector2(-15, 20))

func create_edge_raycast(name: String, offset: Vector2) -> RayCast2D:
	var rc = RayCast2D.new()
	rc.name = name
	rc.position = offset
	rc.enabled = true
	rc.collide_with_bodies = true
	rc.collision_mask = 1
	add_child(rc)
	return rc

func configure_raycast(rc: RayCast2D, target_pos: Vector2) -> void:
	rc.enabled = true
	rc.target_position = target_pos
	rc.collide_with_bodies = true
	rc.collision_mask = 1
	rc.exclude_parent = false

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity_strength * delta

	attack_cooldown_timer -= delta

	if is_bouncing:
		if is_on_floor():
			is_bouncing = false
	elif is_attacking:
		handle_attack_motion()
	elif player:
		update_ai()
	else:
		patrol()

	handle_animation()
	move_and_slide()

func update_ai() -> void:
	var distance_to_player = get_distance_to_player()

	if distance_to_player < min_distance_to_player:
		retreat_from_player()
		return

	if distance_to_player <= detection_range:
		if use_raycast_detection and not can_see_player():
			is_chasing = false
			patrol()
		else:
			is_chasing = true
			chase_player()
	else:
		is_chasing = false
		patrol()

func get_distance_to_player() -> float:
	if not player:
		return INF
	return global_position.distance_to(player.global_position)

func retreat_from_player() -> void:
	if not player:
		return
	var away_dir = -sign(player.global_position.x - global_position.x)
	velocity.x = away_dir * patrol_speed
	update_flip(away_dir)

func can_see_player() -> bool:
	if not player:
		return false
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func chase_player() -> void:
	var distance = get_distance_to_player()
	var direction = sign(player.global_position.x - global_position.x)
	update_flip(direction)

	if distance < stop_chase_distance:
		velocity.x = 0
		return

	# Ataque por salto quando próximo
	if distance < 70 and attack_cooldown_timer <= 0 and is_on_floor():
		start_jump_attack(direction)
	else:
		velocity.x = direction * chase_speed
		if is_on_wall() and is_on_floor():
			velocity.y = jump_force

func start_jump_attack(direction: float) -> void:
	is_attacking = true
	attack_cooldown_timer = attack_cooldown
	velocity.y = jump_attack_force
	velocity.x = direction * jump_attack_horizontal_speed
	animation_sprite.play("jump_attack")
	print("🧨 Slime iniciou salto em direção ao player!")

func handle_attack_motion() -> void:
	# Se pousou, fim do ataque
	if is_on_floor():
		is_attacking = false

func patrol() -> void:
	velocity.x = move_direction * patrol_speed
	update_flip(move_direction)
	if is_on_wall():
		move_direction *= -1
		if is_on_floor():
			velocity.y = jump_force
	if detect_ledges and is_on_floor():
		check_ledges()

func check_ledges() -> void:
	if move_direction > 0 and raycast_right and not raycast_right.is_colliding():
		move_direction *= -1
		if is_on_floor():
			velocity.y = jump_force
	elif move_direction < 0 and raycast_left and not raycast_left.is_colliding():
		move_direction *= -1
		if is_on_floor():
			velocity.y = jump_force

func deal_damage_to_player(player_body: Node2D) -> void:
	if attack_cooldown_timer > 0 or is_dead or is_bouncing:
		return

	var dealt = false
	if player_body.has_method("take_damage"):
		player_body.take_damage(damage_amount)
		dealt = true
	elif player_body.has_node("Stats"):
		var stats = player_body.get_node("Stats")
		if stats.has_method("take_damage"):
			stats.take_damage(damage_amount)
			dealt = true

	if dealt:
		print("💥 Slime causou dano no player!")
		if player_body is CharacterBody2D:
			var dir = sign(player_body.global_position.x - global_position.x)
			player_body.velocity.x = dir * 300
			player_body.velocity.y = -150

		if bounce_on_hit:
			execute_bounce(player_body)

		attack_cooldown_timer = attack_cooldown

func execute_bounce(player_body: Node2D) -> void:
	var bounce_dir = -sign(player_body.global_position.x - global_position.x)
	velocity.x = bounce_dir * bounce_distance
	velocity.y = bounce_force
	is_bouncing = true

	if particles:
		particles.emitting = true
		await get_tree().create_timer(0.3).timeout
		if particles:
			particles.emitting = false
	print("🔄 Slime deu bounce!")

func update_flip(direction: float) -> void:
	if direction > 0:
		animation_sprite.flip_h = true
	elif direction < 0:
		animation_sprite.flip_h = false

func handle_animation() -> void:
	if is_dead:
		return
	if is_bouncing:
		animation_sprite.play("bounce" if animation_sprite.sprite_frames.has_animation("bounce") else "fall")
	elif is_attacking:
		if animation_sprite.sprite_frames.has_animation("jump_attack"):
			animation_sprite.play("jump_attack")
		else:
			animation_sprite.play("jump")
	elif not is_on_floor():
		animation_sprite.play("fall")
	elif abs(velocity.x) > 0:
		animation_sprite.play("walk")
	else:
		animation_sprite.play("idle")

func take_damage() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if hit_area:
		hit_area.set_deferred("monitoring", false)
	if damage_area:
		damage_area.set_deferred("monitoring", false)
	animation_sprite.visible = false
	if particles:
		particles.emitting = true
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _on_hit_area_entered(area: Area2D) -> void:
	if area.is_in_group("stomper") or area.is_in_group("killer"):
		take_damage()

func _on_damage_area_body_entered(body: Area2D) -> void:
	if is_dead:
		return
	if body.is_in_group("player"):
		deal_damage_to_player(body)

func _on_damage_area_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.is_in_group("player_hurtbox") or area.is_in_group("player"):
		var p = area.get_parent()
		if p and p.is_in_group("player"):
			deal_damage_to_player(p)
