extends Area2D

@export var soap_value: int = 1
@export var float_amplitude: float = 3.0
@export var float_speed: float = 2.0
@export var lifetime: float = 8.0
@export var pickup_flash_time: float = 0.5

var _elapsed: float = 0.0
var _base_y: float = 0.0
var _picked: bool = false
var _lifetime_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	_base_y = position.y
	_lifetime_timer = lifetime
	add_to_group("coins")

	var space := get_world_2d().direct_space_state
	if space:
		var query := PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + Vector2(0, 200),
			1
		)
		var result := space.intersect_ray(query)
		if result and result.has("position"):
			global_position.y = result.position.y
			_base_y = position.y

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if _picked:
		return

	_elapsed += delta
	_lifetime_timer -= delta

	position.y = _base_y + sin(_elapsed * float_speed) * float_amplitude

	if _lifetime_timer <= pickup_flash_time:
		var flash := sin(_elapsed * 20.0) * 0.5 + 0.5
		sprite.modulate.a = flash
		if _lifetime_timer <= 0.0:
			queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _picked:
		return
	if body.is_in_group("player"):
		_pickup()


func _on_area_entered(area: Area2D) -> void:
	if _picked:
		return
	if area.is_in_group("player") or area.is_in_group("killer"):
		_pickup()


func _pickup() -> void:
	_picked = true
	collision.set_deferred("disabled", true)
	sprite.visible = false

	GameManager.add_soap(soap_value)

	if audio and audio.stream:
		audio.play()
		await audio.finished

	queue_free()
