extends Area2D

@export var speed: float = 220.0
@export var max_distance: float = 250.0
@export var grow_time: float = 0.3
@export var start_scale: float = 0.05
@export var end_scale: float = 1.0

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var travel_time: float = 0.0


func _ready() -> void:
	start_position = global_position
	scale = Vector2(start_scale, start_scale)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func setup(spawn_direction: Vector2) -> void:
	direction = spawn_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT


func _process(delta: float) -> void:
	travel_time += delta
	var t := minf(travel_time / grow_time, 1.0)
	var s := start_scale + (end_scale - start_scale) * t
	scale = Vector2(s, s)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.distance_to(start_position) >= max_distance:
		_arrived()


func _on_body_entered(body: Node2D) -> void:
	_arrived()


func _on_area_entered(area: Area2D) -> void:
	_arrived()


func _arrived() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		if player.has_method("_on_teleport_bubble_arrived"):
			player._on_teleport_bubble_arrived(global_position)
	queue_free()
