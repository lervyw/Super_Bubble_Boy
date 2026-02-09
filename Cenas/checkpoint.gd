extends Area2D
# =========================================================
#  CHECKPOINT (POWER-UP)
#  Ao encostar:
#  - ativa checkpoint (muda modo do player)
#  - atualiza respawn (por Node2D ou Vector2)
#  - opcionalmente restaura HP
#  - toca som e mostra partículas
#  - opcionalmente se destrói (one-shot)
# =========================================================


# ================================
#           MODOS
# ================================
# Define qual modo o player entra ao ativar esse checkpoint
enum CheckpointMode { PLATAFORMA, METROIDVANIA }


# ================================
#          REFERÊNCIAS
# ================================
@export var player: CharacterBody2D


# ================================
#      CONFIG DO CHECKPOINT
# ================================
@export_group("Modo do Checkpoint")
@export var checkpoint_mode: CheckpointMode = CheckpointMode.PLATAFORMA


# ================================
#            RESPAWN
# ================================
@export_group("Respawn")

# Se true, atualiza o respawn do player
@export var update_respawn: bool = true

# Se true, usa um Node2D do mapa como posição de respawn
@export var use_spawn_node: bool = true

# Ponto de respawn no mapa (melhor opção, porque é visual)
@export var spawn_point: Node2D

# Fallback: posição manual se não usar Node2D
@export var respawn_position: Vector2 = Vector2.ZERO


# ================================
#            FEEDBACK
# ================================
@export_group("Feedback")

# Partículas/efeito visual ao ativar
@export var activate_particles: Node2D

# Som ao ativar
@export var activate_sound: AudioStreamPlayer

# Se true, o checkpoint some depois de ativar
@export var destroy_after_activation: bool = false


# ================================
#               HP
# ================================
@export_group("HP")

# Se true, restaura HP ao ativar (quando houver stats)
@export var restore_health_on_activate: bool = true


# ================================
#             READY
# ================================
func _ready() -> void:
	# Se não foi setado no Inspector, tenta achar o player pelo grupo
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	# Conecta o sinal de coleta/contato apenas uma vez
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


# ================================
#          ATIVAÇÃO
# ================================
func _on_body_entered(body: Node2D) -> void:
	# Só ativa se quem entrou for o player
	if body != player:
		return

	print("🏁 Checkpoint ativado: ", name)

	# ----- 1) Troca o modo do jogo -----
	# (Plataforma = vidas / Metroidvania = HP e habilidades)
	match checkpoint_mode:
		CheckpointMode.PLATAFORMA:
			if player.has_method("enable_plataforma_mode"):
				player.enable_plataforma_mode()
		CheckpointMode.METROIDVANIA:
			if player.has_method("enable_metroidvania_mode"):
				player.enable_metroidvania_mode()

	# ----- 2) Atualiza o respawn do player -----
	if update_respawn and player:
		# Começa com a posição atual do player por segurança
		var pos := player.global_position

		# Preferência: usar Node2D do mapa
		if use_spawn_node and spawn_point:
			pos = spawn_point.global_position
		# Alternativa: usar Vector2 configurado no Inspector
		elif not use_spawn_node and respawn_position != Vector2.ZERO:
			pos = respawn_position

		# Aplica o respawn no player
		player.respawn_position = pos
		print("📍 Respawn atualizado para: ", pos)

	# ----- 3) Cura/HP ao ativar (opcional) -----
	# Aqui você usa "stats" dentro do player, então precisa existir e estar setado
	if restore_health_on_activate and "stats" in player and player.stats:
		var s = player.stats
		if s.has_method("reset_health_full"):
			s.reset_health_full()
			print("💚 HP restaurado no checkpoint")

	# ----- 4) Som de ativação -----
	if activate_sound:
		activate_sound.play()

	# ----- 5) Partículas (efeito visual temporário) -----
	if activate_particles:
		activate_particles.visible = true
		activate_particles.process_mode = Node.PROCESS_MODE_ALWAYS

		# Se o node tiver método restart, reinicia o efeito
		if activate_particles.has_method("restart"):
			activate_particles.restart()

		# Espera 1 segundo e desliga o efeito
		var tree := get_tree()
		if tree:
			var timer := tree.create_timer(1.0)
			await timer.timeout

		activate_particles.visible = false

	# ----- 6) One-shot: destrói o checkpoint após uso -----
	if destroy_after_activation:
		queue_free()
