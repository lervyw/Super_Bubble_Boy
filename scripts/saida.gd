extends Area2D

@export var level: Node2D
@export var player: CharacterBody2D

@export var instant_kill: bool = true
@export var damage_amount: int = 999
@export var respawn_delay: float = 0.5

func _ready() -> void:
	if not level:
		level = get_tree().current_scene
		if level:
			print("✅ Kill Zone: Level encontrado automaticamente: ", level.name)
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if not level:
		push_error("Kill Zone: Level não encontrado! Configure no Inspector.")
	
	if not player:
		push_warning("Kill Zone: Player não encontrado!")
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not is_player(body):
		return
	
	print("☠️ Player caiu na kill zone!")
	
	if instant_kill:
		kill_player(body)
	else:
		damage_player(body)

func is_player(body: Node2D) -> bool:
	if body.name == "player":
		return true
	if body.is_in_group("player"):
		return true
	if player and body == player:
		return true
	return false

func kill_player(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(999) # fatal, sistema de vidas cuida do resto
	else:
		var stats = get_player_stats(body)
		if stats and stats.has_method("take_damage"):
			stats.take_damage(999)

func damage_player(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage_amount)
	else:
		var stats = get_player_stats(body)
		if stats and stats.has_method("take_damage"):
			stats.take_damage(damage_amount)

func get_player_stats(body: Node2D) -> Node:
	if body.has_node("Stats"):
		return body.get_node("Stats")
	for child in body.get_children():
		if child.name.to_lower().contains("stat"):
			return child
	return null
