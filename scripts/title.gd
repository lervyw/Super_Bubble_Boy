extends Control

# Containers
@onready var menu = $MainMenu
@onready var config_menu = $ConfigMenu
@onready var botoes_menu = $ControlsMenu

# Menu principal
@onready var btn_iniciar = $MainMenu/VBoxContainer/Start
@onready var btn_config = $MainMenu/VBoxContainer/Config
@onready var btn_sair = $MainMenu/VBoxContainer/Quit

# Config menu (Volume)
@onready var slider_musica = $ConfigMenu/VBoxContainer/SliderMusica
@onready var slider_sfx = $ConfigMenu/VBoxContainer/SliderEfeitos
@onready var btn_cfg_botoes = $ConfigMenu/VBoxContainer/ConfigurarBotoes
@onready var btn_voltar_config = $ConfigMenu/VBoxContainer/Voltar

# Menu de botões
@onready var btn_pulo = $ControlsMenu/VBoxContainer/Controle1
@onready var btn_bolha = $ControlsMenu/VBoxContainer/Controle2
@onready var btn_super = $ControlsMenu/VBoxContainer/Controle3
@onready var btn_normal_form = $ControlsMenu/VBoxContainer/Controle4
@onready var btn_voltar_botoes = $ControlsMenu/VBoxContainer/Voltar

# Para captura de input
var awaiting_rebind_action: String = ""
var forbidden_keys = [
	KEY_ESCAPE,
	KEY_ENTER,
	KEY_KP_ENTER
]

func _ready():
	menu.visible = true
	config_menu.visible = false
	botoes_menu.visible = false

	# Menu principal
	btn_iniciar.pressed.connect(_on_iniciar)
	btn_config.pressed.connect(_open_config_menu)
	btn_sair.pressed.connect(_on_sair)

	# Configurações de volume
	slider_musica.value_changed.connect(func(val): ConfigManager.set_volume("music", val))
	slider_sfx.value_changed.connect(func(val): ConfigManager.set_volume("sfx", val))
	btn_cfg_botoes.pressed.connect(_open_botoes_menu)
	btn_voltar_config.pressed.connect(_back_to_menu)

	# Menu dos controles
	btn_pulo.pressed.connect(func(): _start_rebind("jump"))
	btn_bolha.pressed.connect(func(): _start_rebind("forma1"))
	btn_super.pressed.connect(func(): _start_rebind("forma2"))
	btn_normal_form.pressed.connect(func(): _start_rebind("normal"))

	btn_voltar_botoes.pressed.connect(_back_to_config_menu)

	# Atualiza os textos iniciais dos botões
	_update_control_labels()


func _input(event: InputEvent):
	if awaiting_rebind_action == "":
		return

	# Apenas eventos válidos
	if event is InputEventKey and event.pressed:
		if event.keycode in forbidden_keys:
			return
		if event.unicode == 0:
			return
		_finish_rebind(event)
		return

	if event is InputEventJoypadButton and event.pressed:
		_finish_rebind(event)
		return


# ================================
#             MENUS
# ================================
func _on_iniciar():
	GameManager.goto_cutscene()

func _on_sair():
	get_tree().quit()

func _open_config_menu():
	menu.visible = false
	config_menu.visible = true
	botoes_menu.visible = false

func _back_to_menu():
	menu.visible = true
	config_menu.visible = false
	botoes_menu.visible = false

func _open_botoes_menu():
	menu.visible = false
	config_menu.visible = false
	botoes_menu.visible = true

func _back_to_config_menu():
	menu.visible = false
	config_menu.visible = true
	botoes_menu.visible = false


# ================================
#         SISTEMA DE REBIND
# ================================
func _start_rebind(action_name: String):
	awaiting_rebind_action = action_name
	print("🎮 Pressione um botão para redefinir:", action_name)


func _finish_rebind(event: InputEvent):
	ConfigManager.rebind_action(awaiting_rebind_action, event)
	print("✔ Ação configurada:", awaiting_rebind_action)

	awaiting_rebind_action = ""
	_update_control_labels()


# ================================
#   VISUALIZAÇÃO ESTILO GZDOOM
# ================================
func _update_control_labels():
	btn_pulo.text = "Pulo: " + _get_current_input_name("jump")
	btn_bolha.text = "Bolha: " + _get_current_input_name("forma1")
	btn_super.text = "Super: " + _get_current_input_name("forma2")
	btn_normal_form.text = "Normal: " + _get_current_input_name("normal")


func _get_current_input_name(action: String) -> String:
	var events = InputMap.action_get_events(action)

	if events.is_empty():
		return "<nenhum>"

	var ev = events[0]

	if ev is InputEventKey:
		return OS.get_keycode_string(ev.physical_keycode)

	if ev is InputEventJoypadButton:
		return "Botão %d" % ev.button_index

	return "<desconhecido>"
