extends Node
# =========================================================
#  CONFIGMANAGER
#  Responsável por:
#  - Salvar e carregar configurações do jogo
#  - Controlar volumes de áudio
#  - Gerenciar rebind de inputs (teclado/controle)
#  Os dados são salvos em um arquivo JSON no user://
# =========================================================

signal rebind_completed(action_name: String)

# Caminho do arquivo de configuração salvo no sistema do jogador
const CONFIG_PATH := "user://config.json"
const INPUT_SCHEMA_VERSION := 2
const JOYPAD_TRIGGER_ACTION_DEADZONE: float = 0.20
const JOYPAD_TRIGGER_AXES: Array[int] = [4, 5]
const MANAGED_INPUT_ACTIONS: Array[StringName] = [
	&"left", &"right", &"swim_up", &"crouch", &"jump", &"normal", &"forma1", &"forma2",
	&"attack", &"defend", &"dash", &"hud_menu", &"hud_select_up", &"hud_select_down",
	&"hud_select_left", &"hud_select_right", &"pause_menu", &"attack_special", &"ultimate_attack",
	&"form_select",
	&"wheel_face_up", &"wheel_face_down", &"wheel_face_left", &"wheel_face_right",
]


# ================================
#     CONFIGURAÇÕES PADRÃO
# ================================
# Valores usados caso o arquivo ainda não exista
var settings := {
	"volume_master": 0.0,
	"volume_music": 0.0,
	"volume_sfx": 0.0,
	"crt_enabled": true,
	"input_schema_version": INPUT_SCHEMA_VERSION,
	"active_input_profile": "keyboard",
	"inputs_keyboard": {},
	"inputs_xbox": {},
	"inputs_playstation": {}
}


func _ready():
	# Inicializa o sistema de configuração
	print("🔧 ConfigManager iniciado.")
	_load()            # Carrega o arquivo de config (ou cria um novo)
	apply_loaded_inputs()
	_apply_settings()  # Aplica volumes e inputs carregados


# ============================================================
#                         VOLUME
# ============================================================

func set_volume(bus_name: String, value_db: float):
	# Busca o índice do bus de áudio pelo nome
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0 and bus_name.to_lower() == "master":
		bus = AudioServer.get_bus_index("Master")

	# Se o bus existir, aplica o volume em decibéis
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, value_db)

	# Salva o valor no dicionário de configurações
	settings["volume_" + bus_name] = value_db
	_save()  # Persiste no arquivo


func get_volume(bus_name: String) -> float:
	# Retorna o volume salvo ou 0.0 se não existir
	return settings.get("volume_" + bus_name, 0.0)


# ============================================================
#            INPUTS (REBIND DE BOTÕES)
# ============================================================

func rebind_action(action: String, event: InputEvent):
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	var is_joypad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var ev := event.duplicate()
	if is_joypad:
		ev.device = -1

	var to_remove: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if is_joypad == (existing is InputEventJoypadButton or existing is InputEventJoypadMotion):
			to_remove.append(existing)

	for e in to_remove:
		InputMap.action_erase_event(action, e)

	InputMap.action_add_event(action, ev)
	_apply_action_deadzone_for_event(action, ev)

	var storage_key := _get_active_controller_storage_key() if is_joypad else "inputs_keyboard"
	settings[storage_key][action] = _event_to_string(ev)
	_save()
	rebind_completed.emit(action)


func apply_loaded_inputs():
	_apply_input_profile("inputs_keyboard", false)
	var controller_profile := settings.get("active_input_profile", "xbox") as String
	if controller_profile == "keyboard":
		controller_profile = "xbox"
	_apply_input_profile("inputs_%s" % controller_profile, true)


func apply_controller_profile(controller_type: int) -> void:
	var profile_name := "playstation" if controller_type == 2 else "xbox"
	if settings.get("active_input_profile", "") == profile_name:
		return
	settings["active_input_profile"] = profile_name
	_apply_input_profile("inputs_%s" % profile_name, true)
	_save()


func set_keyboard_profile_active() -> void:
	if settings.get("active_input_profile", "keyboard") == "keyboard":
		return
	settings["active_input_profile"] = "keyboard"
	_save()


