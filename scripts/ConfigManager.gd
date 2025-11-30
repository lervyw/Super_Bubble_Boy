extends Node

const CONFIG_PATH := "user://config.json"

var settings := {
	"volume_master": 0.0,
	"volume_music": 0.0,
	"volume_sfx": 0.0,
	"inputs": {}
}

func _ready():
	_load()
	_apply_settings()

# =========================================
#                 VOLUME
# =========================================
func set_volume(bus_name: String, value_db: float):
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, value_db)
	settings["volume_" + bus_name] = value_db
	_save()

func get_volume(bus_name: String) -> float:
	return settings.get("volume_" + bus_name, 0.0)

# =========================================
#                 INPUTS
# =========================================
func rebind_action(action: String, event: InputEvent):
	# Remove ações antigas
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

	# Converter evento para texto serializável
	var text := ""

	if event is InputEventKey:
		text = "Key:%s" % event.physical_keycode

	elif event is InputEventJoypadButton:
		text = "JoyButton:%s" % event.button_index

	settings["inputs"][action] = text
	_save()

func apply_loaded_inputs():
	for action in settings["inputs"].keys():
		var event_text = settings["inputs"][action]
		var event = _string_to_event(event_text)
		if event:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)

# String → InputEvent
func _string_to_event(str: String) -> InputEvent:
	if str.begins_with("Key:"):
		var scancode = str.split(":")[1].to_int()
		var ev = InputEventKey.new()
		ev.physical_keycode = scancode
		return ev

	if str.begins_with("JoyButton:"):
		var button_id = str.split(":")[1].to_int()
		var ev = InputEventJoypadButton.new()
		ev.button_index = button_id
		return ev

	return null

# =========================================
#           SALVAR / CARREGAR
# =========================================
func _save():
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings, "\t"))

func _load():
	if not FileAccess.file_exists(CONFIG_PATH):
		_save()
		return

	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data:
		settings = data
		apply_loaded_inputs()

func _apply_settings():
	set_volume("master", settings["volume_master"])
	set_volume("music", settings["volume_music"])
	set_volume("sfx", settings["volume_sfx"])
