extends Area2D
# =========================================================
#  KILL ZONE
#  Objeto de cenário que mata ou causa dano ao player
#  quando ele entra na área (queda, espinhos, lava, etc)
# =========================================================

# ================================
#           REFERÊNCIAS
# ================================
@export var level: Node2D
@export var player: CharacterBody2D

# ================================
#          CONFIGURAÇÕES
# ================================
@export var instant_kill: bool = true
@export var damage_amount: int = 999
@export var respawn_delay: float = 0.5

# Evita múltiplos disparos no mesmo frame/entrada
var triggered: bool = false

# ================================
#             READY
# ================================
func _ready() -> void:
	if not level:
		level = get_tree().current_scene as Node2D
		if level:
			print("✅ Kill Zone: Level encontrado automaticamente: ", level.name)

	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if not level:
		push_error("Kill Zone: Level não encontrado! Configure no Inspector.")

	if not player:
		push_warning("Kill Zone: Player não encontrado!")

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

# ================================
#        DETECÇÃO DE COLISÃO
# ================================
func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return

	if not is_player_body(body):
		return

	triggered = true
	print("☠️ Player caiu na kill zone!")

	if instant_kill:
		kill_player(player)
	else:
		damage_player(player)

	reset_trigger_flag_deferred()

func _on_area_entered(area: Area2D) -> void:
	if triggered:
		return

	if not is_player_area(area):
		return

	triggered = true
	print("☠️ Player caiu na kill zone!")

	if instant_kill:
		kill_player(player)
	else:
		damage_player(player)

	reset_trigger_flag_deferred()

# ================================
#        IDENTIFICAÇÃO DO PLAYER
# ================================
func is_player_body(body: Node) -> bool:
	if body == null:
		return false

	if body == player:
		return true

	if body.is_in_group("player"):
		return true

	if body.get_parent() == player:
		return true

	if player != null and player.is_ancestor_of(body):
		return true

	return false

func is_player_area(area: Area2D) -> bool:
	if area == null:
		return false

	if area.is_in_group("player"):
		return true

	if area.get_parent() == player:
		return true

	if player != null and player.is_ancestor_of(area):
		return true

	return false

# ================================
#          MORTE INSTANTÂNEA
# ================================
func kill_player(target: Node) -> void:
	if target == null:
		return

	if target.has_method("take_damage"):
		target.take_damage(999)
		return

	var stats = get_player_stats(target)
	if stats and stats.has_method("take_damage"):
		stats.take_damage(999)

# ================================
#              DANO
# ================================
func damage_player(target: Node) -> void:
	if target == null:
		return

	if target.has_method("take_damage"):
		target.take_damage(damage_amount)
		return

	var stats = get_player_stats(target)
	if stats and stats.has_method("take_damage"):
		stats.take_damage(damage_amount)

# ================================
#        BUSCA DE STATS
# ================================
func get_player_stats(target: Node) -> Node:
	if target == null:
		return null

	if target.has_node("Stats"):
		return target.get_node("Stats")

	for child in target.get_children():
		if child.name.to_lower().contains("stat"):
			return child

	return null

# ================================
#        RESET DO TRIGGER
# ================================
func reset_trigger_flag_deferred() -> void:
	var tree := get_tree()
	if tree == null:
		triggered = false
		return

	await tree.process_frame
	triggered = false
