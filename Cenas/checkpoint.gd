extends Area2D

enum CheckpointMode { PLATAFORMA, METROIDVANIA }

@export var player: CharacterBody2D

@export_group("Modo do Checkpoint")
@export var checkpoint_mode: CheckpointMode = CheckpointMode.PLATAFORMA

@export_group("Respawn")
@export var update_respawn: bool = true
@export var use_spawn_node: bool = true
@export var spawn_point: Node2D           # Node2D de referência no mapa
@export var respawn_position: Vector2 = Vector2.ZERO  # fallback se não usar Node2D

@export_group("Feedback")
@export var activate_particles: Node2D
@export var activate_sound: AudioStreamPlayer
@export var destroy_after_activation: bool = false

@export_group("HP")
@export var restore_health_on_activate: bool = true

func _ready() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body != player:
		return

	print("🏁 Checkpoint ativado: ", name)

	# ----- 1) Muda modo de jogo -----
	match checkpoint_mode:
		CheckpointMode.PLATAFORMA:
			if player.has_method("enable_plataforma_mode"):
				player.enable_plataforma_mode()
		CheckpointMode.METROIDVANIA:
			if player.has_method("enable_metroidvania_mode"):
				player.enable_metroidvania_mode()

	# ----- 2) Atualiza respawn -----
	if update_respawn and player:
		var pos := player.global_position

		if use_spawn_node and spawn_point:
			pos = spawn_point.global_position
		elif not use_spawn_node and respawn_position != Vector2.ZERO:
			pos = respawn_position

		player.respawn_position = pos
		print("📍 Respawn atualizado para: ", pos)

	# ----- 3) Restaura HP se configurado -----
	if restore_health_on_activate and "stats" in player and player.stats:
		var s = player.stats
		if s.has_method("reset_health_full"):
			s.reset_health_full()
			print("💚 HP restaurado no checkpoint")

	# ----- 4) Som -----
	if activate_sound:
		activate_sound.play()

	# ----- 5) Partículas -----
	if activate_particles:
		activate_particles.visible = true
		activate_particles.process_mode = Node.PROCESS_MODE_ALWAYS
		if activate_particles.has_method("restart"):
			activate_particles.restart()

		var tree := get_tree()
		if tree:
			var timer := tree.create_timer(1.0)
			await timer.timeout
		activate_particles.visible = false

	# ----- 6) Destruir se for one-shot -----
	if destroy_after_activation:
		queue_free()
