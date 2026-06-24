extends Node
# =========================================================
#  CONFIGMANAGER
#  Responsável por:
#  - Salvar e carregar configurações do jogo
#  - Controlar volumes de áudio
#  - Gerenciar rebind de inputs (teclado/controle)
#  Os dados são salvos em um arquivo JSON no user://
# =========================================================

# Caminho do arquivo de configuração salvo no sistema do jogador
const CONFIG_PATH := "user://config.json"
const JOYPAD_TRIGGER_ACTION_DEADZONE: float = 0.20
const JOYPAD_TRIGGER_AXES: Array[int] = [4, 5]


# ================================
#     CONFIGURAÇÕES PADRÃO
# ================================
# Valores usados caso o arquivo ainda não exista
var settings := {
	"volume_master": 0.0,
	"volume_music": 0.0,
	"volume_sfx": 0.0,

	"inputs_keyboard": {
	},
	"inputs_controller": {
	}
}


func _ready():
	# Inicializa o sistema de configuração
	print("🔧 ConfigManager iniciado.")
	_load()            # Carrega o arquivo de config (ou cria um novo)
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

	if is_joypad:
		_remove_conflicting_joypad_events(action, ev)

	var storage_key := "inputs_controller" if is_joypad else "inputs_keyboard"
	settings[storage_key][action] = _event_to_string(ev)
	_save()


func apply_loaded_inputs():
	if not settings.has("inputs_keyboard") or typeof(settings["inputs_keyboard"]) != TYPE_DICTIONARY:
		settings["inputs_keyboard"] = {}
	if not settings.has("inputs_controller") or typeof(settings["inputs_controller"]) != TYPE_DICTIONARY:
		settings["inputs_controller"] = {}

	for entry in [["inputs_keyboard", false], ["inputs_controller", true]]:
		var storage_key := entry[0] as String
		var is_joypad := entry[1] as bool
		for action in settings[storage_key].keys():
			var ev_str = settings[storage_key][action]
			var event = _string_to_event(ev_str)
			if not event:
				continue

			if not InputMap.has_action(action):
				InputMap.add_action(action)

			var to_remove: Array[InputEvent] = []
			for existing in InputMap.action_get_events(action):
				if is_joypad == (existing is InputEventJoypadButton or existing is InputEventJoypadMotion):
					to_remove.append(existing)

			for e in to_remove:
				InputMap.action_erase_event(action, e)

			InputMap.action_add_event(action, event)
			_apply_action_deadzone_for_event(action, event)

			if is_joypad:
				_remove_conflicting_joypad_events(action, event)


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

func _string_to_event(str: String) -> InputEvent:
	# Reconstrói um InputEvent a partir do texto salvo

	if str.begins_with("Key:"):
		var code = str.split(":")[1].to_int()
		var ev = InputEventKey.new()
		ev.physical_keycode = code
		return ev

	if str.begins_with("JoyButton:"):
		var btn = str.split(":")[1].to_int()
		var ev = InputEventJoypadButton.new()
		ev.device = -1
		ev.button_index = btn
		return ev

	if str.begins_with("JoyAxis:"):
		var parts := str.split(":")
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


func _remove_conflicting_joypad_events(source_action: String, event: InputEvent) -> void:
	for other_action in InputMap.get_actions():
		if other_action == source_action:
			continue
		var to_remove: Array[InputEvent] = []
		for existing in InputMap.action_get_events(other_action):
			if _is_same_physical_input(existing, event):
				to_remove.append(existing)
		for e in to_remove:
			InputMap.action_erase_event(other_action, e)


func _is_same_physical_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and sign(a.axis_value) == sign(b.axis_value)
	return false


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
		_save()
		return

	# Abre o arquivo e tenta converter o JSON
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var parse = JSON.parse_string(file.get_as_text())

	# Se o JSON for válido, carrega os dados
	if typeof(parse) == TYPE_DICTIONARY:
		settings = parse
		_ensure_settings_schema()
		apply_loaded_inputs()  # Aplica inputs salvos
		print("📂 Config carregado com sucesso.")
	else:
		# Se deu erro, recria o arquivo
		print("❌ Erro ao carregar config.json — recriando arquivo!")
		_save()


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
	if not settings.has("inputs_keyboard") or typeof(settings["inputs_keyboard"]) != TYPE_DICTIONARY:
		settings["inputs_keyboard"] = {}
	if not settings.has("inputs_controller") or typeof(settings["inputs_controller"]) != TYPE_DICTIONARY:
		settings["inputs_controller"] = {}
	if settings.has("inputs"):
		var old = settings["inputs"]
		if typeof(old) == TYPE_DICTIONARY:
			for action in old:
				var ev_str = old[action]
				if ev_str.begins_with("Key:"):
					settings["inputs_keyboard"][action] = ev_str
				else:
					settings["inputs_controller"][action] = ev_str
		settings.erase("inputs")
		_save()
