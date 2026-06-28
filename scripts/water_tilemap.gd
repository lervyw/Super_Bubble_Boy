extends Node2D
# =========================================================
#  WATER TILEMAP
#  Paint water visually with a TileMapLayer, then generate
#  merged Area2D water volumes from the painted cells.
# =========================================================

@export var tile_layer: TileMapLayer
@export var player: CharacterBody2D
@export var generate_on_ready: bool = true
@export var affected_groups: Array[StringName] = [&"player", &"jogador", &"slime", &"boss"]
@export_flags_2d_physics var water_collision_mask: int = 63

@export_group("Animation")
@export var animate_tiles: bool = true
@export_range(0.05, 2.0, 0.05) var frame_time: float = 0.35
@export var animation_source_ids: Array[int] = [0, 1]

var overlap_counts: Dictionary = {}
var generated_area_parent: Node2D
var animation_timer: float = 0.0
var animation_frame_index: int = 0


func _ready() -> void:
	if not tile_layer:
		tile_layer = get_node_or_null("WaterTiles") as TileMapLayer
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not player:
		player = get_tree().get_first_node_in_group("jogador") as CharacterBody2D

	if generate_on_ready:
		rebuild_water_areas()


func _process(delta: float) -> void:
	if not animate_tiles:
		return
	if not tile_layer:
		return
	if animation_source_ids.size() < 2:
		return

	animation_timer += delta
	if animation_timer < frame_time:
		return

	animation_timer = 0.0
	animation_frame_index = (animation_frame_index + 1) % animation_source_ids.size()
	_apply_animation_frame(animation_source_ids[animation_frame_index])


func rebuild_water_areas() -> void:
	if not tile_layer:
		push_warning("WaterTilemap: tile_layer nao configurado.")
		return
	if not tile_layer.tile_set:
		push_warning("WaterTilemap: WaterTiles sem TileSet.")
		return

	_clear_generated_areas()

	generated_area_parent = Node2D.new()
	generated_area_parent.name = "GeneratedWaterAreas"
	add_child(generated_area_parent)

	for rect in _build_cell_rects(tile_layer.get_used_cells()):
		_create_water_area(rect)


func _apply_animation_frame(source_id: int) -> void:
	for cell in tile_layer.get_used_cells():
		var current_source: int = tile_layer.get_cell_source_id(cell)
		if not animation_source_ids.has(current_source):
			continue

		tile_layer.set_cell(cell, source_id, Vector2i.ZERO)


func _clear_generated_areas() -> void:
	for target in overlap_counts.keys():
		if is_instance_valid(target):
			if target.has_method("exit_water_zone"):
				target.exit_water_zone()
			elif "in_water" in target:
				target.set("in_water", false)

	var old_parent: Node = get_node_or_null("GeneratedWaterAreas")
	if old_parent:
		old_parent.queue_free()
	overlap_counts.clear()


func _build_cell_rects(cells: Array[Vector2i]) -> Array[Rect2i]:
	var occupied: Dictionary = {}
	for cell in cells:
		occupied[cell] = true

	var sorted_cells: Array[Vector2i] = cells.duplicate()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)

	var visited: Dictionary = {}
	var rects: Array[Rect2i] = []

	for cell in sorted_cells:
		if visited.has(cell):
			continue

		var width: int = 1
		while occupied.has(Vector2i(cell.x + width, cell.y)) and not visited.has(Vector2i(cell.x + width, cell.y)):
			width += 1

		var height: int = 1
		var can_grow: bool = true
		while can_grow:
			for x in range(cell.x, cell.x + width):
				var next_cell: Vector2i = Vector2i(x, cell.y + height)
				if not occupied.has(next_cell) or visited.has(next_cell):
					can_grow = false
					break
			if can_grow:
				height += 1

		for y in range(cell.y, cell.y + height):
			for x in range(cell.x, cell.x + width):
				visited[Vector2i(x, y)] = true

		rects.append(Rect2i(cell, Vector2i(width, height)))

	return rects


func _create_water_area(cell_rect: Rect2i) -> void:
	var tile_size: Vector2 = Vector2(tile_layer.tile_set.tile_size)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(cell_rect.size) * tile_size

	var area: Area2D = Area2D.new()
	area.name = "WaterArea_%d_%d" % [cell_rect.position.x, cell_rect.position.y]
	area.collision_layer = 0
	area.collision_mask = water_collision_mask
	area.monitoring = true
	area.monitorable = false
	generated_area_parent.add_child(area)

	var top_left_center: Vector2 = tile_layer.map_to_local(cell_rect.position)
	var rect_center_offset: Vector2 = Vector2(cell_rect.size - Vector2i.ONE) * tile_size * 0.5
	area.position = tile_layer.position + top_left_center + rect_center_offset

	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	area.add_child(collision)

	area.body_entered.connect(_on_water_body_entered.bind(area))
	area.body_exited.connect(_on_water_body_exited.bind(area))
	area.area_entered.connect(_on_water_area_entered.bind(area))
	area.area_exited.connect(_on_water_area_exited.bind(area))


func _on_water_body_entered(body: Node, water_area: Area2D) -> void:
	var target: Node = _resolve_water_target(body)
	if target:
		_enter_water(target, water_area)


func _on_water_body_exited(body: Node, water_area: Area2D) -> void:
	var target: Node = _resolve_water_target(body)
	if target:
		_exit_water(target, water_area)


func _on_water_area_entered(area: Area2D, water_area: Area2D) -> void:
	var target: Node = _resolve_water_target(area)
	if target:
		_enter_water(target, water_area)


func _on_water_area_exited(area: Area2D, water_area: Area2D) -> void:
	var target: Node = _resolve_water_target(area)
	if target:
		_exit_water(target, water_area)


func _resolve_water_target(node: Node) -> Node:
	var current: Node = node
	while current:
		for group_name in affected_groups:
			if current.is_in_group(group_name):
				return current
		current = current.get_parent()
	return null


func _enter_water(target: Node, water_area: Node = null) -> void:
	var count: int = int(overlap_counts.get(target, 0)) + 1
	overlap_counts[target] = count
	if count > 1:
		return

	if target.has_method("enter_water_zone"):
		target.enter_water_zone(water_area if water_area else self)
	elif "in_water" in target:
		target.set("in_water", true)


func _exit_water(target: Node, water_area: Node = null) -> void:
	var count: int = maxi(int(overlap_counts.get(target, 0)) - 1, 0)
	if count > 0:
		overlap_counts[target] = count
		return

	overlap_counts.erase(target)

	if target.has_method("exit_water_zone"):
		target.exit_water_zone(water_area if water_area else self)
	elif "in_water" in target:
		target.set("in_water", false)
