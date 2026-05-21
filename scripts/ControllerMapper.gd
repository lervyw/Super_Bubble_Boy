extends Node

enum ControllerType { UNKNOWN, XBOX, PLAYSTATION, NINTENDO_SWITCH, GENERIC }

signal controller_connected(device_id: int, type: ControllerType)
signal controller_disconnected(device_id: int)

const JOYPAD_TRIGGER_AXES: Array[int] = [4, 5]
const JOYPAD_TRIGGER_DEADZONE: float = 0.20
const JOYPAD_DEADZONE: float = 0.5

var connected_controllers: Dictionary = {}

var _primary_device: int = -1


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_detect_connected_controllers()


func _detect_connected_controllers() -> void:
	for device_id in Input.get_connected_joypads():
		_register_controller(device_id)


func _register_controller(device_id: int) -> void:
	var ctype := _identify_controller(device_id)
	connected_controllers[device_id] = ctype
	print("Controle detectado [%d]: %s (%s)" % [device_id, Input.get_joy_name(device_id), _type_name(ctype)])
	_ensure_all_input_actions(device_id)
	if _primary_device < 0:
		_primary_device = device_id
	controller_connected.emit(device_id, ctype)


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		_register_controller(device_id)
	else:
		connected_controllers.erase(device_id)
		if _primary_device == device_id:
			_primary_device = connected_controllers.keys()[0] if not connected_controllers.is_empty() else -1
		print("Controle desconectado [%d]" % device_id)
		controller_disconnected.emit(device_id)


func _identify_controller(device_id: int) -> ControllerType:
	var name := Input.get_joy_name(device_id).to_lower()
	var guid := Input.get_joy_guid(device_id).to_lower()

	if "xbox" in name or "x-box" in name or "xinput" in name:
		return ControllerType.XBOX
	if "playstation" in name or "ps4" in name or "ps5" in name or "dualsense" in name or "dualshock" in name or "ps" in name:
		return ControllerType.PLAYSTATION
	if "nintendo" in name or "switch" in name or "pro controller" in name or "joy-con" in name:
		return ControllerType.NINTENDO_SWITCH
	if "xbox" in guid:
		return ControllerType.XBOX
	if "ps" in guid or "playstation" in guid:
		return ControllerType.PLAYSTATION
	if "nintendo" in guid or "switch" in guid:
		return ControllerType.NINTENDO_SWITCH
	if "0300" in guid or "xinput" in guid:
		return ControllerType.XBOX

	return ControllerType.GENERIC


func _ensure_all_input_actions(_device_id: int) -> void:
	_ensure_action("ui_accept")
	_ensure_action("ui_select")
	_ensure_action("ui_cancel")
	_ensure_action("ui_up")
	_ensure_action("ui_down")
	_ensure_action("ui_left")
	_ensure_action("ui_right")
	_ensure_action("pause_menu")
	_ensure_action("hud_select_up")
	_ensure_action("hud_select_down")
	_ensure_action("hud_select_left")
	_ensure_action("hud_select_right")
	_ensure_action("swim_up")

	_add_joy_button("jump", 0)
	_add_joy_button("ui_accept", 0)
	_add_joy_button("ui_select", 0)
	_add_joy_button("normal", 1)
	_add_joy_button("ui_cancel", 1)
	_add_joy_button("attack", 2)
	_add_joy_button("dash", 3)
	_add_joy_button("ui_start", 6)
	_add_joy_button("pause_menu", 6)
	_add_joy_button("forma1", 10)
	_add_joy_button("forma2", 9)
	_add_joy_button("ui_up", 11)
	_add_joy_button("ui_down", 12)
	_add_joy_button("crouch", 12)
	_add_joy_button("ui_left", 13)
	_add_joy_button("left", 13)
	_add_joy_button("ui_right", 14)
	_add_joy_button("right", 14)

	_add_joy_axis("attack_special", 5, 1.0)
	_add_joy_axis("defend", 4, 1.0)
	_add_joy_axis("ui_left", 0, -1.0)
	_add_joy_axis("ui_right", 0, 1.0)
	_add_joy_axis("ui_up", 1, -1.0)
	_add_joy_axis("ui_down", 1, 1.0)
	_add_joy_axis("left", 0, -1.0)
	_add_joy_axis("right", 0, 1.0)
	_add_joy_axis("crouch", 1, 1.0)


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, JOYPAD_DEADZONE)


