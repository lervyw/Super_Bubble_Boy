extends Node2D

@export var point_name_prefix: String = "ponto_luz"
@export var light_color: Color = Color(0.84, 0.95, 1.0, 1.0)
@export_range(0.0, 6.0, 0.05) var day_energy: float = 0.45
@export_range(0.0, 6.0, 0.05) var night_energy: float = 1.85
@export_range(0.05, 6.0, 0.05) var texture_scale: float = 1.05
@export_range(64, 1024, 1) var texture_size: int = 512

var _lights: Array[PointLight2D] = []


func _ready() -> void:
	call_deferred("_setup_point_lights")


func _setup_point_lights() -> void:
	_lights.clear()
	var root := get_tree().current_scene
	if not root:
		root = get_parent()
	if not root:
		return

	var texture := _create_soft_light_texture()
	for point in _find_light_points(root):
		var light := PointLight2D.new()
		light.name = "%s_light" % point.name
		light.global_position = point.global_position
		light.z_as_relative = false
		light.color = light_color
		light.energy = day_energy
		light.texture = texture
		light.texture_scale = texture_scale
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)

	var cycle := get_tree().get_first_node_in_group("dayAndNightCycle")
	if cycle and cycle.has_signal("day_night_progress"):
		cycle.day_night_progress.connect(_on_day_night_progress)


func _find_light_points(root: Node) -> Array[Node2D]:
	var points: Array[Node2D] = []
	_collect_light_points(root, points)
	return points


func _collect_light_points(node: Node, points: Array[Node2D]) -> void:
	if node is Node2D and node.name.begins_with(point_name_prefix):
		points.append(node as Node2D)
	for child in node.get_children():
		_collect_light_points(child, points)


func _create_soft_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.56, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.22),
		Color(1.0, 1.0, 1.0, 0.0)
	])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = texture_size
	texture.height = texture_size
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _on_day_night_progress(progress: float) -> void:
	var night_amount := _get_night_amount(progress)
	var target_energy := lerpf(day_energy, night_energy, night_amount)
	for light in _lights:
		if is_instance_valid(light):
			light.energy = target_energy
			light.color = _get_light_color(night_amount)


func _get_night_amount(progress: float) -> float:
	if progress < 0.28:
		return progress / 0.28 * 0.35
	if progress < 0.50:
		return lerpf(0.35, 1.0, (progress - 0.28) / 0.22)
	if progress < 0.72:
		return lerpf(1.0, 0.35, (progress - 0.50) / 0.22)
	return lerpf(0.35, 0.0, (progress - 0.72) / 0.28)


func _get_light_color(night_amount: float) -> Color:
	var day_tint := Color(0.86, 0.96, 1.0, 1.0)
	var night_tint := Color(0.62, 0.76, 1.0, 1.0)
	return day_tint.lerp(night_tint, night_amount)
