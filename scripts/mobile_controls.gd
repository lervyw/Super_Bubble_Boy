extends CanvasLayer

const BUTTON_SIZE := Vector2(36, 36)
const SMALL_BUTTON_SIZE := Vector2(30, 30)
const PAUSE_BUTTON_SIZE := Vector2(44, 24)
const EDGE_PADDING := 12.0
const BOTTOM_PADDING := 12.0
const BUTTON_GAP := 5.0
const JOYSTICK_DEADZONE := 0.24
const MENU_JOYSTICK_DEADZONE := 0.5
const MENU_NAV_COOLDOWN := 0.2
const TOUCH_BUTTON_NORMAL := preload("res://assets/input_prompts/mr_breakfast/png/button_dark.png")
const TOUCH_BUTTON_PRESSED := preload("res://assets/input_prompts/mr_breakfast/png/button_light.png")

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

const GAMEPLAY_BUTTONS: Array[String] = [
	"Pause", "Attack", "HudMenu", "Dash", "Jump", "Normal", "Bubble", "Super"
]

const MENU_ACTIONS: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]

var joystick_actions := ["left", "right", "crouch", "swim_up", "hud_select_up", "hud_select_down", "hud_select_left", "hud_select_right"]
var button_nodes: Dictionary = {}
var label_nodes: Dictionary = {}
@onready var joystick = $VirtualJoystick
var joystick_was_power_mode := false
var controls_hidden_for_pause := false
var virtual_pressed: Dictionary = {}
var menu_mode := false
var _menu_nav_timer := 0.0
var _menu_last_direction := Vector2.ZERO
var _menu_confirm_btn: TouchScreenButton
var _menu_confirm_label: Label
var _menu_back_btn: TouchScreenButton
var _menu_back_label: Label


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_actions()
	_setup_scene_buttons()
	_setup_menu_buttons()


func _process(delta: float) -> void:
	if menu_mode:
		_update_menu_mode(delta)
		return

	_update_pause_visibility()
	if controls_hidden_for_pause:
		return

	_apply_joystick_actions()


func _exit_tree() -> void:
	_release_joystick_actions()


func set_menu_mode(enabled: bool) -> void:
	menu_mode = enabled
	_release_joystick_actions()
	if joystick:
		joystick.reset_joystick()
	_menu_last_direction = Vector2.ZERO
	_menu_nav_timer = 0.0
	_apply_menu_button_visibility()


func _apply_menu_button_visibility() -> void:
	for child in get_children():
		if child is CanvasItem and child.name not in ["MenuControls", "VirtualJoystick"]:
			child.visible = not menu_mode

	if joystick:
		joystick.visible = menu_mode

	if _menu_confirm_btn:
		_menu_confirm_btn.visible = menu_mode
		_menu_confirm_label.visible = menu_mode
	if _menu_back_btn:
		_menu_back_btn.visible = menu_mode
		_menu_back_label.visible = menu_mode


func _setup_menu_buttons() -> void:
	var menu_controls := find_child("MenuControls", true, false) as Control
	if not menu_controls:
		return

	_menu_confirm_btn = find_child("MenuOK", true, false) as TouchScreenButton
	_menu_confirm_label = find_child("MenuOKLabel", true, false) as Label
	_menu_back_btn = find_child("MenuVoltar", true, false) as TouchScreenButton
	_menu_back_label = find_child("MenuVoltarLabel", true, false) as Label

	if _menu_confirm_btn:
		_menu_confirm_btn.action = "ui_accept"
		_menu_confirm_btn.texture_normal = TOUCH_BUTTON_NORMAL
		_menu_confirm_btn.texture_pressed = TOUCH_BUTTON_PRESSED
		_menu_confirm_btn.scale = Vector2(1.1, 0.7)
		_menu_confirm_btn.visible = false
	if _menu_confirm_label:
		_menu_confirm_label.text = "OK"
		_menu_confirm_label.visible = false

	if _menu_back_btn:
		_menu_back_btn.action = "ui_cancel"
		_menu_back_btn.texture_normal = TOUCH_BUTTON_NORMAL
		_menu_back_btn.texture_pressed = TOUCH_BUTTON_PRESSED
		_menu_back_btn.scale = Vector2(1.3, 0.7)
		_menu_back_btn.visible = false
	if _menu_back_label:
		_menu_back_label.text = "VOLTAR"
		_menu_back_label.visible = false


func _update_menu_mode(delta: float) -> void:
	_menu_nav_timer = maxf(_menu_nav_timer - delta, 0.0)

	if not joystick:
		return

	if not joystick.is_pressed or joystick.output.length() < MENU_JOYSTICK_DEADZONE:
		_menu_last_direction = Vector2.ZERO
		_release_menu_actions()
		return

	var direction: Vector2 = joystick.output
	var snapped := Vector2.ZERO
	if absf(direction.x) >= MENU_JOYSTICK_DEADZONE:
		snapped.x = 1.0 if direction.x > 0.0 else -1.0
	if absf(direction.y) >= MENU_JOYSTICK_DEADZONE:
		snapped.y = 1.0 if direction.y > 0.0 else -1.0

	if snapped == _menu_last_direction or _menu_nav_timer > 0.0:
		return

	_release_menu_actions()

	if snapped.y < 0.0:
		Input.action_press("ui_up")
		_menu_nav_timer = MENU_NAV_COOLDOWN
	elif snapped.y > 0.0:
		Input.action_press("ui_down")
		_menu_nav_timer = MENU_NAV_COOLDOWN

	_menu_last_direction = snapped
	_call_deferred_menu_release(snapped)


func _call_deferred_menu_release(direction: Vector2) -> void:
	var action := ""
	if direction.y < 0.0:
		action = "ui_up"
	elif direction.y > 0.0:
		action = "ui_down"
	elif direction.x < 0.0:
		action = "ui_left"
	elif direction.x > 0.0:
		action = "ui_right"
	if action != "":
		await get_tree().create_timer(0.05).timeout
		Input.action_release(action)


func _release_menu_actions() -> void:
	for action_name in MENU_ACTIONS:
		if virtual_pressed.has(action_name):
			Input.action_release(action_name)
			virtual_pressed.erase(action_name)


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
		var button_size: Vector2 = item["size"]
		var button := find_child(button_name, true, false) as TouchScreenButton
		var label := find_child("%sLabel" % button_name, true, false) as Label
		if not button or not label:
			continue
		button.action = action_name
		button.texture_normal = _make_button_texture(button_size, Color(0.04, 0.10, 0.16, 0.48), Color(0.62, 0.86, 1.0, 0.9))
		button.texture_pressed = _make_button_texture(button_size, Color(0.15, 0.42, 0.66, 0.72), Color(0.94, 1.0, 1.0, 1.0))
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
	var direction: Vector2 = joystick.output
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
	_release_menu_actions()


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
