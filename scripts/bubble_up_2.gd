extends Area2D

@export var player: CharacterBody2D
@export var stats: Node
@export var update_respawn: bool = false
@export var respawn_node: Node2D

func _ready() -> void:
	if not player:
		push_error("BubbleUp2: Player reference não foi definida!")
	if not stats:
		push_error("BubbleUp2: Stats reference não foi definida!")

func _on_body_entered(body: Node2D) -> void:
	if body != player:
		return

	# Cura / buff
	if stats and stats.has_method("update_health"):
		stats.update_health("Increase", 2)
	if stats and stats.has_method("update_max_health_by_form"):
		stats.update_max_health_by_form()

	# Desbloqueia Super
	player.unlocked_forms[player.Form.SUPER] = true

	# Respawn opcional
	if update_respawn and respawn_node:
		player.respawn_position = respawn_node.global_position

	# Restaura vidas/HP
	if player.mode == player.GameMode.METROIDVANIA:
		if stats and stats.has_method("reset_health_full"):
			stats.reset_health_full()
		GameManager.restore_full_lives()
	else:
		GameManager.restore_full_lives()

	print("⭐ Forma Super desbloqueada! Vida e vidas restauradas!")
	queue_free()
