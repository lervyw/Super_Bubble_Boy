extends CharacterBody2D

@export var soap_value: int = 1
@export var float_amplitude: float = 3.0
@export var float_speed: float = 2.0
@export var lifetime: float = 8.0
@export var pickup_flash_time: float = 0.5

@export_group("Drop Physics")
@export var drop_gravity: float = 350.0
@export var pop_horizontal_speed: float = 45.0
@export var pop_vertical_speed: float = 80.0

var _elapsed: float = 0.0
var _base_y: float = 0.0
var _picked: bool = false
var _lifetime_timer: float = 0.0
var _landed: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	_lifetime_timer = lifetime
	add_to_group("coins")

	velocity = Vector2(
		randf_range(-pop_horizontal_speed, pop_horizontal_speed),
		-pop_vertical_speed
	)

	pickup_area.body_entered.connect(_on_body_entered)
	pickup_area.area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _picked or _landed:
		return

	velocity.y += drop_gravity * delta
	move_and_slide()

	if is_on_floor():
		velocity = Vector2.ZERO
		_landed = true
		_base_y = position.y


func _process(delta: float) -> void:
	if _picked or not _landed:
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
	if body.is_in_group("jogador"):
		_pickup()


func _on_area_entered(area: Area2D) -> void:
	if _picked:
		return
	if area.is_in_group("player_hurtbox"):
		_pickup()


func _pickup() -> void:
	_picked = true
	pickup_area.set_deferred("monitoring", false)
	sprite.visible = false

	GameManager.add_soap(soap_value)

	if audio and audio.stream:
		audio.play()
		await audio.finished

	queue_free()
