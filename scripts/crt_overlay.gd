extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

func _ready():
	var root = get_tree().root
	color_rect.size = root.get_visible_rect().size
	get_tree().root.size_changed.connect(_on_screen_resized)
	visible = ConfigManager.is_crt_enabled()
	_apply_crt_settings()


func _on_screen_resized():
	var root = get_tree().root
	color_rect.size = root.get_visible_rect().size

	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("screen_width", color_rect.size.x)
		mat.set_shader_parameter("screen_height", color_rect.size.y)


func _apply_crt_settings():
	var mat := color_rect.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("scanline_alpha", ConfigManager.get_crt_scanline_alpha())
	mat.set_shader_parameter("barrel_power", ConfigManager.get_crt_barrel_power())
	mat.set_shader_parameter("color_bleeding", ConfigManager.get_crt_color_bleeding())
