extends Node

const CONFIG_PATH := "user://config.json"

# Valores padrão quando não existe config.json
var settings := {
	"volume_master": 0.0,
	"volume_music": 0.0,
	"volume_sfx": 0.0,

	"inputs": {
		# Será preenchido quando o usuário configurar algo
	}
}

func _ready():
	print("🔧 ConfigManager iniciado.")
	_load()
	_apply_settings()


# ============================================================
#                         VOLUME
# ============================================================

func set_volume(bus_name: String, value_db: float):
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, value_db)

	settings["volume_" + bus_name] = value_db
	_save()

func get_volume(bus_name: String) -> float:
	return settings.get("volume_" + bus_name, 0.0)


# ============================================================
#                         INPUTS
# ============================================================

func rebind_action(action: String, event: InputEvent):
	# Apaga binds antigos
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

	# Salva o evento como texto serializável
	var event_text := _event_to_string(event)
	settings["inputs"][action] = event_text

	_save()


func apply_loaded_inputs():
	for action in settings["inputs"].keys():
		var ev_str = settings["inputs"][action]
		var event = _string_to_event(ev_str)
		if event:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)


# ============================================================
#                EVENTO → STRING  (SALVAR)
# ============================================================

func _event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		return "Key:%s" % event.physical_keycode

	if event is InputEventJoypadButton:
		return "JoyButton:%s" % event.button_index

	return "Unknown"


# ============================================================
#                STRING → EVENTO  (CARREGAR)
# ============================================================

func _string_to_event(str: String) -> InputEvent:
	if str.begins_with("Key:"):
		var code = str.split(":")[1].to_int()
		var ev = InputEventKey.new()
		ev.physical_keycode = code
		return ev

	if str.begins_with("JoyButton:"):
		var btn = str.split(":")[1].to_int()
		var ev = InputEventJoypadButton.new()
		ev.button_index = btn
		return ev

	return null


# ============================================================
#               SALVAR / CARREGAR CONFIG
# ============================================================

func _save():
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings, "\t"))
	print("💾 Config salvo em:", CONFIG_PATH)


func _load():
	if not FileAccess.file_exists(CONFIG_PATH):
		print("⚠ Nenhum arquivo de config encontrado. Criando config padrão!")
		_save()
		return

	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var parse = JSON.parse_string(file.get_as_text())

	if typeof(parse) == TYPE_DICTIONARY:
		settings = parse
		apply_loaded_inputs()
		print("📂 Config carregado com sucesso.")

	else:
		print("❌ Erro ao carregar config.json — recriando arquivo!")
		_save()


func _apply_settings():
	set_volume("master", settings["volume_master"])
	set_volume("music", settings["volume_music"])
	set_volume("sfx", settings["volume_sfx"])
