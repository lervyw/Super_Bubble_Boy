# EnemySimple.gd
extends CharacterBody2D

# =========================================================
#  INIMIGO COMUM SIMPLES
#  - Move até o player (andar/pular/voar)
#  - Por padrão, "pula aos poucos" quando perseguindo (MoveMode.JUMP)
#  - Ataca ativando uma hitbox por poucos ms
#  - Dano via Player.take_damage()
# =========================================================


# ==========================
# ===== CONFIGURAÇÕES ======
# ==========================
enum MoveMode { WALK, JUMP, FLY }

@export_group("Target")
@export var player_group: StringName = "player"

@export_group("Movement")
@export var move_mode: MoveMode = MoveMode.JUMP
@export var speed: float = 70.0
@export var gravity: float = 900.0
@export var jump_force: float = -260.0
@export var jump_interval: float = 0.35 # menor que o boss (pula mais)
@export var fly_y_speed: float = 70.0
@export var fly_vertical_follow: bool = true

@export_group("AI")
@export var aggro_range: float = 260.0
@export var stop_distance: float = 40.0

@export_group("Attack")
@export var damage: int = 1
@export var attack_range: float = 48.0
@export var hitbox_active_time: float = 0.10
@export var attack_cooldown: float = 0.85
# ==========================
# ===== VIDA DO INIMIGO =====
# ==========================
@export var max_health: int = 3
var health: int = max_health

@export_group("Nodes")
@export var hitbox_path: NodePath = NodePath("AttackHitbox")
@export var hurtbox_path: NodePath = NodePath("Hurtbox")
@onready var hurtbox: Area2D = get_node_or_null(hurtbox_path)

# ==========================
# ===== RUNTIME VARS =======
# ==========================
var player: Node2D
var cooldown_t: float = 0.0
var jump_t: float = 0.0
var attacking: bool = false
var stunned: bool = false


@onready var hitbox: Area2D = get_node_or_null(hitbox_path)
@onready var hitbox_shape: CollisionShape2D = (
	hitbox.get_node_or_null("CollisionShape2D") if hitbox else null
)


# ==========================
# ========= READY ==========
# ==========================
func _ready() -> void:
	player = get_tree().get_first_node_in_group(player_group) as Node2D

	if hitbox_shape:
		hitbox_shape.disabled = true

	if hitbox:
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)
	if hurtbox:
		if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_hurtbox_area_entered)



# ==========================
# ===== LOOP FÍSICO ========
# ==========================
func _physics_process(delta: float) -> void:
	if cooldown_t > 0.0:
		cooldown_t -= delta
	if jump_t > 0.0:
		jump_t -= delta

	if move_mode != MoveMode.FLY and not is_on_floor():
		velocity.y += gravity * delta
	elif move_mode == MoveMode.FLY:
		velocity.y = 0.0

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(player_group) as Node2D

	if not is_instance_valid(player):
		velocity.x = 0.0
		move_and_slide()
		return

	var dist := global_position.distance_to(player.global_position)
	if dist > aggro_range:
		velocity.x = 0.0
		move_and_slide()
		return
	# ataque perto
	if not stunned and not attacking and cooldown_t <= 0.0 and dist <= attack_range:
		start_attack()
		velocity.x = 0.0
		move_and_slide()
		return

	move_towards_player(delta, dist)
	move_and_slide()


# ==========================
# ===== MOVIMENTO ==========
# ==========================
func move_towards_player(delta: float, dist: float) -> void:
	var dir: int = int(sign(player.global_position.x - global_position.x))
	if dir == 0: dir = 1

	if dist <= stop_distance:
		velocity.x = 0.0
		return

	match move_mode:
		MoveMode.WALK:
			velocity.x = dir * speed

		MoveMode.JUMP:
			# locomove pulando sempre que possível
			velocity.x = dir * speed
			if is_on_floor() and jump_t <= 0.0:
				velocity.y = jump_force
				jump_t = jump_interval

		MoveMode.FLY:
			velocity.x = dir * speed
			if fly_vertical_follow:
				var dy := player.global_position.y - global_position.y
				velocity.y = clamp(dy, -1.0, 1.0) * fly_y_speed


# ==========================
# ===== ATAQUE (HITBOX) ====
# ==========================
func start_attack() -> void:
	attacking = true
	cooldown_t = attack_cooldown

	if hitbox_shape:
		hitbox_shape.disabled = false

	await get_tree().create_timer(hitbox_active_time).timeout

	if hitbox_shape:
		hitbox_shape.disabled = true

	attacking = false

# ==========================
# ===== RECEBER DANO =======
# ==========================
func take_damage(amount: int) -> void:
	health -= amount

	# Desativa ataque e aplica stun
	stunned = true
	attacking = false
	if hitbox_shape:
		hitbox_shape.disabled = true

	# Timer de 1 segundo para sair do stun
	await get_tree().create_timer(1.0).timeout
	stunned = false

	if health <= 0:
		die()

func die() -> void:
	# garante que todas colisões estão desativadas
	if $CollisionShape2D:
		$CollisionShape2D.disabled = true
	if hitbox_shape:
		hitbox_shape.disabled = true
	if hurtbox and hurtbox.get_node("CollisionShape2D"):
		hurtbox.get_node("CollisionShape2D").disabled = true

	queue_free()  # remove o inimigo da cena



# ==========================
# ===== DANO NO PLAYER =====
# ==========================
func apply_damage_to(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
		return

	if target.has_node("Stats"):
		var stats = target.get_node("Stats")
		if stats and stats.has_method("take_damage"):
			stats.take_damage(damage)

func _on_hitbox_body_entered(body: Node) -> void:
	if not attacking:
		return
	if body and body.is_in_group(player_group):
		apply_damage_to(body)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not attacking:
		return
	if not area:
		return
	var p := area.get_parent()
	if p and p.is_in_group(player_group):
		apply_damage_to(p)

# ==========================
# ===== DANO NO INIMIGO ====
# ==========================
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("killer"):
		take_damage(resolve_attack_damage(area))
		print("levou dano do player")
	# Se o player pisar em cima (ex.: colisão vertical negativa)
	var p := area.get_parent()
	if p and p.is_in_group(player_group):
		var dy: float = p.global_position.y - global_position.y
		if dy < -10.0:  # player está acima do inimigo
			# desativa colisões imediatamente
			if $CollisionShape2D:
				$CollisionShape2D.disabled = true
			if hitbox_shape:
				hitbox_shape.disabled = true
			if hurtbox and hurtbox.get_node("CollisionShape2D"):
				hurtbox.get_node("CollisionShape2D").disabled = true

			die()  # remove o inimigo da cena
			print("player pisou no inimigo")


func resolve_attack_damage(area: Area2D) -> int:
	if area == null:
		return 2
	if area.has_meta("attack_damage"):
		return int(area.get_meta("attack_damage"))
	return 2
