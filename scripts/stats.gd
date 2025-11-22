# Stats.gd
extends Node

signal health_changed(current_health: int, max_health: int)

@export var max_health: int = 5
var current_health: int = 5

@export var player: CharacterBody2D

func _ready() -> void:
	if not player:
		# Tenta achar o player como pai
		player = get_parent() as CharacterBody2D
	
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

# usado pelos powerups atuais
func update_health(mode: String, amount: int) -> void:
	match mode:
		"Increase":
			current_health = min(current_health + amount, max_health)
		"Decrease":
			current_health = max(current_health - amount, 0)
	emit_signal("health_changed", current_health, max_health)

# dano “bruto”
func take_damage(amount: int = 1) -> void:
	update_health("Decrease", amount)

func reset_health_full() -> void:
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

# já existia; deixo genérico
func update_max_health_by_form() -> void:
	if current_health > max_health:
		current_health = max_health
	emit_signal("health_changed", current_health, max_health)

# para HUD saber se mostra ou não a barra de HP
func is_health_visible() -> bool:
	if player:
		return player.mode == player.GameMode.METROIDVANIA
	return true
	
func restore_full_health():
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
