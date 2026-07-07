extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

func _ready():
	var root = get_tree().root
	color_rect.size = root.get_visible_rect().size
	get_tree().root.size_changed.connect(_on_screen_resized)


func _on_screen_resized():
	var root = get_tree().root
	color_rect.size = root.get_visible_rect().size

	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("screen_width", color_rect.size.x)
		mat.set_shader_parameter("screen_height", color_rect.size.y)
