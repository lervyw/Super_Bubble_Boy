# Stats.gd
extends Node
# =========================================================
#  STATS DO PLAYER (HP + MANA)
#  Responsável por:
#  - Guardar max/current de HP e mana
#  - Emitir sinais para a HUD atualizar
#  - Controlar dano, cura, gasto e regen de mana
#  - Centralizar restauração total para checkpoints/respawn
# =========================================================

signal health_changed(current_health: int, max_health: int)
signal mana_changed(current_mana: float, max_mana: float)

@export_group("Health")
@export var max_health: int = 5
var current_health: int = 5

@export_group("Mana")
@export var max_mana: float = 100.0
@export_range(0.0, 100.0, 0.1) var mana_regen_per_second: float = 20.0
@export_range(0.0, 10.0, 0.05) var mana_regen_delay: float = 0.75
var current_mana: float = 100.0
var mana_regen_block_timer: float = 0.0

@export_group("References")
@export var player: CharacterBody2D


func _ready() -> void:
	if not player:
		player = get_parent() as CharacterBody2D

	current_health = max_health
	current_mana = max_mana
	emit_signal("health_changed", current_health, max_health)
	emit_signal("mana_changed", current_mana, max_mana)


func _process(delta: float) -> void:
	if current_mana >= max_mana:
		return
	if not is_mana_enabled():
		return

	if mana_regen_block_timer > 0.0:
		mana_regen_block_timer = max(mana_regen_block_timer - delta, 0.0)
		return

	if mana_regen_per_second <= 0.0:
		return

	restore_mana(mana_regen_per_second * delta, false)


# ================================
#   ALTERAÇÃO DE HP (GENÉRICO)
# ================================
func update_health(mode: String, amount: int) -> void:
	match mode:
		"Increase":
			current_health = min(current_health + amount, max_health)
		"Decrease":
			current_health = max(current_health - amount, 0)

	emit_signal("health_changed", current_health, max_health)


func take_damage(amount: int = 1) -> void:
	update_health("Decrease", amount)


func reset_health_full() -> void:
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)


func restore_full_health() -> void:
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)


func update_max_health_by_form() -> void:
	current_health = min(current_health, max_health)
	emit_signal("health_changed", current_health, max_health)


# ================================
#            MANA
# ================================
func is_mana_enabled() -> bool:
	if player and player.has_method("can_use_mana_system"):
		return player.can_use_mana_system()
	return true


func consume_mana(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not is_mana_enabled():
		return true
	if current_mana < amount:
		return false

	current_mana = max(current_mana - amount, 0.0)
	mana_regen_block_timer = mana_regen_delay
	emit_signal("mana_changed", current_mana, max_mana)
	return true


func consume_all_mana() -> bool:
	if not is_mana_enabled():
		return true
	if current_mana <= 0.0:
		return false

	current_mana = 0.0
	mana_regen_block_timer = mana_regen_delay
	emit_signal("mana_changed", current_mana, max_mana)
	return true


func restore_mana(amount: float, clear_regen_delay: bool = true) -> void:
	if amount <= 0.0:
		return

	current_mana = min(current_mana + amount, max_mana)
	if clear_regen_delay:
		mana_regen_block_timer = 0.0
	emit_signal("mana_changed", current_mana, max_mana)


func reset_mana_full() -> void:
	current_mana = max_mana
	mana_regen_block_timer = 0.0
	emit_signal("mana_changed", current_mana, max_mana)


func restore_full_mana() -> void:
	current_mana = max_mana
	mana_regen_block_timer = 0.0
	emit_signal("mana_changed", current_mana, max_mana)


func restore_all() -> void:
	restore_full_health()
	restore_full_mana()


func is_health_visible() -> bool:
	if player:
		return player.mode == player.GameMode.METROIDVANIA
	return true


func is_mana_visible() -> bool:
	if player and player.has_method("can_use_mana_system"):
		return player.can_use_mana_system()
	return true
