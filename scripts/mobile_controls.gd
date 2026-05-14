extends CanvasLayer

const BUTTON_SIZE := Vector2(46, 46)
const SMALL_BUTTON_SIZE := Vector2(38, 38)
const PAUSE_BUTTON_SIZE := Vector2(54, 30)
const EDGE_PADDING := 18.0
const BOTTOM_PADDING := 18.0
const BUTTON_GAP := 8.0
const JOYSTICK_RADIUS := 56.0
const JOYSTICK_DEADZONE := 0.24
const JOYSTICK_KNOB_SIZE := Vector2(32, 32)

var controls: Array[Dictionary] = [
	{"name": "Pause", "action": "pause_menu", "label": "PAUSE", "group": "top_right", "pos": Vector2(0, 0), "size": PAUSE_BUTTON_SIZE},
	{"name": "Jump", "action": "jump", "label": "A", "group": "right_pad", "pos": Vector2(54, 0), "size": BUTTON_SIZE},
	{"name": "Attack", "action": "attack", "label": "X", "group": "right_pad", "pos": Vector2(0, 54), "size": BUTTON_SIZE},
	{"name": "Dash", "action": "dash", "label": "B", "group": "right_pad", "pos": Vector2(108, 54), "size": BUTTON_SIZE},
	{"name": "HudMenu", "action": "hud_menu", "label": "Y", "group": "right_pad", "pos": Vector2(54, 108), "size": BUTTON_SIZE},
	{"name": "Normal", "action": "normal", "label": "N", "group": "right_pad", "pos": Vector2(0, -44), "size": SMALL_BUTTON_SIZE},
	{"name": "Bubble", "action": "forma1", "label": "BOL", "group": "right_pad", "pos": Vector2(46, -44), "size": SMALL_BUTTON_SIZE},
	{"name": "Super", "action": "forma2", "label": "SUP", "group": "right_pad", "pos": Vector2(92, -44), "size": SMALL_BUTTON_SIZE},
]

var joystick_actions := ["left", "right", "crouch", "hud_select_up", "hud_select_down", "hud_select_left", "hud_select_right"]
var button_nodes: Dictionary = {}
var label_nodes: Dictionary = {}
var joystick_base: TextureRect
var joystick_knob: TextureRect
var joystick_hint: Label
var joystick_center := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_touch_index := -1
var joystick_active := false
var joystick_was_power_mode := false
var virtual_pressed: Dictionary = {}


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_actions()
	_create_joystick()
	_create_buttons()
	_update_layout()
	set_process_input(true)
	get_viewport().size_changed.connect(_update_layout)


func _process(_delta: float) -> void:
	_apply_joystick_actions()


func _exit_tree() -> void:
	_release_joystick_actions()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and joystick_touch_index == -1 and _is_inside_joystick(event.position):
			joystick_touch_index = event.index
			joystick_active = true
			_update_joystick_vector(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == joystick_touch_index and not event.pressed:
			_reset_joystick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == joystick_touch_index:
		_update_joystick_vector(event.position)
		get_viewport().set_input_as_handled()


func _ensure_actions() -> void:
	for item in controls:
		var action_name: String = item["action"]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	for action_name in joystick_actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func _create_joystick() -> void:
	joystick_base = TextureRect.new()
	joystick_base.name = "MovePowerStick"
	joystick_base.texture = _make_button_texture(Vector2.ONE * JOYSTICK_RADIUS * 2.0, Color(0.04, 0.10, 0.16, 0.34), Color(0.62, 0.86, 1.0, 0.72))
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick_base)

	joystick_knob = TextureRect.new()
	joystick_knob.name = "MovePowerStickKnob"
	joystick_knob.texture = _make_button_texture(JOYSTICK_KNOB_SIZE, Color(0.15, 0.42, 0.66, 0.72), Color(0.94, 1.0, 1.0, 0.95))
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick_knob)

	joystick_hint = Label.new()
	joystick_hint.name = "MovePowerStickHint"
	joystick_hint.text = "MOVE / PODER"
	joystick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	joystick_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	joystick_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_hint.add_theme_font_size_override("font_size", 9)
	joystick_hint.add_theme_color_override("font_color", Color(0.94, 1.0, 1.0, 0.8))
	add_child(joystick_hint)


