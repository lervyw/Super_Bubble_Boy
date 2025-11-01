extends Area2D

# Referências
@export var level: Node2D  # Referência ao nível
@export var player: CharacterBody2D

# Configurações
@export var instant_kill: bool = true
@export var damage_amount: int = 999
@export var respawn_delay: float = 0.5

func _ready() -> void:
	# ✅ Busca level automaticamente se não definido
	if not level:
		level = get_tree().current_scene
		if level:
			print("✅ Kill Zone: Level encontrado automaticamente: ", level.name)
	
	# Busca player automaticamente
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	# ✅ Validação
	if not level:
		push_error("Kill Zone: Level não encontrado! Configure no Inspector.")
	
	if not player:
		push_warning("Kill Zone: Player não encontrado!")
	
	# Conecta signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	"""Player caiu na kill zone"""
	
	if not is_player(body):
		return
	
	print("☠️ Player caiu na kill zone!")
	
	if instant_kill:
		kill_player(body)
	else:
		damage_player(body)

func is_player(body: Node2D) -> bool:
	"""Verifica se o body é o player"""
	if body.name == "player":
		return true
	if body.is_in_group("player"):
		return true
	if player and body == player:
		return true
	return false

func kill_player(body: Node2D) -> void:
	"""Mata o player instantaneamente"""
	var stats = get_player_stats(body)
	
	if stats and stats.has_method("take_damage"):
		stats.take_damage(999)
	elif body.has_method("die"):
		body.die()
	
	# Respawn após delay
	#await get_tree().create_timer(respawn_delay).timeout
	#respawn_player()

func damage_player(body: Node2D) -> void:
	"""Causa dano ao player"""
	var stats = get_player_stats(body)
	
	if stats and stats.has_method("take_damage"):
		stats.take_damage(damage_amount)
		
		if stats.current_health <= 0:
			await get_tree().create_timer(respawn_delay).timeout
			respawn_player()

func respawn_player() -> void:
	"""Respawna o player no checkpoint"""
	# ✅ Validação melhorada
	if not level:
		push_error("Kill Zone: Não há referência ao level para respawn!")
		# ✅ Tenta reload da cena como último recurso
		get_tree().reload_current_scene()
		return
	
	# Tenta múltiplos métodos
	if level.has_method("reset_player_position"):
		level.reset_player_position()
	elif level.has_method("reset_scene"):
		level.reset_scene()
	else:
		push_error("Kill Zone: Level '%s' não tem método de respawn!" % level.name)
		# Último recurso: reload
		get_tree().reload_current_scene()

func get_player_stats(body: Node2D) -> Node:
	"""Obtém o node Stats do player"""
	if body.has_node("Stats"):
		return body.get_node("Stats")
	
	for child in body.get_children():
		if child.name.to_lower().contains("stat"):
			return child
	
	return null
