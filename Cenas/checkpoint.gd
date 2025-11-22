extends Area2D

@export var player: CharacterBody2D
@export var respawn_position: Vector2
@export var activate_particles: Node2D
@export var activate_sound: AudioStreamPlayer
@export var destroy_after_activation: bool = true

func _ready() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body != player:
		return

	# 1) Ativa modo Metroidvania
	player.enable_metroidvania_mode()

	# 2) Atualiza respawn do player
	player.respawn_position = respawn_position
	print("🏁 Checkpoint Metroidvania ativado! Respawn atualizado.")

	# 3) Som
	if activate_sound:
		activate_sound.play()

	# 4) Partículas por 1s
	if activate_particles:
		activate_particles.visible = true
		activate_particles.process_mode = Node.PROCESS_MODE_ALWAYS
		if activate_particles.has_method("restart"):
			activate_particles.restart()
		await get_tree().create_timer(1.0).timeout
		activate_particles.visible = false

	if destroy_after_activation:
		queue_free()
