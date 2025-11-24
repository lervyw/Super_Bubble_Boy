# Stats.gd
extends Node

signal health_changed(current_health: int, max_health: int)

@export var max_health: int = 5
var current_health: int = 5

@export var player: CharacterBody2D

func _ready() -> void:
	if not player:
		player = get_parent() as CharacterBody2D

	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

# Alteração de HP por powerup
func update_health(mode: String, amount: int) -> void:
	match mode:
		"Increase":
			current_health = min(current_health + amount, max_health)
		"Decrease":
			current_health = max(current_health - amount, 0)

	emit_signal("health_changed", current_health, max_health)

# Dano direto
func take_damage(amount: int = 1) -> void:
	update_health("Decrease", amount)

# Restaurar vida cheia
func reset_health_full() -> void:
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

# Função usada pelo Continue Screen / GameManager
func restore_full_health() -> void:
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

# Atualizar max_health baseado em forma
func update_max_health_by_form() -> void:
	current_health = min(current_health, max_health)
	emit_signal("health_changed", current_health, max_health)

# HUD usa esta função para saber se mostra a barra de HP
func is_health_visible() -> bool:
	if player:
		return player.mode == player.GameMode.METROIDVANIA
	return true
