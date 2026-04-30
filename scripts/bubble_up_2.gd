extends Area2D
# =========================================================
#  POWER-UP: SUPER
#  Item coletável que:
#  - Cura o player (valor maior)
#  - Atualiza/buffa HP máximo (se aplicável)
#  - Desbloqueia a forma SUPER
#  - Opcionalmente redefine o respawn
#  - Restaura HP no modo Metroidvania
# =========================================================

# ================================
#           REFERÊNCIAS
# ================================
@export var player: CharacterBody2D
@export var stats: Node
@export var update_respawn: bool = false
@export var respawn_node: Node2D

# Evita coleta duplicada
var collected: bool = false

# ================================
#             READY
# ================================
func _ready() -> void:
	# Validação básica para evitar erros silenciosos
	if not player:
		push_error("BubbleUp2: Player reference não foi definida!")
	if not stats:
		push_error("BubbleUp2: Stats reference não foi definida!")

	# Garante conexão dos sinais
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

# ================================
#        DETECÇÃO DE COLETA
# ================================
func _on_body_entered(body: Node2D) -> void:
	if collected:
		return

	if is_player_body(body):
		collect()

func _on_area_entered(area: Area2D) -> void:
	if collected:
		return

	if is_player_area(area):
		collect()

func is_player_body(body: Node) -> bool:
	if body == null:
		return false

	if body == player:
		return true

	if body.get_parent() == player:
		return true

	if player != null and player.is_ancestor_of(body):
		return true

	return false

func is_player_area(area: Area2D) -> bool:
	if area == null:
		return false

	if area == player:
		return true

	if area.get_parent() == player:
		return true

	if player != null and player.is_ancestor_of(area):
		return true

	return false

# ================================
#        COLETA DO ITEM
# ================================
func collect() -> void:
	if collected:
		return

	collected = true

	# --- Cura / buff ---
	if stats and stats.has_method("update_health"):
		stats.update_health("Increase", 2)

	if stats and stats.has_method("update_max_health_by_form"):
		stats.update_max_health_by_form()

	# --- Desbloqueio de forma ---
	player.unlocked_forms[player.Form.SUPER] = true

	# --- Atualização de respawn (opcional) ---
	if update_respawn and respawn_node:
		player.respawn_position = respawn_node.global_position

	# --- Restauração de HP ---
	if stats and stats.has_method("reset_health_full"):
		stats.reset_health_full()

	print("⭐ Forma Super desbloqueada! Vida restaurada!")

	queue_free()
