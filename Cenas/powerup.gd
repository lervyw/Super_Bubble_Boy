extends Area2D

@export var player: CharacterBody2D
@export var stats: Node

@export var unlock_form: int = -1        # usa ENUM Form
@export var health_increase: int = 0
@export var max_health_increase: int = 0
@export var update_respawn: bool = false
@export var respawn_position: Vector2

@export var pickup_sound: AudioStreamPlayer
@export var pickup_particles: Node2D

func _ready():
	if not player:
		push_error("PowerUp: Player não definido!")
	if not stats:
		push_error("PowerUp: Stats não definidos!")
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body != player:
		return

	# ⭐ 1. Cura HP
	if health_increase != 0:
		stats.update_health("Increase", health_increase)

	# ⭐ 2. Aumenta vida máxima
	if max_health_increase != 0:
		stats.max_health += max_health_increase
		stats.update_max_health_by_form()

	# ⭐ 3. Libera Forma
	if unlock_form >= 0:
		player.unlocked_forms[unlock_form] = true
		print("🔓 Forma desbloqueada:", unlock_form)

	# ⭐ 4. Atualiza Respawn (opcional)
	if update_respawn:
		player.respawn_position = respawn_position
		print("📍 Respawn atualizado pelo PowerUp.")

	# ⭐ 5. Som
	if pickup_sound:
		pickup_sound.play()

	# ⭐ 6. Partículas
	if pickup_particles:
		pickup_particles.visible = true
		if pickup_particles.has_method("restart"):
			pickup_particles.restart()

	# Dá tempo para os efeitos tocarem
	await get_tree().create_timer(0.2).timeout

	queue_free()
