extends Area2D

const ATTACK_META_DAMAGE := &"attack_damage"
const ATTACK_META_KIND := &"attack_kind"
const ATTACK_META_ID := &"attack_id"
const PROJECTILE_DIRECT_DAMAGE_META := &"projectile_direct_damage"

@export var speed: float = 180.0
@export var max_distance: float = 260.0
@export var damage: int = 1
@export var vertical_wave_amplitude: float = 0.0
@export var vertical_wave_speed: float = 7.0
@export var is_player_projectile: bool = false
@export var sprite_faces_left: bool = false
@export var attack_id: StringName = &"projectile"
@export var hit_groups: Array[StringName] = []
@export var hurtbox_groups: Array[StringName] = []

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var wave_time: float = 0.0


func _ready() -> void:
	start_position = global_position
	if is_player_projectile:
		add_to_group("player_attack")
		set_meta(ATTACK_META_DAMAGE, damage)
		set_meta(ATTACK_META_KIND, 2)
		set_meta(ATTACK_META_ID, String(attack_id))
		set_meta(PROJECTILE_DIRECT_DAMAGE_META, true)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.flip_h = direction.x > 0.0 if sprite_faces_left else direction.x < 0.0
		sprite.play()


func setup(spawn_direction: Vector2, projectile_damage: int = -1) -> void:
	direction = spawn_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	if projectile_damage > 0:
		damage = projectile_damage


func _physics_process(delta: float) -> void:
	wave_time += delta
	var wave := Vector2.ZERO
	if vertical_wave_amplitude > 0.0:
		wave.y = sin(wave_time * vertical_wave_speed) * vertical_wave_amplitude

	global_position += direction * speed * delta + wave * delta

	if global_position.distance_to(start_position) >= max_distance:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(node: Node) -> void:
	var target := _resolve_target(node)
	if target and target.has_method("take_damage"):
		target.take_damage(damage)
		queue_free()


func _resolve_target(node: Node) -> Node:
	var current := node
	while current != null:
		if _matches_groups(current, hit_groups):
			return current
		if _matches_groups(current, hurtbox_groups):
			return current.get_parent()
		current = current.get_parent()
	return null


func _matches_groups(node: Node, groups: Array[StringName]) -> bool:
	for group_name in groups:
		if node.is_in_group(group_name):
			return true
	return false
