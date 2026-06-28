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
@export var validate_against_world: bool = true
@export_flags_2d_physics var spawn_collision_mask: int = 1
@export var max_spawn_attempts: int = 80
@export var spawn_clearance_margin: float = 2.0
@export var snap_ground_enemies_to_floor: bool = true
@export var floor_snap_distance: float = 96.0
@export var floor_clearance: float = 2.0

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
	configure_area_collision()

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

func configure_area_collision() -> void:
	# Spawn zones are region markers. They should not physically affect the player.
	collision_layer = 0
	collision_mask = 1 if spawn_on_enter else 0
	monitoring = spawn_on_enter
	monitorable = false

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
	var shape_position: Vector2 = collision.position
	
	if shape is RectangleShape2D:
		var size = shape.size
		zone_rect = Rect2(shape_position - size / 2, size)
	elif shape is CircleShape2D:
		var radius = shape.radius
		zone_rect = Rect2(shape_position - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
	elif shape is CapsuleShape2D:
		var radius = shape.radius
		var height = shape.height
		zone_rect = Rect2(shape_position + Vector2(-radius, -height / 2), Vector2(radius * 2, height))
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
	var spawn_pos = get_valid_spawn_position(enemy_instance)
	
	# Usa call_deferred para evitar erro durante physics flush
	get_parent().call_deferred("add_child", enemy_instance)
	
	# Define posição depois de adicionar
	enemy_instance.set_deferred("global_position", spawn_pos)
	if enemy_instance.has_method("set_spawn_water_position"):
		enemy_instance.call_deferred("set_spawn_water_position", spawn_pos)
	
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

func get_valid_spawn_position(enemy_instance: Node = null) -> Vector2:
	"""Retorna uma posição válida para spawn (sempre dentro da CollisionShape2D)"""
	var attempts = 0
	var enemy_collision_shape := get_enemy_collision_shape(enemy_instance)
	var wants_floor := should_snap_enemy_to_floor(enemy_instance)
	
	while attempts < max_spawn_attempts:
		# ✅ Sempre spawna dentro dos bounds da CollisionShape2D
		var local_spawn_pos := Vector2(
			randf_range(zone_rect.position.x, zone_rect.position.x + zone_rect.size.x),
			randf_range(zone_rect.position.y, zone_rect.position.y + zone_rect.size.y)
		)
		var spawn_pos := to_global(local_spawn_pos)

		if wants_floor:
			var floor_pos := get_floor_spawn_position(spawn_pos, enemy_collision_shape)
			if floor_pos == Vector2.INF:
				attempts += 1
				continue
			spawn_pos = floor_pos
		
		# Verifica distância do player
		if (not player or is_position_far_from_player(spawn_pos)) and is_spawn_position_clear(spawn_pos, enemy_collision_shape):
			return spawn_pos
		
		attempts += 1
	
	# Se não encontrou posição válida, usa o centro da zona
	var fallback_position := to_global(zone_rect.get_center())
	if wants_floor:
		var fallback_floor := get_floor_spawn_position(fallback_position, enemy_collision_shape)
		if fallback_floor != Vector2.INF:
			return fallback_floor
	return fallback_position

func should_snap_enemy_to_floor(enemy_instance: Node) -> bool:
	if not snap_ground_enemies_to_floor or enemy_instance == null:
		return false
	if not has_property(enemy_instance, "move_mode"):
		return false
	var move_mode := int(enemy_instance.get("move_mode"))
	return move_mode != 2 and move_mode != 3

func has_property(target: Object, property_name: StringName) -> bool:
	for property in target.get_property_list():
		if property.get("name", "") == String(property_name):
			return true
	return false

func get_enemy_collision_shape(enemy_instance: Node) -> Shape2D:
	if enemy_instance == null:
		return null

	var collision_shape := enemy_instance.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return null

	return collision_shape.shape.duplicate()

func get_floor_spawn_position(start_position: Vector2, enemy_shape: Shape2D) -> Vector2:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		start_position,
		start_position + Vector2.DOWN * floor_snap_distance,
		spawn_collision_mask
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return Vector2.INF

	var radius := get_shape_bottom_extent(enemy_shape)
	var spawn_pos: Vector2 = result.position - Vector2(0, radius + floor_clearance)
	if not is_position_inside_zone(spawn_pos):
		return Vector2.INF

	return spawn_pos

func is_spawn_position_clear(spawn_pos: Vector2, enemy_shape: Shape2D) -> bool:
	if not validate_against_world:
		return true
	if enemy_shape == null:
		return true

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = enemy_shape
	query.transform = Transform2D(0.0, spawn_pos)
	query.collision_mask = spawn_collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.margin = spawn_clearance_margin

	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func is_position_inside_zone(pos: Vector2) -> bool:
	return zone_rect.has_point(to_local(pos))

func get_shape_bottom_extent(shape: Shape2D) -> float:
	if shape is CircleShape2D:
		return shape.radius
	if shape is RectangleShape2D:
		return shape.size.y / 2.0
	if shape is CapsuleShape2D:
		return shape.height / 2.0
	return 8.0

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
