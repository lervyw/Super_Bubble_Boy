extends CanvasLayer

const BUTTON_SIZE := Vector2(36, 36)
const SMALL_BUTTON_SIZE := Vector2(30, 30)
const PAUSE_BUTTON_SIZE := Vector2(44, 24)
const EDGE_PADDING := 12.0
const BOTTOM_PADDING := 12.0
const BUTTON_GAP := 5.0
const JOYSTICK_DEADZONE := 0.24

var controls: Array[Dictionary] = [
	{"name": "Pause", "action": "pause_menu", "label": "PAUSE", "group": "top_right", "pos": Vector2(0, 0), "size": PAUSE_BUTTON_SIZE},
	{"name": "HudMenu", "action": "hud_menu", "label": "A", "group": "right_pad", "pos": Vector2(41, 0), "size": BUTTON_SIZE},
	{"name": "Attack", "action": "attack", "label": "X", "group": "right_pad", "pos": Vector2(0, 41), "size": BUTTON_SIZE},
	{"name": "Dash", "action": "dash", "label": "B", "group": "right_pad", "pos": Vector2(82, 41), "size": BUTTON_SIZE},
	{"name": "Jump", "action": "jump", "label": "Y", "group": "right_pad", "pos": Vector2(41, 82), "size": BUTTON_SIZE},
	{"name": "Normal", "action": "normal", "label": "N", "group": "right_pad", "pos": Vector2(6, -34), "size": SMALL_BUTTON_SIZE},
	{"name": "Bubble", "action": "forma1", "label": "BOL", "group": "right_pad", "pos": Vector2(41, -34), "size": SMALL_BUTTON_SIZE},
	{"name": "Super", "action": "forma2", "label": "SUP", "group": "right_pad", "pos": Vector2(76, -34), "size": SMALL_BUTTON_SIZE},
]

var joystick_actions := ["left", "right", "crouch", "swim_up", "hud_select_up", "hud_select_down", "hud_select_left", "hud_select_right"]
var button_nodes: Dictionary = {}
var label_nodes: Dictionary = {}
@onready var joystick: VirtualJoystick = $VirtualJoystick
var joystick_was_power_mode := false
var controls_hidden_for_pause := false
var virtual_pressed: Dictionary = {}


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_actions()
	_setup_scene_buttons()


func _process(_delta: float) -> void:
	_update_pause_visibility()
	if controls_hidden_for_pause:
		return

	_apply_joystick_actions()


func _exit_tree() -> void:
	_release_joystick_actions()


func _ensure_actions() -> void:
	for item in controls:
		var action_name: String = item["action"]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	for action_name in joystick_actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func _setup_scene_buttons() -> void:
	for item in controls:
		var button_name: String = item["name"]
		var action_name: String = item["action"]
		var button := find_child(button_name, true, false) as TouchScreenButton
		var label := find_child("%sLabel" % button_name, true, false) as Label
		if not button or not label:
			push_warning("Controle mobile ausente na cena: %s" % button_name)
			continue
		button.action = action_name
		button.texture_normal = _make_button_texture(item["size"], Color(0.04, 0.10, 0.16, 0.48), Color(0.62, 0.86, 1.0, 0.9))
		button.texture_pressed = _make_button_texture(item["size"], Color(0.15, 0.42, 0.66, 0.72), Color(0.94, 1.0, 1.0, 1.0))
		button_nodes[button_name] = button
		label_nodes[button_name] = label


func _update_pause_visibility() -> void:
	var should_hide := get_tree().paused
	if controls_hidden_for_pause == should_hide:
		return

	controls_hidden_for_pause = should_hide
	if controls_hidden_for_pause:
		if joystick:
			joystick.reset_joystick()
		_release_joystick_actions()
	else:
		joystick_was_power_mode = false

	for child in get_children():
		if child is CanvasItem:
			child.visible = not controls_hidden_for_pause


func _apply_joystick_actions() -> void:
	if not joystick:
		return
	var power_mode := Input.is_action_pressed("hud_menu")
	if power_mode != joystick_was_power_mode:
		_release_joystick_actions()
		joystick.reset_joystick()
		joystick_was_power_mode = power_mode

	if not joystick.is_pressed or joystick.output.length() < JOYSTICK_DEADZONE:
		_release_joystick_actions()
		return

	if power_mode:
		_release_movement_actions()
		_press_direction_actions("hud_select_left", "hud_select_right", "hud_select_up", "hud_select_down")
	else:
		_release_power_select_actions()
		_press_direction_actions("left", "right", "swim_up", "crouch")


func _press_direction_actions(left_action: String, right_action: String, up_action: String, down_action: String) -> void:
	var direction := joystick.output
	if absf(direction.x) >= JOYSTICK_DEADZONE:
		_set_action_strength(left_action, -direction.x if direction.x < 0.0 else 0.0)
		_set_action_strength(right_action, direction.x if direction.x > 0.0 else 0.0)
	else:
		_release_action(left_action)
		_release_action(right_action)

	if absf(direction.y) >= JOYSTICK_DEADZONE:
		_set_action_strength(up_action, -direction.y if direction.y < 0.0 else 0.0)
		_set_action_strength(down_action, direction.y if direction.y > 0.0 else 0.0)
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
	for action_name in ["left", "right", "crouch", "swim_up"]:
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
