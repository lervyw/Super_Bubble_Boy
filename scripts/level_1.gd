extends Node2D
# =========================================================
#  LEVEL 1 CONTROLLER
#  Responsável por:
#  - Inicialização do nível
#  - Reset / checkpoint do player
#  - Conexão com o boss e troca de cena
#  - Configuração automática das SpawnZones
# =========================================================


# ================================
#           REFERÊNCIAS
# ================================
@export_group("References")

# Referência para o player da fase
@export var player: CharacterBody2D

# Referência para o sistema de status (vida, etc)
@export var stats: Node


# ================================
#       CONFIGURAÇÃO DE CHECKPOINT
# ================================
@export_group("Checkpoint")

# Posição onde o player reaparece ao morrer
@export var checkpoint_position: Vector2 = Vector2(288, 207)

# Define se o player perde vida ao morrer
@export var lose_health_on_death: bool = false


# ================================
#          CONFIGURAÇÃO DE TEMPO
# ================================
@export_group("Level Timer")

# Liga/desliga o contador da fase pelo Inspector do nível.
@export var level_timer_enabled: bool = true

# Tempo total da fase em segundos.
@export_range(1.0, 3600.0, 1.0) var level_time_limit: float = 180.0

# Timer HUD da fase.
@export var timer_node: NodePath = NodePath("Timer")


# ================================
#         CONTROLES MOBILE
# ================================
@export_group("Mobile Controls")

@export var mobile_controls_enabled: bool = true
@export var mobile_controls_show_on_desktop: bool = false
@export var mobile_controls_scene: PackedScene = preload("res://Cenas/mobile_controls.tscn")


# ================================
#        PRÓXIMO NÍVEL
# ================================
@export_group("Next Level")

# Caminho do nó do boss deste nível
@export var boss_node: NodePath

# Cena que será carregada após derrotar o boss
@export var next_scene: PackedScene


# ================================
#             READY
# ================================
func _ready() -> void:
	print("🎮 Nível iniciado!")

	show_tutorial_message("Pressione a tecla J para atacar")
	show_dash_tutorial_after_delay()

	# Restaura vida cheia ao entrar no nível (se existir stats)
	if stats and stats.has_method("restore_all"):
		stats.restore_all()
	elif stats and stats.has_method("restore_full_health"):
		stats.restore_full_health()
		if stats.has_method("restore_full_mana"):
			stats.restore_full_mana()

	# Validação obrigatória do player
	if not player:
		push_error("Player reference não definida!")
		return

	# Aviso caso stats não esteja definido
	if not stats:
		push_warning("Stats reference não definida!")

	# --- Conexão com o boss ---
	# Se um boss foi configurado e existe na cena
	if boss_node != NodePath("") and has_node(boss_node):
		var boss = get_node(boss_node)
		var hud = player.get_node_or_null("HUD")

		if hud and hud.has_method("set_boss_target"):
			hud.set_boss_target(boss)

		# Conecta o sinal de vitória do boss
		if boss and boss.has_signal("boss_defeated"):
			boss.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
			print("✅ Boss conectado ao evento de vitória!")
	else:
		push_warning("⚠️ Nenhum boss configurado para este nível.")

	# Configura automaticamente todas as spawn zones
	setup_spawn_zones()
	setup_level_timer()
	setup_mobile_controls()


# ================================
#        TUTORIAL
# ================================
func show_dash_tutorial_after_delay() -> void:
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(self):
		show_tutorial_message("Pressione a tecla K para dar dash")


