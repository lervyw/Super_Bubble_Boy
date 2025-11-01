extends Area2D

@export var player: CharacterBody2D
@export var stats: Node  # ✅ Renomeado de 'status' para 'stats'

func _ready() -> void:
	# Validação para evitar crashes
	if not player:
		push_error("BubbleUp2: Player reference não foi definida!")
	if not stats:
		push_error("BubbleUp2: Stats reference não foi definida!")

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		# ✅ Corrigido: update_helth → update_health
		# ✅ Cura 2 HP em vez de 1 (Super é mais especial)
		stats.update_health("Increase", 2)
		
		# Desbloqueia a forma Super
		player.unlocked_forms[player.Form.SUPER] = true
		
		# ✅ Atualiza vida máxima (Super ganha +2 HP max)
		stats.update_max_health_by_form()
		
		print("⭐ Forma Super desbloqueada! +2 HP | Vida máxima aumentada!")
		
		# Remove o power-up
		queue_free()