func _apply_input_profile(storage_key: String, is_joypad: bool) -> void:
	if not settings.has(storage_key) or typeof(settings[storage_key]) != TYPE_DICTIONARY:
		return
	_clear_managed_device_events(is_joypad)

	for action in settings[storage_key].keys():
		var event := _string_to_event(settings[storage_key][action])
		if not event:
			continue
		_replace_device_event(action, event, is_joypad)


func _clear_managed_device_events(is_joypad: bool) -> void:
	for action in MANAGED_INPUT_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var to_remove: Array[InputEvent] = []
		for existing in InputMap.action_get_events(action):
			if is_joypad == (existing is InputEventJoypadButton or existing is InputEventJoypadMotion):
				to_remove.append(existing)
		for existing in to_remove:
			InputMap.action_erase_event(action, existing)


func _replace_device_event(action: String, event: InputEvent, is_joypad: bool) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	var to_remove: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if is_joypad == (existing is InputEventJoypadButton or existing is InputEventJoypadMotion):
			to_remove.append(existing)
	for existing in to_remove:
		InputMap.action_erase_event(action, existing)

	InputMap.action_add_event(action, event)
	_apply_action_deadzone_for_event(action, event)


# ============================================================
#          EVENTO → STRING (SALVAR)
# ============================================================

func _event_to_string(event: InputEvent) -> String:
	# Converte um InputEvent em texto para salvar no JSON

	if event is InputEventKey:
		# Ex: "Key:32"
		var keycode: int = event.physical_keycode
		if keycode == 0:
			keycode = event.keycode
		return "Key:%s" % keycode

	if event is InputEventJoypadButton:
		# Ex: "JoyButton:0"
		return "JoyButton:%s" % event.button_index

	if event is InputEventJoypadMotion:
		# Ex: "JoyAxis:5:1.000" (RT/R2). O sinal diferencia esquerda/direita em eixos analógicos.
		return "JoyAxis:%s:%.3f" % [event.axis, event.axis_value]

	# Caso não seja um tipo suportado
	return "Unknown"


# ============================================================
#          STRING → EVENTO (CARREGAR)
# ============================================================

func _string_to_event(serialized_event: String) -> InputEvent:
	# Reconstrói um InputEvent a partir do texto salvo

	if serialized_event.begins_with("Key:"):
		var code = serialized_event.split(":")[1].to_int()
		var ev = InputEventKey.new()
		ev.physical_keycode = code
		return ev

	if serialized_event.begins_with("JoyButton:"):
		var btn = serialized_event.split(":")[1].to_int()
		var ev = InputEventJoypadButton.new()
		ev.device = -1
		ev.button_index = btn
		return ev

	if serialized_event.begins_with("JoyAxis:"):
		var parts := serialized_event.split(":")
		if parts.size() < 3:
			return null
		var ev = InputEventJoypadMotion.new()
		ev.device = -1
		ev.axis = parts[1].to_int()
		ev.axis_value = parts[2].to_float()
		return ev

	# Caso não reconheça o formato
	return null


func _apply_action_deadzone_for_event(action: String, event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis in JOYPAD_TRIGGER_AXES:
		InputMap.action_set_deadzone(action, JOYPAD_TRIGGER_ACTION_DEADZONE)


# ============================================================
#           SALVAR / CARREGAR CONFIG
# ============================================================

func _save():
	# Abre o arquivo em modo escrita
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)

	# Salva o dicionário settings como JSON formatado
	file.store_string(JSON.stringify(settings, "\t"))
	print("💾 Config salvo em:", CONFIG_PATH)


func _load():
	# Se não existir arquivo de config, cria um novo
	if not FileAccess.file_exists(CONFIG_PATH):
		print("⚠ Nenhum arquivo de config encontrado. Criando config padrão!")
		_ensure_settings_schema()
		_save()
		return

	# Abre o arquivo e tenta converter o JSON
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var parse = JSON.parse_string(file.get_as_text())

	# Se o JSON for válido, carrega os dados
	if typeof(parse) == TYPE_DICTIONARY:
		settings = parse
		_ensure_settings_schema()
		print("📂 Config carregado com sucesso.")
	else:
		# Se deu erro, recria o arquivo
		print("❌ Erro ao carregar config.json — recriando arquivo!")
		_ensure_settings_schema()
		_save()


