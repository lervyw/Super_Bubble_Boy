extends Area2D
# =========================================================
#  POWER-UP: SUPER
#  Item coletável que:
#  - Cura o player (valor maior)
#  - Atualiza/buffa HP máximo (se aplicável)
#  - Desbloqueia a forma SUPER
#  - Opcionalmente redefine o respawn
#  - Restaura vidas e HP conforme o modo de jogo
# =========================================================


# ================================
#           REFERÊNCIAS
# ================================

# Referência direta ao player
@export var player: CharacterBody2D

# Referência ao sistema de stats (HP)
@export var stats: Node

# Define se este power-up atualiza o checkpoint
@export var update_respawn: bool = false

# Nó usado como novo ponto de respawn
@export var respawn_node: Node2D


# ================================
#             READY
# ================================
func _ready() -> void:
	# Validação básica para evitar erros silenciosos
	if not player:
		push_error("BubbleUp2: Player reference não foi definida!")
	if not stats:
		push_error("BubbleUp2: Stats reference não foi definida!")


# ================================
#        COLETA DO ITEM
# ================================
func _on_body_entered(body: Node2D) -> void:
	# Garante que só o player pode coletar
	if body != player:
		return

	# --- Cura / buff ---
	# Aumenta HP atual em 2
	if stats and stats.has_method("update_health"):
		stats.update_health("Increase", 2)

	# Ajusta HP máximo (ou valida HP atual após mudança de forma)
	if stats and stats.has_method("update_max_health_by_form"):
		stats.update_max_health_by_form()

	# --- Desbloqueio de forma ---
	# Libera a forma SUPER permanentemente
	player.unlocked_forms[player.Form.SUPER] = true

	# --- Atualização de respawn (opcional) ---
	# Atualiza o ponto de respawn caso configurado
	if update_respawn and respawn_node:
		player.respawn_position = respawn_node.global_position

	# --- Restauração de vidas / HP ---
	# Metroidvania: restaura HP total e vidas
	if player.mode == player.GameMode.METROIDVANIA:
		if stats and stats.has_method("reset_health_full"):
			stats.reset_health_full()
		GameManager.restore_full_lives()
	else:
		# Plataforma: restaura apenas vidas
		GameManager.restore_full_lives()

	print("⭐ Forma Super desbloqueada! Vida e vidas restauradas!")

	# Remove o power-up da cena após coleta
	queue_free()
