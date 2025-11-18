extends Area2D

@export var player: Node
@export var respawn_position: Vector2
@export var activate_particles: Node2D
@export var activate_sound: AudioStreamPlayer
@export var destroy_after_activation: bool = true

func _ready() -> void:
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body != player:
		return

	# 🔥 1. Ativa modo metroidvania
	player.enable_metroidvania_mode()

	# 🔥 2. Atualiza respawn do player
	player.respawn_position = respawn_position
	print("🏁 Checkpoint Metroidvania ativado! Respawn atualizado.")

	# 🔥 3. Toca o som
	if activate_sound:
		activate_sound.play()

	# 🔥 4. Ativa partículas por 1 segundo
	if activate_particles:
		activate_particles.visible = true
		activate_particles.process_mode = Node.PROCESS_MODE_ALWAYS
		if activate_particles.has_method("restart"):
			activate_particles.restart()

		# Partículas desligam depois de 1 segundo
		await get_tree().create_timer(1.0).timeout
		activate_particles.visible = false

	# 🔥 5. Se quiser sumir após ativação
	if destroy_after_activation:
		queue_free()