func set_crt_enabled(enabled: bool) -> void:
	settings["crt_enabled"] = enabled
	_save()


func is_crt_enabled() -> bool:
	return settings.get("crt_enabled", true)


func _apply_settings():
	# Aplica volumes carregados no AudioServer
	set_volume("master", settings["volume_master"])
	set_volume("music", settings["volume_music"])
	set_volume("sfx", settings["volume_sfx"])


func _ensure_settings_schema() -> void:
	if not settings.has("volume_master"):
		settings["volume_master"] = 0.0
	if not settings.has("volume_music"):
		settings["volume_music"] = 0.0
	if not settings.has("volume_sfx"):
		settings["volume_sfx"] = 0.0
	if not settings.has("crt_enabled"):
		settings["crt_enabled"] = true
	var schema_version := int(settings.get("input_schema_version", 0))
	if schema_version < INPUT_SCHEMA_VERSION:
		settings["inputs_keyboard"] = _default_keyboard_inputs()
		settings["inputs_xbox"] = _default_controller_inputs()
		settings["inputs_playstation"] = _default_controller_inputs()
		settings["active_input_profile"] = "keyboard"
		settings["input_schema_version"] = INPUT_SCHEMA_VERSION
		settings.erase("inputs")
		settings.erase("inputs_controller")
		_save()
		return

	_ensure_input_profile("inputs_keyboard", _default_keyboard_inputs())
	_ensure_input_profile("inputs_xbox", _default_controller_inputs())
	_ensure_input_profile("inputs_playstation", _default_controller_inputs())
	if not settings.has("active_input_profile"):
		settings["active_input_profile"] = "keyboard"


func _ensure_input_profile(storage_key: String, defaults: Dictionary) -> void:
	if not settings.has(storage_key) or typeof(settings[storage_key]) != TYPE_DICTIONARY:
		settings[storage_key] = defaults
		return
	for action in defaults:
		if not settings[storage_key].has(action):
			settings[storage_key][action] = defaults[action]


func _default_keyboard_inputs() -> Dictionary:
	return {
		"left": _key_binding(KEY_A),
		"right": _key_binding(KEY_D),
		"swim_up": _key_binding(KEY_W),
		"crouch": _key_binding(KEY_S),
		"jump": _key_binding(KEY_SPACE),
		"normal": _key_binding(KEY_1),
		"forma1": _key_binding(KEY_2),
		"forma2": _key_binding(KEY_3),
		"attack": _key_binding(KEY_C),
		"defend": _key_binding(KEY_V),
		"hud_menu": _key_binding(KEY_R),
		"hud_select_up": _key_binding(KEY_I),
		"hud_select_left": _key_binding(KEY_J),
		"hud_select_down": _key_binding(KEY_K),
		"hud_select_right": _key_binding(KEY_L),
		"pause_menu": _key_binding(KEY_TAB),
		"dash": _key_binding(KEY_SHIFT),
	}


func _default_controller_inputs() -> Dictionary:
	return {
		"jump": "JoyButton:0",
		"attack": "JoyButton:2",
		"defend": "JoyButton:3",
		"dash": "JoyButton:1",
		"forma1": "JoyButton:10",
		"forma2": "JoyButton:9",
		"normal": "JoyAxis:4:1.000",
		"hud_menu": "JoyAxis:5:1.000",
		"left": "JoyAxis:0:-1.000",
		"right": "JoyAxis:0:1.000",
		"swim_up": "JoyAxis:1:-1.000",
		"crouch": "JoyAxis:1:1.000",
		"hud_select_left": "JoyAxis:2:-1.000",
		"hud_select_right": "JoyAxis:2:1.000",
		"hud_select_up": "JoyAxis:3:-1.000",
		"hud_select_down": "JoyAxis:3:1.000",
		"pause_menu": "JoyButton:6",
		"wheel_face_up": "JoyButton:3",
		"wheel_face_down": "JoyButton:1",
		"wheel_face_left": "JoyButton:2",
		"wheel_face_right": "JoyButton:0",
	}


func _key_binding(keycode: int) -> String:
	return "Key:%d" % keycode


func _get_active_controller_storage_key() -> String:
	var profile_name := settings.get("active_input_profile", "xbox") as String
	if profile_name != "playstation":
		profile_name = "xbox"
	return "inputs_%s" % profile_name
