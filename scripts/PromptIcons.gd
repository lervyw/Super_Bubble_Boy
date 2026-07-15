class_name PromptIcons
extends RefCounted

const PROMPT_ROOT := "res://assets/input_prompts/mr_breakfast/png/"


static func for_action(action_name: StringName) -> Texture2D:
	if not InputMap.has_action(action_name):
		return null

	var wants_controller := ControllerMapper.get_last_input_source() == ControllerMapper.InputSource.CONTROLLER
	var fallback: InputEvent = null
	for event in InputMap.action_get_events(action_name):
		if fallback == null:
			fallback = event
		if wants_controller and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			return for_event(event, ControllerMapper.get_primary_type())
		if not wants_controller and event is InputEventKey:
			return for_event(event, ControllerMapper.ControllerType.UNKNOWN)

	return for_event(fallback, ControllerMapper.get_primary_type())


static func for_event(event: InputEvent, controller_type: int) -> Texture2D:
	if event is InputEventKey:
		return _keyboard_icon(event)
	if event is InputEventJoypadButton:
		return _gamepad_button_icon(event.button_index, controller_type)
	if event is InputEventJoypadMotion:
		return _gamepad_axis_icon(event.axis, event.axis_value, controller_type)
	return null


static func _keyboard_icon(event: InputEventKey) -> Texture2D:
	var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var key_name := OS.get_keycode_string(keycode).to_lower()
	var aliases := {
		"escape": "escape", "control": "control", "capslock": "caps_lock",
		"backspace": "backspace", "pageup": "page_up", "pagedown": "page_down",
		"enter": "return", "kp enter": "return",
		"left": "arrow_left", "right": "arrow_right", "up": "arrow_up", "down": "arrow_down",
	}
	var file_stem: String = aliases.get(key_name, key_name)
	return _load_prompt("%s_light.png" % file_stem)


static func _gamepad_button_icon(button_index: int, controller_type: int) -> Texture2D:
	if controller_type == ControllerMapper.ControllerType.PLAYSTATION:
		var playstation_files := {
			0: "ps5_cross_color_light.png", 1: "ps5_circle_color_light.png",
			2: "ps5_square_color_light.png", 3: "ps5_triangle_color_light.png",
			4: "ps5_create_light.png", 5: "ps5_touchpad_light.png",
			6: "ps5_options_light.png", 7: "stick_press_light.png",
			8: "stick_press_light.png", 9: "ps5_l2_light.png",
			10: "ps5_r2_light.png", 11: "dpad_n_light.png",
			12: "dpad_s_light.png", 13: "dpad_w_light.png",
			14: "dpad_e_light.png", 15: "ps5_touchpad_tap_light.png",
		}
		return _load_prompt(playstation_files.get(button_index, "ps5_cross_color_light.png"))

	var xbox_files := {
		0: "xbox_a_color_light.png", 1: "xbox_b_color_light.png",
		2: "xbox_x_color_light.png", 3: "xbox_y_color_light.png",
		4: "xbox_view_light.png", 5: "xbox_share_light.png",
		6: "xbox_menu_light.png", 7: "stick_press_light.png",
		8: "stick_press_light.png", 9: "xbox_lb_light.png",
		10: "xbox_rb_light.png", 11: "dpad_n_light.png",
		12: "dpad_s_light.png", 13: "dpad_w_light.png",
		14: "dpad_e_light.png", 15: "xbox_share_light.png",
	}
	return _load_prompt(xbox_files.get(button_index, "xbox_a_color_light.png"))


static func _gamepad_axis_icon(axis: int, axis_value: float, controller_type: int) -> Texture2D:
	if axis == 4:
		return _load_prompt("ps5_l1_light.png" if controller_type == ControllerMapper.ControllerType.PLAYSTATION else "xbox_lt_light.png")
	if axis == 5:
		return _load_prompt("ps5_r1_light.png" if controller_type == ControllerMapper.ControllerType.PLAYSTATION else "xbox_rt_light.png")

	var direction := "right"
	if axis == 0 or axis == 2:
		direction = "left" if axis_value < 0.0 else "right"
	elif axis == 1 or axis == 3:
		direction = "up" if axis_value < 0.0 else "down"
	return _load_prompt("stick_%s_light.png" % direction)


static func _load_prompt(file_name: String) -> Texture2D:
	var path := PROMPT_ROOT + file_name
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
