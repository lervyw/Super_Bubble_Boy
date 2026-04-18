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


# ================================
#     CONFIGURAÇÕES PADRÃO
# ================================
# Valores usados caso o arquivo ainda não exista
var settings := {
	"volume_master": 0.0,
	"volume_music": 0.0,
	"volume_sfx": 0.0,

	# Inputs personalizados pelo jogador
	"inputs": {
		# Ex: "jump": "Key:32"
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
	# Garante que a ação exista no InputMap
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	# Remove qualquer input antigo dessa ação
	InputMap.action_erase_events(action)

	# DUPLICA o evento
	# (evita problemas por reutilizar o mesmo objeto InputEvent)
	var ev := event.duplicate()
	InputMap.action_add_event(action, ev)

	# Converte o evento para string e salva
	settings["inputs"][action] = _event_to_string(ev)
	_save()


func apply_loaded_inputs():
	# Reaplica todos os inputs salvos no arquivo de config
	for action in settings["inputs"].keys():
		var ev_str = settings["inputs"][action]
		var event = _string_to_event(ev_str)

		if event:
			# Garante que a ação exista
			if not InputMap.has_action(action):
				InputMap.add_action(action)

			# Remove binds antigos e aplica o carregado
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)


# ============================================================
#          EVENTO → STRING (SALVAR)
# ============================================================

func _event_to_string(event: InputEvent) -> String:
	# Converte um InputEvent em texto para salvar no JSON

	if event is InputEventKey:
		# Ex: "Key:32"
		return "Key:%s" % event.physical_keycode

	if event is InputEventJoypadButton:
		# Ex: "JoyButton:0"
		return "JoyButton:%s" % event.button_index

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
		ev.button_index = btn
		return ev

	# Caso não reconheça o formato
	return null


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
