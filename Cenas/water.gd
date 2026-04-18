extends Area2D
# =========================================================
#  WATER ZONE
#  Área que simula água:
#  - Ativa física de água no player
#  - Diminui velocidade / gravidade (controlado no Player.gd)
#  - Troca estado para SWIM ao entrar
#  - Funciona com body e areas do player
# =========================================================

@export var player: CharacterBody2D

# Quantos colliders/areas do player estão dentro da água
var overlap_count: int = 0

func _ready() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)

func _on_body_entered(body: Node) -> void:
	if is_player_body(body):
		enter_water()

func _on_body_exited(body: Node) -> void:
	if is_player_body(body):
		exit_water()

func _on_area_entered(area: Area2D) -> void:
	if is_player_area(area):
		enter_water()

func _on_area_exited(area: Area2D) -> void:
	if is_player_area(area):
		exit_water()

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

func enter_water() -> void:
	if not is_instance_valid(player):
		return

	overlap_count += 1

	# Só faz a transição real na primeira entrada
	if overlap_count > 1:
		return

	player.in_water = true

	if player.has_method("change_state") and player.state != player.State.DEAD:
		player.change_state(player.State.SWIM)

	print("💧 Entrou na água")

func exit_water() -> void:
	if not is_instance_valid(player):
		return

	overlap_count = max(overlap_count - 1, 0)

	# Só sai da água quando nada mais do player estiver sobrepondo
	if overlap_count > 0:
		return

	player.in_water = false

	if player.has_method("change_state") and player.state != player.State.DEAD:
		if player.is_on_floor():
			player.change_state(player.State.IDLE)
		else:
			player.change_state(player.State.JUMP)

	print("🌊 Saiu da água")
