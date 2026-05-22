extends Area2D

@export var speed: float = 200.0
@export var max_distance: float = 300.0

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2


func _ready() -> void:
	start_position = global_position
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func setup(spawn_direction: Vector2) -> void:
	direction = spawn_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.distance_to(start_position) >= max_distance:
		_hit_position(global_position)


func _on_body_entered(body: Node2D) -> void:
	_hit_position(global_position)


func _on_area_entered(area: Area2D) -> void:
	_hit_position(global_position)


func _hit_position(pos: Vector2) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("_on_portal_bubble_hit"):
		player._on_portal_bubble_hit(pos)
	queue_free()
