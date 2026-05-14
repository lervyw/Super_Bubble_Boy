extends CanvasLayer

const BUTTON_SIZE := Vector2(46, 46)
const SMALL_BUTTON_SIZE := Vector2(38, 38)
const PAUSE_BUTTON_SIZE := Vector2(54, 30)
const EDGE_PADDING := 18.0
const BOTTOM_PADDING := 18.0
const BUTTON_GAP := 8.0

var controls: Array[Dictionary] = [
	{"name": "Pause", "action": "pause_menu", "label": "PAUSE", "group": "top_right", "pos": Vector2(0, 0), "size": PAUSE_BUTTON_SIZE},
	{"name": "Left", "action": "left", "label": "<", "group": "left_pad", "pos": Vector2(0, 0), "size": BUTTON_SIZE},
	{"name": "Right", "action": "right", "label": ">", "group": "left_pad", "pos": Vector2(108, 0), "size": BUTTON_SIZE},
	{"name": "Down", "action": "crouch", "label": "v", "group": "left_pad", "pos": Vector2(54, 42), "size": BUTTON_SIZE},
	{"name": "Jump", "action": "jump", "label": "A", "group": "right_pad", "pos": Vector2(54, 0), "size": BUTTON_SIZE},
	{"name": "Attack", "action": "attack", "label": "X", "group": "right_pad", "pos": Vector2(0, 54), "size": BUTTON_SIZE},
	{"name": "Dash", "action": "dash", "label": "B", "group": "right_pad", "pos": Vector2(108, 54), "size": BUTTON_SIZE},
	{"name": "HudMenu", "action": "hud_menu", "label": "Y", "group": "right_pad", "pos": Vector2(54, 108), "size": BUTTON_SIZE},
	{"name": "PowerUp", "action": "hud_select_up", "label": "^", "group": "left_pad", "pos": Vector2(58, -90), "size": SMALL_BUTTON_SIZE},
	{"name": "PowerLeft", "action": "hud_select_left", "label": "<", "group": "left_pad", "pos": Vector2(18, -50), "size": SMALL_BUTTON_SIZE},
	{"name": "PowerRight", "action": "hud_select_right", "label": ">", "group": "left_pad", "pos": Vector2(98, -50), "size": SMALL_BUTTON_SIZE},
	{"name": "PowerDown", "action": "hud_select_down", "label": "v", "group": "left_pad", "pos": Vector2(58, -10), "size": SMALL_BUTTON_SIZE},
	{"name": "Normal", "action": "normal", "label": "N", "group": "right_pad", "pos": Vector2(0, -44), "size": SMALL_BUTTON_SIZE},
	{"name": "Bubble", "action": "forma1", "label": "BOL", "group": "right_pad", "pos": Vector2(46, -44), "size": SMALL_BUTTON_SIZE},
	{"name": "Super", "action": "forma2", "label": "SUP", "group": "right_pad", "pos": Vector2(92, -44), "size": SMALL_BUTTON_SIZE},
]

var button_nodes: Dictionary = {}
var label_nodes: Dictionary = {}


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_controls()
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)


func _create_controls() -> void:
	for item in controls:
		var button_name: String = item["name"]
		var action_name: String = item["action"]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		var button := TouchScreenButton.new()
		button.name = button_name
		button.action = action_name
		button.texture_normal = _make_button_texture(item["size"], Color(0.04, 0.10, 0.16, 0.48), Color(0.62, 0.86, 1.0, 0.9))
		button.texture_pressed = _make_button_texture(item["size"], Color(0.15, 0.42, 0.66, 0.72), Color(0.94, 1.0, 1.0, 1.0))
		add_child(button)
		button_nodes[button_name] = button

		var label := Label.new()
		label.name = "%sLabel" % button_name
		label.text = item["label"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.94, 1.0, 1.0, 0.95))
		add_child(label)
		label_nodes[button_name] = label


func _update_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var left_base := Vector2(EDGE_PADDING, viewport_size.y - BOTTOM_PADDING - BUTTON_SIZE.y * 2.0)
	var right_base := Vector2(
		viewport_size.x - EDGE_PADDING - BUTTON_SIZE.x * 3.0 - BUTTON_GAP * 2.0,
		viewport_size.y - BOTTOM_PADDING - BUTTON_SIZE.y * 3.0 - BUTTON_GAP * 2.0
	)
	var top_right_base := Vector2(viewport_size.x - EDGE_PADDING - PAUSE_BUTTON_SIZE.x, EDGE_PADDING)

	for item in controls:
		var button_name: String = item["name"]
		var button := button_nodes.get(button_name) as TouchScreenButton
		var label := label_nodes.get(button_name) as Label
		if not button or not label:
			continue

		var size: Vector2 = item["size"]
		var group: String = item["group"]
		var base := left_base
		match group:
			"right_pad":
				base = right_base
			"top_right":
				base = top_right_base
		var position: Vector2 = base + item["pos"]
		button.position = position

		label.position = position
		label.size = size


func _make_button_texture(size: Vector2, fill: Color, border: Color) -> Texture2D:
	var width := int(size.x)
	var height := int(size.y)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var center := Vector2((width - 1) * 0.5, (height - 1) * 0.5)
	var radius := minf(size.x, size.y) * 0.5 - 1.0
	var border_radius := radius - 2.0

	for y in range(height):
		for x in range(width):
			var distance := Vector2(x, y).distance_to(center)
			if distance <= radius:
				image.set_pixel(x, y, border if distance >= border_radius else fill)

	return ImageTexture.create_from_image(image)
