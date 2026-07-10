class_name PromptIcons
extends RefCounted

const KEYBOARD_LETTERS := preload("res://assets/input_prompts/source/keyboard-letters-symbols.png")
const KEYBOARD_EXTRAS := preload("res://assets/input_prompts/source/keyboard-extras.png")
const XBOX := preload("res://assets/input_prompts/source/gdb-xbox-2.png")
const PLAYSTATION := preload("res://assets/input_prompts/source/gdb-playstation-3.png")

const CELL := 16


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
	var key_name := OS.get_keycode_string(keycode).to_upper()

	if key_name.length() == 1:
		var character := key_name.unicode_at(0)
		if character >= 65 and character <= 90:
			var index := character - 65
			return _atlas(KEYBOARD_LETTERS, Rect2((index % 8) * CELL, (2 + floori(index / 8.0)) * CELL, CELL, CELL))
		if character >= 48 and character <= 57:
			var digit_index := 9 if character == 48 else character - 49
			return _atlas(KEYBOARD_LETTERS, Rect2((digit_index % 8) * CELL, (12 + floori(digit_index / 8.0)) * CELL, CELL, CELL))

	var extras := {
		"TAB": Vector2i(0, 0), "ESC": Vector2i(1, 0), "ESCAPE": Vector2i(1, 0),
		"PRINT": Vector2i(2, 0), "BACKSPACE": Vector2i(3, 0),
		"SHIFT": Vector2i(0, 1), "CAPSLOCK": Vector2i(1, 1), "ENTER": Vector2i(3, 1),
		"CTRL": Vector2i(0, 2), "CONTROL": Vector2i(0, 2), "ALT": Vector2i(1, 2),
		"SPACE": Vector2i(2, 2), "INSERT": Vector2i(3, 2), "DELETE": Vector2i(0, 3),
		"END": Vector2i(1, 3), "HOME": Vector2i(2, 3), "PAUSE": Vector2i(3, 3),
	}
	if extras.has(key_name):
		var cell: Vector2i = extras[key_name]
		return _atlas(KEYBOARD_EXTRAS, Rect2(cell * CELL, Vector2i(CELL, CELL)))

	var arrows := {"UP": Vector2i(0, 0), "RIGHT": Vector2i(1, 0), "DOWN": Vector2i(2, 0), "LEFT": Vector2i(3, 0)}
	if arrows.has(key_name):
		var cell: Vector2i = arrows[key_name]
		return _atlas(KEYBOARD_LETTERS, Rect2(cell * CELL, Vector2i(CELL, CELL)))
	return null


static func _gamepad_button_icon(button_index: int, controller_type: int) -> Texture2D:
	if controller_type == ControllerMapper.ControllerType.PLAYSTATION:
		var ps_regions := {
			0: Rect2(16, 192, 16, 16), 1: Rect2(16, 176, 16, 16),
			2: Rect2(16, 208, 16, 16), 3: Rect2(16, 160, 16, 16),
			4: Rect2(16, 240, 16, 16), 5: Rect2(16, 256, 16, 16),
			6: Rect2(16, 240, 16, 16), 9: Rect2(120, 104, 32, 16),
			10: Rect2(120, 120, 32, 16), 11: Rect2(16, 64, 16, 16),
			12: Rect2(16, 96, 16, 16), 13: Rect2(16, 112, 16, 16),
			14: Rect2(16, 80, 16, 16),
		}
		return _atlas(PLAYSTATION, ps_regions.get(button_index, Rect2(16, 192, 16, 16)))

	var xbox_regions := {
		0: Rect2(16, 48, 16, 16), 1: Rect2(16, 80, 16, 16),
		2: Rect2(16, 32, 16, 16), 3: Rect2(16, 64, 16, 16),
		4: Rect2(16, 96, 16, 16), 5: Rect2(16, 112, 16, 16),
		6: Rect2(16, 112, 16, 16), 9: Rect2(112, 528, 32, 16),
		10: Rect2(112, 544, 32, 16), 11: Rect2(16, 480, 32, 32),
		12: Rect2(16, 480, 32, 32), 13: Rect2(16, 480, 32, 32),
		14: Rect2(16, 480, 32, 32),
	}
	return _atlas(XBOX, xbox_regions.get(button_index, Rect2(16, 64, 16, 16)))


static func _gamepad_axis_icon(axis: int, axis_value: float, controller_type: int) -> Texture2D:
	if axis == 4 or axis == 5:
		if controller_type == ControllerMapper.ControllerType.PLAYSTATION:
			return _atlas(PLAYSTATION, Rect2(120, 80 if axis == 4 else 96, 32, 16))
		return _atlas(XBOX, Rect2(112, 496 if axis == 4 else 512, 32, 16))
	if controller_type == ControllerMapper.ControllerType.PLAYSTATION and axis >= 0 and axis <= 3:
		return _playstation_stick_direction_icon(axis, axis_value)
	if axis == 2 or axis == 3:
		return _atlas(XBOX, Rect2(280, 32, 16, 16))

	if axis == 0:
		return _gamepad_button_icon(13 if axis_value < 0.0 else 14, controller_type)
	return _gamepad_button_icon(11 if axis_value < 0.0 else 12, controller_type)


static func _playstation_stick_direction_icon(axis: int, axis_value: float) -> Texture2D:
	var region := Rect2()
	match axis:
		0: # Analogico esquerdo: esquerda / direita
			region = Rect2(16 if axis_value < 0.0 else 56, 308, 24, 24)
		1: # Analogico esquerdo: cima / baixo
			region = Rect2(36, 288 if axis_value < 0.0 else 328, 24, 24)
		2: # Analogico direito: esquerda / direita
			region = Rect2(128 if axis_value < 0.0 else 168, 308, 24, 24)
		3: # Analogico direito: cima / baixo
			region = Rect2(148, 288 if axis_value < 0.0 else 328, 24, 24)
		_:
			return null
	return _atlas(PLAYSTATION, region)


static func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas
