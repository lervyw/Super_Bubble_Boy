extends Area2D
# =========================================================
#  POWER-UP: BUBBLE
#  Item coletável que:
#  - Cura o player levemente
#  - Desbloqueia a forma Bubble
#  - Opcionalmente atualiza o checkpoint/respawn
#  - Restaura vidas/HP conforme o modo de jogo
# =========================================================


# ================================
#           REFERÊNCIAS
# ================================

# Referência direta ao player
@export var player: CharacterBody2D

# Referência ao sistema de stats (HP)
@export var stats: Node

# Se true, atualiza o ponto de respawn ao coletar
@export var update_respawn: bool = false

# Nó que define a nova posição de respawn
@export var respawn_node: Node2D


# ================================
#             READY
# ================================
func _ready() -> void:
	# Validação básica para evitar erros silenciosos
	if not player:
		push_error("BubbleUp1: Player reference não foi definida!")
	if not stats:
		push_error("BubbleUp1: Stats reference não foi definida!")


# ================================
#        COLETA DO ITEM
# ================================
func _on_body_entered(body: Node2D) -> void:
	# Ignora qualquer coisa que não seja o player
	if body != player:
		return

	# --- Cura leve ---
	# Aumenta 1 de HP (se o sistema de stats existir)
	if stats and stats.has_method("update_health"):
		stats.update_health("Increase", 1)

	# --- Desbloqueio de forma ---
	# Libera a forma Bubble permanentemente
	player.unlocked_forms[player.Form.BUBBLE] = true

	# --- Atualização de respawn (opcional) ---
	# Se configurado, define novo ponto de respawn
	if update_respawn and respawn_node:
		player.respawn_position = respawn_node.global_position

	# --- Restauração de vidas / HP ---
	# Metroidvania: restaura HP e vidas
	if player.mode == player.GameMode.METROIDVANIA:
		if stats and stats.has_method("reset_health_full"):
			stats.reset_health_full()
		GameManager.restore_full_lives()
	else:
		# Plataforma: restaura apenas vidas
		GameManager.restore_full_lives()

	print("🫧 Forma Bubble desbloqueada! +1 HP (se tiver) | Vidas restauradas!")

	# Remove o power-up da cena após coleta
	queue_free()
