extends Area2D
# =========================================================
#  KILL ZONE
#  Objeto de cenário que mata ou causa dano ao player
#  quando ele entra na área (queda, espinhos, lava, etc)
# =========================================================


# ================================
#           REFERÊNCIAS
# ================================

# Referência ao nível (usada para contexto / compatibilidade)
@export var level: Node2D

# Referência direta ao player
@export var player: CharacterBody2D


# ================================
#          CONFIGURAÇÕES
# ================================

# Se true, mata o player instantaneamente
@export var instant_kill: bool = true

# Quantidade de dano (usado se instant_kill = false)
@export var damage_amount: int = 999

# Delay de respawn (não usado aqui, mas preparado para lógica futura)
@export var respawn_delay: float = 0.5


# ================================
#             READY
# ================================
func _ready() -> void:
	# Tenta pegar o nível automaticamente se não foi setado no Inspector
	if not level:
		level = get_tree().current_scene
		if level:
			print("✅ Kill Zone: Level encontrado automaticamente: ", level.name)

	# Tenta encontrar o player pelo grupo "player"
	if not player:
		player = get_tree().get_first_node_in_group("player")

	# Valida referências
	if not level:
		push_error("Kill Zone: Level não encontrado! Configure no Inspector.")

	if not player:
		push_warning("Kill Zone: Player não encontrado!")

	# Conecta o sinal de colisão apenas uma vez
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


# ================================
#        DETECÇÃO DE COLISÃO
# ================================
func _on_body_entered(body: Node2D) -> void:
	# Ignora qualquer coisa que não seja o player
	if not is_player(body):
		return

	print("☠️ Player caiu na kill zone!")

	# Decide entre morte instantânea ou dano
	if instant_kill:
		kill_player(body)
	else:
		damage_player(body)


# ================================
#        IDENTIFICAÇÃO DO PLAYER
# ================================
func is_player(body: Node2D) -> bool:
	# Verifica por nome
	if body.name == "player":
		return true

	# Verifica por grupo
	if body.is_in_group("player"):
		return true

	# Verifica referência direta
	if player and body == player:
		return true

	return false


# ================================
#          MORTE INSTANTÂNEA
# ================================
func kill_player(body: Node2D) -> void:
	# Se o player tiver método próprio de dano
	if body.has_method("take_damage"):
		body.take_damage(999) # dano fatal, sistema de vida cuida do resto
	else:
		# Fallback: tenta acessar Stats manualmente
		var stats = get_player_stats(body)
		if stats and stats.has_method("take_damage"):
			stats.take_damage(999)


# ================================
#              DANO
# ================================
func damage_player(body: Node2D) -> void:
	# Aplica dano normal ao player
	if body.has_method("take_damage"):
		body.take_damage(damage_amount)
	else:
		# Fallback via Stats
		var stats = get_player_stats(body)
		if stats and stats.has_method("take_damage"):
			stats.take_damage(damage_amount)


# ================================
#        BUSCA DE STATS
# ================================
func get_player_stats(body: Node2D) -> Node:
	# Procura um nó chamado "Stats"
	if body.has_node("Stats"):
		return body.get_node("Stats")

	# Procura qualquer filho com nome parecido com "stat"
	for child in body.get_children():
		if child.name.to_lower().contains("stat"):
			return child

	return null
