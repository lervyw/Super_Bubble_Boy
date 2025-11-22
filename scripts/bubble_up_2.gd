extends Area2D

@export var player: CharacterBody2D
@export var stats: Node
@export var update_respawn: bool = false
@export var restore_health: bool = true
@export var restore_lives: bool = true

func _ready() -> void:
	if not player:
		push_error("BubbleUp2: Player reference não foi definida!")
	if not stats:
		push_error("BubbleUp2: Stats reference não foi definida!")

func _on_body_entered(body: Node2D) -> void:
	if body != player:
		return
	
	# Cura 2 HP
	stats.update_health("Increase", 2)
	
	# Desbloqueia a forma Super
	player.unlocked_forms[player.Form.SUPER] = true
	
	# Atualiza vida máxima por forma
	if stats.has_method("update_max_health_by_form"):
		stats.update_max_health_by_form()
	
	print("⭐ Forma Super desbloqueada! +2 HP | Vida máxima aumentada!")

	# Restaurar HP e vidas
	if restore_health and stats.has_method("reset_health_full"):
		stats.reset_health_full()
	if restore_lives:
		GameManager.restore_full_lives()
	
	if update_respawn:
		player.respawn_position = player.global_position
		print("📍 Respawn atualizado pelo BubbleUp2")

	queue_free()
