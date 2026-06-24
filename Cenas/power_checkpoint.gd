extends Area2D

enum WheelSlot { ULTIMATE, SPECIAL_ATTACK, BUBBLE_PROJECTILE, PLACEHOLDER }

@export var player: CharacterBody2D
@export var unlock_form: int = 0
@export var unlock_slot: int = 0

@export_group("Respawn")
@export var update_respawn: bool = true
@export var use_spawn_node: bool = true
@export var spawn_point: Node2D
@export var respawn_position: Vector2 = Vector2.ZERO

@export_group("Feedback")
@export var activate_particles: Node2D
@export var activate_sound: AudioStreamPlayer
@export var destroy_after_activation: bool = false

@export_group("HP")
@export var restore_health_on_activate: bool = true

@export_group("Mana")
@export var restore_mana_on_activate: bool = true

var activated: bool = false


func _ready() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


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


func activate_checkpoint() -> void:
	if activated:
		return
	activated = true

	print("⚡ Power Checkpoint ativado: ", name)

	if player and "unlocked_wheel_slots" in player:
		if player.has_method("is_wheel_slot_unlocked_for_form"):
			if player.is_wheel_slot_unlocked_for_form(unlock_slot, unlock_form):
				print("   Slot ja desbloqueado, ignorando")
				if destroy_after_activation:
					queue_free()
				return

		var form_slots = player.unlocked_wheel_slots.get(unlock_form, {})
		form_slots[unlock_slot] = true
		print("   Slot ", unlock_slot, " desbloqueado para forma ", unlock_form)

	if update_respawn and player:
		var pos := player.global_position
		if use_spawn_node and spawn_point:
			pos = spawn_point.global_position
		elif not use_spawn_node and respawn_position != Vector2.ZERO:
			pos = respawn_position
		player.respawn_position = pos
		print("   Respawn atualizado para: ", pos)

	if restore_health_on_activate and player and "stats" in player and player.stats:
		var s = player.stats
		if s.has_method("reset_health_full"):
			s.reset_health_full()
			print("   HP restaurado")

	if restore_mana_on_activate and player and "stats" in player and player.stats:
		var s = player.stats
		if s.has_method("reset_mana_full"):
			s.reset_mana_full()
			print("   Mana restaurada")

	if activate_sound:
		activate_sound.play()

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

	if destroy_after_activation:
		queue_free()
