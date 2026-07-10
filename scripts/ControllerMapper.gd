extends Node

enum ControllerType { UNKNOWN, XBOX, PLAYSTATION, NINTENDO_SWITCH, GENERIC }
enum InputSource { KEYBOARD, CONTROLLER }

signal controller_connected(device_id: int, type: ControllerType)
signal controller_disconnected(device_id: int)
signal input_source_changed(source: InputSource, controller_type: ControllerType)

var connected_controllers: Dictionary = {}

var _primary_device: int = -1
var _last_input_source: InputSource = InputSource.KEYBOARD


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_detect_connected_controllers()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_last_input_source(InputSource.KEYBOARD)
	elif event is InputEventJoypadButton and event.pressed:
		_activate_controller_input(event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.55:
		_activate_controller_input(event.device)


func _activate_controller_input(device_id: int) -> void:
	var previous_type := get_primary_type()
	if device_id >= 0:
		_primary_device = device_id
	var current_type := get_primary_type()
	ConfigManager.apply_controller_profile(current_type)
	if _last_input_source == InputSource.CONTROLLER:
		if previous_type != current_type:
			input_source_changed.emit(InputSource.CONTROLLER, current_type)
		return
	_set_last_input_source(InputSource.CONTROLLER)


func _set_last_input_source(source: InputSource) -> void:
	if _last_input_source == source:
		return
	_last_input_source = source
	if source == InputSource.KEYBOARD:
		ConfigManager.set_keyboard_profile_active()
	else:
		ConfigManager.apply_controller_profile(get_primary_type())
	input_source_changed.emit(source, get_primary_type())


func get_last_input_source() -> InputSource:
	return _last_input_source


func _detect_connected_controllers() -> void:
	for device_id in Input.get_connected_joypads():
		_register_controller(device_id)


func _register_controller(device_id: int) -> void:
	var ctype := _identify_controller(device_id)
	connected_controllers[device_id] = ctype
	print("Controle detectado [%d]: %s (%s)" % [device_id, Input.get_joy_name(device_id), _type_name(ctype)])
	if _primary_device < 0:
		_primary_device = device_id
	ConfigManager.apply_controller_profile(ctype)
	controller_connected.emit(device_id, ctype)


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		_register_controller(device_id)
	else:
		connected_controllers.erase(device_id)
		if _primary_device == device_id:
			_primary_device = connected_controllers.keys()[0] if not connected_controllers.is_empty() else -1
			if _primary_device >= 0:
				ConfigManager.apply_controller_profile(get_primary_type())
				input_source_changed.emit(_last_input_source, get_primary_type())
		print("Controle desconectado [%d]" % device_id)
		controller_disconnected.emit(device_id)


func _identify_controller(device_id: int) -> ControllerType:
	var controller_name := Input.get_joy_name(device_id).to_lower()
	var guid := Input.get_joy_guid(device_id).to_lower()

	if "xbox" in controller_name or "x-box" in controller_name or "xinput" in controller_name:
		return ControllerType.XBOX
	if "playstation" in controller_name or "ps4" in controller_name or "ps5" in controller_name or "dualsense" in controller_name or "dualshock" in controller_name or "ps" in controller_name:
		return ControllerType.PLAYSTATION
	if "nintendo" in controller_name or "switch" in controller_name or "pro controller" in controller_name or "joy-con" in controller_name:
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
	var ctype := _get_type_for_device(device_id)

	match axis:
		0: return "Analogico Esquerdo " + ("Direita" if axis_value >= 0.0 else "Esquerda")
		1: return "Analogico Esquerdo " + ("Baixo" if axis_value >= 0.0 else "Cima")
		2: return "Analogico Direito " + ("Direita" if axis_value >= 0.0 else "Esquerda")
		3: return "Analogico Direito " + ("Baixo" if axis_value >= 0.0 else "Cima")
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
		_: return "Eixo %d" % axis


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
