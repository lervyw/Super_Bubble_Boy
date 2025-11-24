extends Area2D

@export var player: CharacterBody2D
@export var stats: Node
@export var update_respawn: bool = false
@export var respawn_node: Node2D

func _ready() -> void:
	if not player:
		push_error("BubbleUp1: Player reference não foi definida!")
	if not stats:
		push_error("BubbleUp1: Stats reference não foi definida!")

func _on_body_entered(body: Node2D) -> void:
	if body != player:
		return

	# Cura leve
	if stats and stats.has_method("update_health"):
		stats.update_health("Increase", 1)

	# Desbloqueia Bubble
	player.unlocked_forms[player.Form.BUBBLE] = true

	# Respawn opcional
	if update_respawn and respawn_node:
		player.respawn_position = respawn_node.global_position

	# Restaura vidas/HP dependendo do modo
	if player.mode == player.GameMode.METROIDVANIA:
		if stats and stats.has_method("reset_health_full"):
			stats.reset_health_full()
		GameManager.restore_full_lives()
	else:
		GameManager.restore_full_lives()

	print("🫧 Forma Bubble desbloqueada! +1 HP (se tiver) | Vidas restauradas!")
	queue_free()