func _add_joy_button(action_name: StringName, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		return

	if _is_button_in_any_action(button_index):
		return

	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and event.button_index == button_index:
			return
	var joy_event := InputEventJoypadButton.new()
	joy_event.device = -1
	joy_event.button_index = button_index
	InputMap.action_add_event(action_name, joy_event)


func _add_joy_axis(action_name: StringName, axis: int, axis_value: float) -> void:
	if not InputMap.has_action(action_name):
		return

	if _is_axis_in_any_action(axis, axis_value):
		return

	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion and event.axis == axis and sign(event.axis_value) == sign(axis_value):
			return
	var joy_event := InputEventJoypadMotion.new()
	joy_event.device = -1
	joy_event.axis = axis
	joy_event.axis_value = axis_value
	InputMap.action_add_event(action_name, joy_event)
	if axis in JOYPAD_TRIGGER_AXES:
		InputMap.action_set_deadzone(action_name, JOYPAD_TRIGGER_DEADZONE)


func _is_button_in_any_action(button_index: int) -> bool:
	for action in InputMap.get_actions():
		if action in ["ui_accept", "ui_select", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right", "ui_start", "ui_text_newline"]:
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == button_index:
				return true
	return false


func _is_axis_in_any_action(axis: int, axis_value: float) -> bool:
	for action in InputMap.get_actions():
		if action in ["ui_accept", "ui_select", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right", "ui_start", "ui_text_newline"]:
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion and event.axis == axis and sign(event.axis_value) == sign(axis_value):
				return true
	return false


func get_primary_type() -> ControllerType:
	if _primary_device < 0:
		return ControllerType.UNKNOWN
	return connected_controllers.get(_primary_device, ControllerType.UNKNOWN)


func has_controller() -> bool:
	return not connected_controllers.is_empty()


func get_button_name(button_index: int, device_id: int = -1) -> String:
	var ctype := _get_type_for_device(device_id)
	match ctype:
		ControllerType.PLAYSTATION:
			match button_index:
				0: return "Cross"
				1: return "Circulo"
				2: return "Quadrado"
				3: return "Triangulo"
				4: return "Touchpad / Select"
				5: return "PS"
				6: return "Options"
				7: return "L3"
				8: return "R3"
				9: return "L1"
				10: return "R1"
				11: return "D-Pad Cima"
				12: return "D-Pad Baixo"
				13: return "D-Pad Esquerda"
				14: return "D-Pad Direita"
				15: return "Touchpad Click"
				_: return "Botao %d" % button_index

		ControllerType.NINTENDO_SWITCH:
			match button_index:
				0: return "B"
				1: return "A"
				2: return "Y"
				3: return "X"
				4: return "-"
				5: return "Home"
				6: return "+"
				7: return "L3"
				8: return "R3"
				9: return "L"
				10: return "R"
				11: return "D-Pad Cima"
				12: return "D-Pad Baixo"
				13: return "D-Pad Esquerda"
				14: return "D-Pad Direita"
				15: return "Capture"
				_: return "Botao %d" % button_index

		_: # Xbox / Generic
			match button_index:
				0: return "A"
				1: return "B"
				2: return "X"
				3: return "Y"
				4: return "Back"
				5: return "Home"
				6: return "Start"
				7: return "L3"
				8: return "R3"
				9: return "LB"
				10: return "RB"
				11: return "D-Pad Cima"
				12: return "D-Pad Baixo"
				13: return "D-Pad Esquerda"
				14: return "D-Pad Direita"
				15: return "Share"
				_: return "Botao %d" % button_index


func get_axis_name(axis: int, axis_value: float, device_id: int = -1) -> String:
	var direction := "+" if axis_value >= 0.0 else "-"
	var ctype := _get_type_for_device(device_id)

	match axis:
		0: return "Analogico Esquerdo %sX" % direction
		1: return "Analogico Esquerdo %sY" % direction
		2: return "Analogico Direito %sX" % direction
		3: return "Analogico Direito %sY" % direction
		4:
			match ctype:
				ControllerType.PLAYSTATION: return "L2"
				ControllerType.NINTENDO_SWITCH: return "ZL"
				_: return "LT"
		5:
			match ctype:
				ControllerType.PLAYSTATION: return "R2"
				ControllerType.NINTENDO_SWITCH: return "ZR"
				_: return "RT"
		_: return "Eixo %d%s" % [axis, direction]


func _get_type_for_device(device_id: int) -> ControllerType:
	if device_id < 0:
		return get_primary_type()
	return connected_controllers.get(device_id, get_primary_type())


func _type_name(ctype: ControllerType) -> String:
	match ctype:
		ControllerType.XBOX: return "Xbox"
		ControllerType.PLAYSTATION: return "PlayStation"
		ControllerType.NINTENDO_SWITCH: return "Nintendo Switch"
		ControllerType.GENERIC: return "Generico"
		_: return "Desconhecido"
