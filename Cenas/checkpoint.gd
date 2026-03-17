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
@export var update_respawn: bool = true
@export var use_spawn_node: bool = true
@export var spawn_point: Node2D
@export var respawn_position: Vector2 = Vector2.ZERO

# ================================
#            FEEDBACK
# ================================
@export_group("Feedback")
@export var activate_particles: Node2D
@export var activate_sound: AudioStreamPlayer
@export var destroy_after_activation: bool = false

# ================================
#               HP
# ================================
@export_group("HP")
@export var restore_health_on_activate: bool = true

# Evita ativação duplicada
var activated: bool = false

# ================================
#             READY
# ================================
func _ready() -> void:
	# Se não foi setado no Inspector, tenta achar o player pelo grupo
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	# Conecta sinais apenas uma vez
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

# ================================
#          DETECÇÃO
# ================================
func _on_body_entered(body: Node2D) -> void:
	if activated:
		return

	if is_player_body(body):
		await activate_checkpoint()

func _on_area_entered(area: Area2D) -> void:
	if activated:
		return

	if is_player_area(area):
		await activate_checkpoint()

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

	if area.get_parent() == player:
		return true

	if player != null and player.is_ancestor_of(area):
		return true

	return false

# ================================
#          ATIVAÇÃO
# ================================
func activate_checkpoint() -> void:
	if activated:
		return

	activated = true

	print("🏁 Checkpoint ativado: ", name)

	# ----- 1) Troca o modo do jogo -----
	match checkpoint_mode:
		CheckpointMode.PLATAFORMA:
			if player and player.has_method("enable_plataforma_mode"):
				player.enable_plataforma_mode()

		CheckpointMode.METROIDVANIA:
			if player and player.has_method("enable_metroidvania_mode"):
				player.enable_metroidvania_mode()

	# ----- 2) Atualiza o respawn do player -----
	if update_respawn and player:
		var pos := player.global_position

		if use_spawn_node and spawn_point:
			pos = spawn_point.global_position
		elif not use_spawn_node and respawn_position != Vector2.ZERO:
			pos = respawn_position

		player.respawn_position = pos
		print("📍 Respawn atualizado para: ", pos)

	# ----- 3) Cura/HP ao ativar (opcional) -----
	if restore_health_on_activate and player and "stats" in player and player.stats:
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

		if activate_particles.has_method("restart"):
			activate_particles.restart()

		var tree := get_tree()
		if tree:
			var timer := tree.create_timer(1.0)
			await timer.timeout

		if is_instance_valid(activate_particles):
			activate_particles.visible = false

	# ----- 6) One-shot: destrói o checkpoint após uso -----
	if destroy_after_activation:
		queue_free()