func _create_buttons() -> void:
	for item in controls:
		var button_name: String = item["name"]
		var action_name: String = item["action"]
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
	joystick_center = Vector2(EDGE_PADDING + JOYSTICK_RADIUS + 18.0, viewport_size.y - BOTTOM_PADDING - JOYSTICK_RADIUS - 8.0)

	if joystick_base:
		joystick_base.position = joystick_center - Vector2.ONE * JOYSTICK_RADIUS
		joystick_base.size = Vector2.ONE * JOYSTICK_RADIUS * 2.0
	if joystick_knob:
		_update_knob_position()
	if joystick_hint:
		joystick_hint.position = joystick_center + Vector2(-58.0, JOYSTICK_RADIUS + 2.0)
		joystick_hint.size = Vector2(116.0, 16.0)

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
		var base := right_base
		if item["group"] == "top_right":
			base = top_right_base
		var position: Vector2 = base + item["pos"]
		button.position = position

		label.position = position
		label.size = size


func _is_inside_joystick(position: Vector2) -> bool:
	return position.distance_to(joystick_center) <= JOYSTICK_RADIUS * 1.35


func _update_joystick_vector(position: Vector2) -> void:
	var offset := position - joystick_center
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS
	joystick_vector = offset / JOYSTICK_RADIUS
	_update_knob_position()


func _update_knob_position() -> void:
	if not joystick_knob:
		return

	var knob_center := joystick_center + joystick_vector * JOYSTICK_RADIUS
	joystick_knob.position = knob_center - JOYSTICK_KNOB_SIZE * 0.5
	joystick_knob.size = JOYSTICK_KNOB_SIZE


func _reset_joystick() -> void:
	joystick_touch_index = -1
	joystick_active = false
	joystick_vector = Vector2.ZERO
	_update_knob_position()
	_release_joystick_actions()


func _apply_joystick_actions() -> void:
	var power_mode := Input.is_action_pressed("hud_menu")
	if power_mode != joystick_was_power_mode:
		_release_joystick_actions()
		joystick_was_power_mode = power_mode

	if not joystick_active or joystick_vector.length() < JOYSTICK_DEADZONE:
		_release_joystick_actions()
		return

	if power_mode:
		_release_movement_actions()
		_press_direction_actions("hud_select_left", "hud_select_right", "hud_select_up", "hud_select_down")
	else:
		_release_power_select_actions()
		_press_direction_actions("left", "right", "", "crouch")


func _press_direction_actions(left_action: String, right_action: String, up_action: String, down_action: String) -> void:
	if absf(joystick_vector.x) >= JOYSTICK_DEADZONE:
		_set_action_strength(left_action, -joystick_vector.x if joystick_vector.x < 0.0 else 0.0)
		_set_action_strength(right_action, joystick_vector.x if joystick_vector.x > 0.0 else 0.0)
	else:
		_release_action(left_action)
		_release_action(right_action)

	if absf(joystick_vector.y) >= JOYSTICK_DEADZONE:
		_set_action_strength(up_action, -joystick_vector.y if joystick_vector.y < 0.0 else 0.0)
		_set_action_strength(down_action, joystick_vector.y if joystick_vector.y > 0.0 else 0.0)
	else:
		_release_action(up_action)
		_release_action(down_action)


func _set_action_strength(action_name: String, strength: float) -> void:
	if action_name == "":
		return
	if strength > 0.0:
		Input.action_press(action_name, clampf(strength, 0.0, 1.0))
		virtual_pressed[action_name] = true
	else:
		_release_action(action_name)


func _release_action(action_name: String) -> void:
	if action_name != "" and virtual_pressed.has(action_name):
		Input.action_release(action_name)
		virtual_pressed.erase(action_name)


func _release_movement_actions() -> void:
	for action_name in ["left", "right", "crouch"]:
		_release_action(action_name)


func _release_power_select_actions() -> void:
	for action_name in ["hud_select_up", "hud_select_down", "hud_select_left", "hud_select_right"]:
		_release_action(action_name)


func _release_joystick_actions() -> void:
	_release_movement_actions()
	_release_power_select_actions()


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
