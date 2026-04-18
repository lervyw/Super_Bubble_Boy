class_name SpawnZone
extends Area2D

# Referências
@export_group("References")
@export var enemy_scene: PackedScene  # Qual inimigo spawnar
@export var player: CharacterBody2D  # Referência ao player (opcional)

# Configurações de Spawn
@export_group("Spawn Settings")
@export var enemies_to_spawn: int = 5  # Quantos inimigos spawnar
@export var spawn_interval: float = 0.5  # Intervalo entre spawns
@export var max_enemies_alive: int = 3  # Máximo simultâneo desta zona
@export var spawn_on_ready: bool = true  # ✅ NOVO: Spawna automaticamente ao iniciar
@export var spawn_on_enter: bool = false  # Spawna quando player entra? (agora false por padrão)
@export var spawn_continuously: bool = false  # Continua spawnando?
@export var respawn_cooldown: float = 10.0  # Tempo para spawnar de novo
@export var initial_spawn_delay: float = 0.0  # ✅ NOVO: Delay antes do primeiro spawn

# Área de Spawn
@export_group("Spawn Area")
@export var min_distance_from_player: float = 50.0  # Distância mínima do player

# Ativação
@export_group("Activation")
@export var active: bool = true  # Zona está ativa?
@export var one_time_only: bool = false  # Só spawna uma vez?
@export var require_all_dead: bool = true  # Precisa matar todos antes de respawn?

# Debug
@export var debug_mode: bool = false

# Estado interno
var enemies_spawned: int = 0
var enemies_alive: int = 0
var is_spawning: bool = false
var has_spawned_once: bool = false
var can_respawn: bool = true
var player_inside: bool = false
var spawned_enemies: Array[Node] = []

# Bounds da zona (sempre usa CollisionShape2D agora)
var zone_rect: Rect2

func _ready() -> void:
	# Encontra player se não definido
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	# Calcula bounds da zona
	calculate_zone_bounds()
	
	# Conecta sinais
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Validação
	if not enemy_scene:
		push_warning("SpawnZone '%s': enemy_scene não definido!" % name)
		active = false
	
	if debug_mode:
		print("🎯 SpawnZone '%s' inicializada" % name)
		print("  - Inimigos: %d" % enemies_to_spawn)
		print("  - Intervalo: %.1fs" % spawn_interval)
		print("  - Máx vivos: %d" % max_enemies_alive)
		print("  - Spawn automático: %s" % spawn_on_ready)
		print("  - Zone bounds: %v" % zone_rect)
	
	# ✅ NOVO: Spawna automaticamente após delay
	if spawn_on_ready and active:
		if initial_spawn_delay > 0:
			await get_tree().create_timer(initial_spawn_delay).timeout
		start_spawning()

func _process(_delta: float) -> void:
	if debug_mode:
		queue_redraw()

