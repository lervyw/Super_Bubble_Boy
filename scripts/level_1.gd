extends Node2D

# Referências
@export_group("References")
@export var player: CharacterBody2D
@export var stats: Node

# Configurações de Checkpoint
@export_group("Checkpoint")
@export var checkpoint_position: Vector2 = Vector2(288, 207)
@export var lose_health_on_death: bool = false

@export_group("Next Level")
@export var boss_node: NodePath
@export var next_scene: PackedScene


func _ready() -> void:
	print("🎮 Nível iniciado!")
	if stats and stats.has_method("restore_full_health"):
		stats.restore_full_health()
	
	if not player:
		push_error("Player reference não definida!")
		return
	
	if not stats:
		push_warning("Stats reference não definida!")
	
	# Conecta boss
	if boss_node != NodePath("") and has_node(boss_node):
		var boss = get_node(boss_node)
		if boss and boss.has_signal("boss_defeated"):
			boss.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
			print("✅ Boss conectado ao evento de vitória!")
	else:
		push_warning("⚠️ Nenhum boss configurado para este nível.")
	
	# Spawn zones continuam
	setup_spawn_zones()

func _on_boss_defeated() -> void:
	print("🏁 Boss derrotado! Mudando de cena em 2 segundos...")
	await get_tree().create_timer(2.0).timeout
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)

	else:
		push_warning("⚠️ Nenhuma cena configurada em 'next_scene'.")


func setup_spawn_zones() -> void:
	"""Configura referências automáticas nas spawn zones"""
	var zones = get_tree().get_nodes_in_group("spawn_zone")
	
	for zone in zones:
		if zone is SpawnZone:
			# Injeta referências automaticamente
			if not zone.player:
				zone.player = player
			
			print("✅ SpawnZone '%s' configurada" % zone.name)

func reset_scene() -> void:
	"""LEGACY: Compatibilidade com sistema antigo"""
	reset_player_position()

func reset_player_position() -> void:
	"""Reseta posição do player (checkpoint)"""
	if not player:
		push_error("Level: Player não encontrado!")
		return
	
	print("🔄 Player respawnando no checkpoint")
	
	player.global_position = checkpoint_position
	player.velocity = Vector2.ZERO
	
	if player.has_method("change_state"):
		player.change_state(player.State.IDLE)
	
	if lose_health_on_death and stats:
		stats.update_health("Decrease", 1)
		print("💔 -1 HP por morte")
	
	# Garante vida mínima
	if stats and stats.current_health <= 0:
		stats.current_health = 1
		stats.emit_signal("health_changed", stats.current_health, stats.max_health)

# ===== CONTROLE DE SPAWN ZONES (OPCIONAL) =====

func activate_zone(zone_name: String) -> void:
	"""Ativa uma spawn zone específica"""
	var zone = get_node_or_null(zone_name)
	if zone and zone.has_method("activate"):
		zone.activate()

func deactivate_zone(zone_name: String) -> void:
	"""Desativa uma spawn zone"""
	var zone = get_node_or_null(zone_name)
	if zone and zone.has_method("deactivate"):
		zone.deactivate()

func clear_all_zones() -> void:
	"""Limpa todos os inimigos de todas as zonas"""
	for zone in get_tree().get_nodes_in_group("spawn_zone"):
		if zone.has_method("clear_all_enemies"):
			zone.clear_all_enemies()

# ===== DEBUG =====

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	
	if event.is_action_pressed("ui_page_down"):
		print("🧪 [DEBUG] Limpar todas as zonas")
		clear_all_zones()