func show_tutorial_message(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "TutorialLayer"
	add_child(layer)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -160.0
	label.offset_right = 160.0
	label.offset_top = 20.0
	label.offset_bottom = 44.0
	layer.add_child(label)

	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	await tween.finished
	if is_instance_valid(layer):
		layer.queue_free()


# ================================
#        BOSS DERROTADO
# ================================
func _on_boss_defeated() -> void:
	print("🏁 Boss derrotado! Mudando de cena em 2 segundos...")

	# Pequeno delay antes de trocar de fase
	await get_tree().create_timer(2.0).timeout

	# Troca para a próxima cena
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
	else:
		push_warning("⚠️ Nenhuma cena configurada em 'next_scene'.")


# ================================
#        SPAWN ZONES
# ================================
func setup_spawn_zones() -> void:
	"""Configura referências automáticas nas spawn zones"""

	# Busca todas as zonas no grupo "spawn_zone"
	var zones = get_tree().get_nodes_in_group("spawn_zone")

	for zone in zones:
		if zone is SpawnZone:
			# Injeta o player automaticamente na zona
			if not zone.player:
				zone.player = player

			print("✅ SpawnZone '%s' configurada" % zone.name)


func setup_level_timer() -> void:
	if timer_node == NodePath(""):
		return

	var level_timer = get_node_or_null(timer_node)
	if not level_timer:
		push_warning("Timer da fase não encontrado: %s" % timer_node)
		return

	if level_timer.has_method("configure_level_timer"):
		level_timer.configure_level_timer(level_timer_enabled, level_time_limit, player)
		return

	level_timer.set("time_left", level_time_limit)
	level_timer.set("player", player)
	if level_timer.has_method("resume_timer") and level_timer_enabled:
		level_timer.resume_timer()
	elif level_timer.has_method("pause_timer"):
		level_timer.pause_timer()
	level_timer.visible = level_timer_enabled


func setup_mobile_controls() -> void:
	if not mobile_controls_enabled:
		return
	if has_node("MobileControls"):
		return

	var os_name := OS.get_name()
	var should_show := mobile_controls_show_on_desktop or os_name == "Android"
	if not should_show:
		return

	if not mobile_controls_scene:
		push_warning("Cena dos controles mobile não configurada.")
		return

	var controls := mobile_controls_scene.instantiate()
	controls.name = "MobileControls"
	add_child(controls)


# ================================
#      RESET / CHECKPOINT
# ================================
func reset_scene() -> void:
	"""LEGACY: Mantido para compatibilidade antiga"""
	reset_player_position()


func reset_player_position() -> void:
	"""Reseta o player para o checkpoint"""

	if not player:
		push_error("Level: Player não encontrado!")
		return

	print("🔄 Player respawnando no checkpoint")

	# Reseta posição e velocidade
	player.global_position = checkpoint_position
	player.velocity = Vector2.ZERO

	# Força estado idle se existir máquina de estados
	if player.has_method("change_state"):
		player.change_state(player.State.IDLE)

	# Remove vida ao morrer (se ativado)
	if lose_health_on_death and stats:
		stats.update_health("Decrease", 1)
		print("💔 -1 HP por morte")

	if stats and stats.has_method("reset_mana_full"):
		stats.reset_mana_full()

	# Garante que o player nunca fique com 0 de vida
	if stats and stats.current_health <= 0:
		stats.current_health = 1
		stats.emit_signal("health_changed", stats.current_health, stats.max_health)


# ================================
#   CONTROLE DE SPAWN ZONES (OPCIONAL)
# ================================
func activate_zone(zone_name: String) -> void:
	"""Ativa uma spawn zone específica"""
	var zone = get_node_or_null(zone_name)
	if zone and zone.has_method("activate"):
		zone.activate()


func deactivate_zone(zone_name: String) -> void:
	"""Desativa uma spawn zone específica"""
	var zone = get_node_or_null(zone_name)
	if zone and zone.has_method("deactivate"):
		zone.deactivate()


func clear_all_zones() -> void:
	"""Remove todos os inimigos de todas as zonas"""
	for zone in get_tree().get_nodes_in_group("spawn_zone"):
		if zone.has_method("clear_all_enemies"):
			zone.clear_all_enemies()


# ================================
#              DEBUG
# ================================
func _input(event: InputEvent) -> void:
	# Debug só funciona em build de desenvolvimento
	if not OS.is_debug_build():
		return

	# Tecla de debug para limpar todas as zonas
	if event.is_action_pressed("ui_page_down"):
		print("🧪 [DEBUG] Limpar todas as zonas")
		clear_all_zones()
