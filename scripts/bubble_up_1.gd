extends Area2D

@export var player: CharacterBody2D
@export var stats: Node
@export var update_respawn: bool = false
@export var restore_health: bool = true
@export var restore_lives: bool = true

func _ready() -> void:
	if not player:
		push_error("BubbleUp1: Player reference não foi definida!")
	if not stats:
		push_error("BubbleUp1: Stats reference não foi definida!")

func _on_body_entered(body: Node2D) -> void:
	if body != player:
		return
	
	# Continua compatível com o código antigo
	stats.update_health("Increase", 1)
	
	# Desbloqueia a forma Bubble
	player.unlocked_forms[player.Form.BUBBLE] = true
	
	print("🫧 Forma Bubble desbloqueada! +1 HP")

	# Restaurar HP totalmente (modo Metroidvania)
	if restore_health and stats.has_method("reset_health_full"):
		stats.reset_health_full()
	
	# Restaurar vidas
	if restore_lives:
		GameManager.restore_full_lives()
	
	# Atualizar respawn (opcional)
	if update_respawn:
		player.respawn_position = player.global_position
		print("📍 Respawn atualizado pelo BubbleUp1")

	queue_free()
