# Stats.gd
extends Node
# =========================================================
#  STATS DO PLAYER (HP)
#  Responsável por:
#  - Guardar max_health e current_health
#  - Emitir sinal quando HP muda (para HUD atualizar)
#  - Fornecer funções simples: dano, cura, restaurar vida
#  - Informar se o HP deve aparecer (depende do modo do player)
# =========================================================

# Sinal usado pela HUD (ou outros) para atualizar UI sempre que o HP mudar
signal health_changed(current_health: int, max_health: int)

# Vida máxima configurável no Inspector
@export var max_health: int = 5

# Vida atual (começa igual ao máximo)
var current_health: int = 5

# Referência do player para checar modo do jogo (plataforma/metroidvania)
@export var player: CharacterBody2D


func _ready() -> void:
	# Se o player não foi setado no Inspector, tenta pegar o pai (componente no player)
	if not player:
		player = get_parent() as CharacterBody2D

	# Inicia com vida cheia
	current_health = max_health

	# Notifica HUD/ouvintes com o estado inicial
	emit_signal("health_changed", current_health, max_health)


# ================================
#   ALTERAÇÃO DE HP (GENÉRICO)
# ================================
func update_health(mode: String, amount: int) -> void:
	# Controla cura/dano por texto ("Increase"/"Decrease")
	match mode:
		"Increase":
			# Cura, mas nunca passa do máximo
			current_health = min(current_health + amount, max_health)
		"Decrease":
			# Dano, mas nunca desce abaixo de 0
			current_health = max(current_health - amount, 0)

	# Sempre avisa a HUD que mudou
	emit_signal("health_changed", current_health, max_health)


# ================================
#          DANO DIRETO
# ================================
func take_damage(amount: int = 1) -> void:
	# Atalho para aplicar dano
	update_health("Decrease", amount)


# ================================
#        RESTAURAR VIDA
# ================================
func reset_health_full() -> void:
	# Restaura HP total (usado ao entrar no modo/metroidvania ou respawn)
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

func restore_full_health() -> void:
	# Mesma ideia do reset_health_full, usado por Continue/GameManager
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)


# ================================
#      AJUSTE DE MAX HP
# ================================
func update_max_health_by_form() -> void:
	# Garante que current_health não ultrapasse max_health (caso max_health mude)
	current_health = min(current_health, max_health)
	emit_signal("health_changed", current_health, max_health)


# ================================
#        VISIBILIDADE NO HUD
# ================================
func is_health_visible() -> bool:
	# No seu design: HP aparece só em Metroidvania
	if player:
		return player.mode == player.GameMode.METROIDVANIA

	# Se não tiver player, assume visível por segurança
	return true