func _draw() -> void:
	"""Debug: desenha a área de spawn"""
	if not debug_mode:
		return
	
	# Desenha bounds da zona (sempre usa CollisionShape2D)
	draw_rect(zone_rect, Color.YELLOW, false, 2.0)
	
	# Desenha distância mínima do player
	draw_circle(Vector2.ZERO, min_distance_from_player, Color.RED, false, 1.0)
	
	# Info text
	var info = "Enemies: %d/%d alive" % [enemies_alive, max_enemies_alive]
	draw_string(ThemeDB.fallback_font, Vector2(-50, -zone_rect.size.y/2 - 10), info, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

func calculate_zone_bounds() -> void:
	"""Calcula os limites da zona baseado no CollisionShape2D"""
	if not has_node("CollisionShape2D"):
		push_error("SpawnZone '%s': CollisionShape2D não encontrada!" % name)
		zone_rect = Rect2(-100, -100, 200, 200)  # Fallback
		return
	
	var collision = $CollisionShape2D
	var shape = collision.shape
	
	if shape is RectangleShape2D:
		var size = shape.size
		zone_rect = Rect2(-size / 2, size)
	elif shape is CircleShape2D:
		var radius = shape.radius
		zone_rect = Rect2(-radius, -radius, radius * 2, radius * 2)
	elif shape is CapsuleShape2D:
		var radius = shape.radius
		var height = shape.height
		zone_rect = Rect2(-radius, -height/2, radius * 2, height)
	else:
		push_warning("SpawnZone '%s': Shape não suportado, usando fallback" % name)
		zone_rect = Rect2(-100, -100, 200, 200)
	
	if debug_mode:
		print("  - Zone bounds calculado: ", zone_rect)

func _on_body_entered(body: Node2D) -> void:
	"""Detecta quando player entra na zona"""
	if not is_player(body):
		return
	
	player_inside = true
	
	if debug_mode:
		print("🎯 SpawnZone '%s': Player entrou" % name)
	
	# Só spawna na entrada se configurado
	if spawn_on_enter and active and can_spawn():
		start_spawning()

func _on_body_exited(body: Node2D) -> void:
	"""Detecta quando player sai da zona"""
	if not is_player(body):
		return
	
	player_inside = false
	
	if debug_mode:
		print("🎯 SpawnZone '%s': Player saiu" % name)

func is_player(body: Node2D) -> bool:
	"""Verifica se o body é o player"""
	if body.is_in_group("player"):
		return true
	if player and body == player:
		return true
	return false

func can_spawn() -> bool:
	"""Verifica se pode spawnar"""
	if not active:
		return false
	
	if one_time_only and has_spawned_once:
		return false
	
	if is_spawning:
		return false
	
	if require_all_dead and enemies_alive > 0:
		return false
	
	if not can_respawn:
		return false
	
	return true

func start_spawning() -> void:
	"""Inicia o processo de spawn"""
	if not can_spawn():
		return
	
	is_spawning = true
	has_spawned_once = true
	enemies_spawned = 0
	
	if debug_mode:
		print("🌊 SpawnZone '%s': Iniciando spawn de %d inimigos" % [name, enemies_to_spawn])
	
	spawn_wave()

func spawn_wave() -> void:
	"""Spawna a wave de inimigos"""
	while enemies_spawned < enemies_to_spawn:
		# Verifica se ainda está na árvore
		if not is_inside_tree():
			print("⚠️ SpawnZone '%s' removida durante spawn" % name)
			return
		
		# Limita inimigos simultâneos
		if enemies_alive >= max_enemies_alive:
			await get_tree().create_timer(0.5).timeout
			continue
		
		# Não spawna se player muito próximo
		if player and not is_player_far_enough():
			await get_tree().create_timer(0.5).timeout
			continue
		
		spawn_enemy()
		enemies_spawned += 1
		
		# Verifica novamente antes de await
		if not is_inside_tree():
			return
		
		await get_tree().create_timer(spawn_interval).timeout
	
	is_spawning = false
	
	if debug_mode:
		print("✅ SpawnZone '%s': Todos os %d inimigos spawnados" % [name, enemies_to_spawn])
	
	if spawn_continuously:
		setup_respawn()

func spawn_enemy() -> void:
	"""Spawna um único inimigo"""
	if not enemy_scene:
		push_warning("SpawnZone '%s': enemy_scene não está definido!" % name)
		return
	
	var enemy_instance = enemy_scene.instantiate()
	
	# Define posição de spawn (sempre dentro da CollisionShape2D)
	var spawn_pos = get_valid_spawn_position()
	
	# Usa call_deferred para evitar erro durante physics flush
	get_parent().call_deferred("add_child", enemy_instance)
	
	# Define posição depois de adicionar
	enemy_instance.set_deferred("global_position", spawn_pos)
	
	# Adiciona ao grupo
	if not enemy_instance.is_in_group("enemy"):
		enemy_instance.call_deferred("add_to_group", "enemy")
	
	# Rastreia este inimigo
	_track_enemy_deferred(enemy_instance)
	
	enemies_alive += 1
	
	if debug_mode:
		print("👾 SpawnZone '%s': Inimigo spawnado em %v" % [name, spawn_pos])

func _track_enemy_deferred(enemy: Node) -> void:
	"""Rastreia inimigo após ele estar na árvore"""
	# Aguarda o inimigo estar pronto
	await enemy.ready
	
	# Verifica se ainda é válido
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		spawned_enemies.append(enemy)
		
		# Conecta signal de morte
		if not enemy.tree_exiting.is_connected(_on_enemy_died):
			enemy.tree_exiting.connect(_on_enemy_died.bind(enemy))

func get_valid_spawn_position() -> Vector2:
	"""Retorna uma posição válida para spawn (sempre dentro da CollisionShape2D)"""
	var attempts = 0
	var max_attempts = 20
	
	while attempts < max_attempts:
		# ✅ Sempre spawna dentro dos bounds da CollisionShape2D
		var spawn_pos = global_position + Vector2(
			randf_range(zone_rect.position.x, zone_rect.position.x + zone_rect.size.x),
			randf_range(zone_rect.position.y, zone_rect.position.y + zone_rect.size.y)
		)
		
		# Verifica distância do player
		if not player or is_position_far_from_player(spawn_pos):
			return spawn_pos
		
		attempts += 1
	
	# Se não encontrou posição válida, usa o centro da zona
	return global_position

func is_player_far_enough() -> bool:
	"""Verifica se player está longe o suficiente da zona"""
	if not player:
		return true
	
	var distance = global_position.distance_to(player.global_position)
	return distance > min_distance_from_player

func is_position_far_from_player(pos: Vector2) -> bool:
	"""Verifica se uma posição está longe do player"""
	if not player:
		return true
	
	var distance = pos.distance_to(player.global_position)
	return distance > min_distance_from_player

func _on_enemy_died(enemy: Node) -> void:
	"""Callback quando inimigo morre"""
	enemies_alive -= 1
	spawned_enemies.erase(enemy)
	
	if debug_mode:
		print("💀 SpawnZone '%s': Inimigo morto | Restantes: %d" % [name, enemies_alive])
	
	# Verifica se zona ainda existe
	if not is_inside_tree():
		return
	
	# Se spawn contínuo e todos morreram, respawn
	if spawn_continuously and enemies_alive <= 0 and require_all_dead:
		setup_respawn()

func setup_respawn() -> void:
	"""Configura o respawn após cooldown"""
	if one_time_only:
		return
	
	# Verifica se está na árvore
	if not is_inside_tree():
		return
	
	can_respawn = false
	
	if debug_mode:
		print("⏳ SpawnZone '%s': Respawn em %.1fs" % [name, respawn_cooldown])
	
	await get_tree().create_timer(respawn_cooldown).timeout
	
	# Verifica de novo após await
	if not is_inside_tree():
		return
	
	can_respawn = true
	
	# ✅ MODIFICADO: Spawna automaticamente se spawn_continuously está ativo
	if spawn_continuously:
		start_spawning()

# ===== FUNÇÕES PÚBLICAS =====

func activate() -> void:
	"""Ativa a zona manualmente"""
	active = true
	if debug_mode:
		print("✅ SpawnZone '%s': Ativada" % name)

func deactivate() -> void:
	"""Desativa a zona"""
	active = false
	if debug_mode:
		print("❌ SpawnZone '%s': Desativada" % name)

func force_spawn() -> void:
	"""Força spawn imediato"""
	if active:
		start_spawning()

func clear_all_enemies() -> void:
	"""Remove todos os inimigos desta zona"""
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	spawned_enemies.clear()
	enemies_alive = 0
	
	if debug_mode:
		print("🧹 SpawnZone '%s': Todos os inimigos removidos" % name)

func reset() -> void:
	"""Reseta a zona para estado inicial"""
	clear_all_enemies()
	has_spawned_once = false
	can_respawn = true
	is_spawning = false
	enemies_spawned = 0
