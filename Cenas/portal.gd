extends Area2D

const TELEPORT_COOLDOWN: float = 0.5

@export var player_ref: Node = null
@export var portal_sprite: Sprite2D
@export var glow_sprite: Sprite2D

var linked_portal: Node = null
var teleport_cooldown: float = 0.0
var activated: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if teleport_cooldown > 0.0:
		teleport_cooldown = max(teleport_cooldown - delta, 0.0)


func _on_body_entered(body: Node2D) -> void:
	_try_teleport(body)


func _on_area_entered(area: Area2D) -> void:
	var parent := area.get_parent()
	if parent == player_ref:
		_try_teleport(parent)


func _try_teleport(target: Node) -> void:
	if target != player_ref:
		return
	if not linked_portal or not is_instance_valid(linked_portal):
		return
	if not is_instance_valid(player_ref):
		return
	if teleport_cooldown > 0.0:
		return

	teleport_cooldown = TELEPORT_COOLDOWN
	if linked_portal.has_method("set_teleport_cooldown"):
		linked_portal.set_teleport_cooldown(TELEPORT_COOLDOWN)

	var portal_pos: Vector2 = linked_portal.global_position
	player_ref.global_position = portal_pos


func set_teleport_cooldown(value: float) -> void:
	teleport_cooldown = max(teleport_cooldown, value)


func try_deactivate_by_player() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	if player_ref.has_method("deactivate_portal"):
		player_ref.deactivate_portal(self)
