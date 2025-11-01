extends Area2D

@export var player: CharacterBody2D
@export var stats: Node  # ✅ Renomeado de 'status' para 'stats'

func _ready() -> void:
	# Validação para evitar crashes
	if not player:
		push_error("BubbleUp1: Player reference não foi definida!")
	if not stats:
		push_error("BubbleUp1: Stats reference não foi definida!")

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		# ✅ Corrigido: update_helth → update_health
		stats.update_health("Increase", 1)
		
		# Desbloqueia a forma Bubble
		player.unlocked_forms[player.Form.BUBBLE] = true
		
		print("🫧 Forma Bubble desbloqueada! +1 HP")
		
		# Remove o power-up
		queue_free()
