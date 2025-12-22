extends Control

# ================================
#           CONTAINERS
# ================================
@onready var menu = $MainMenu
@onready var config_menu = $ConfigMenu
@onready var botoes_menu = $ControlsMenu

# ================================
#         MENU PRINCIPAL
# ================================
@onready var btn_iniciar = $MainMenu/VBoxContainer/Start
@onready var btn_config = $MainMenu/VBoxContainer/Config
@onready var btn_sair = $MainMenu/VBoxContainer/Quit

# ================================
#       CONFIG (VOLUME)
# ================================
@onready var slider_musica = $ConfigMenu/VBoxContainer/SliderMusica
@onready var slider_sfx = $ConfigMenu/VBoxContainer/SliderEfeitos
@onready var btn_cfg_botoes = $ConfigMenu/VBoxContainer/ConfigurarBotoes
@onready var btn_voltar_config = $ConfigMenu/VBoxContainer/Voltar

# ================================
#        MENU DE BOTÕES
# ================================
@onready var btn_pulo = $ControlsMenu/ScrollContainer/VBoxContainer/Controle1
@onready var btn_bolha = $ControlsMenu/ScrollContainer/VBoxContainer/Controle2
@onready var btn_super = $ControlsMenu/ScrollContainer/VBoxContainer/Controle3
@onready var btn_normal_form = $ControlsMenu/ScrollContainer/VBoxContainer/Controle4
@onready var btn_menu = $ControlsMenu/ScrollContainer/VBoxContainer/Controle5      # MENU
@onready var btn_ataque = $ControlsMenu/ScrollContainer/VBoxContainer/Controle6    # ATAQUE

@onready var btn_ataque_especial = $ControlsMenu/ScrollContainer/VBoxContainer/Controle7
@onready var btn_defesa = $ControlsMenu/ScrollContainer/VBoxContainer/Controle8

@onready var btn_combo1 = $ControlsMenu/ScrollContainer/VBoxContainer/Controle9
@onready var btn_combo2 = $ControlsMenu/ScrollContainer/VBoxContainer/Controle10
@onready var btn_combo3 = $ControlsMenu/ScrollContainer/VBoxContainer/Controle11
@onready var btn_combo4 = $ControlsMenu/ScrollContainer/VBoxContainer/Controle12

@onready var btn_voltar_botoes = $ControlsMenu/ScrollContainer/VBoxContainer/Voltar

#      SISTEMA DE REBIND DO MENU
var awaiting_rebind_action: String = ""
var forbidden_keys = [
	KEY_ESCAPE,
	KEY_ENTER,
	KEY_KP_ENTER
]

# ================================
#             READY
# ================================
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
	btn_menu.pressed.connect(func(): _start_rebind("hud_menu"))
	btn_ataque.pressed.connect(func(): _start_rebind("attack"))
	
	btn_ataque_especial.pressed.connect(func(): _start_rebind("attack_special"))
	btn_defesa.pressed.connect(func(): _start_rebind("defend"))

	btn_combo1.pressed.connect(func(): _start_rebind("combo_1"))
	btn_combo2.pressed.connect(func(): _start_rebind("combo_2"))
	btn_combo3.pressed.connect(func(): _start_rebind("combo_3"))
	btn_combo4.pressed.connect(func(): _start_rebind("combo_4"))


	btn_voltar_botoes.pressed.connect(_back_to_config_menu)

	# Atualiza os textos iniciais
	_update_control_labels()


# ================================
#          INPUT REBIND
# ================================
func _input(event: InputEvent):
	if awaiting_rebind_action == "":
		return

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
#              MENUS
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
#        SISTEMA DE REBIND
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
#   VISUAL (ESTILO GZDOOM)
# ================================
func _update_control_labels():
	btn_pulo.text = "Pulo: " + _get_current_input_name("jump")
	btn_bolha.text = "Bolha: " + _get_current_input_name("forma1")
	btn_super.text = "Super: " + _get_current_input_name("forma2")
	btn_normal_form.text = "Normal: " + _get_current_input_name("normal")
	btn_menu.text = "Menu: " + _get_current_input_name("hud_menu")
	btn_ataque.text = "Ataque: " + _get_current_input_name("attack")
	btn_ataque_especial.text = "Ataque Especial: " + _get_current_input_name("attack_special")
	btn_defesa.text = "Defesa: " + _get_current_input_name("defend")

	btn_combo1.text = "Combo 1: " + _get_current_input_name("combo_1")
	btn_combo2.text = "Combo 2: " + _get_current_input_name("combo_2")
	btn_combo3.text = "Combo 3: " + _get_current_input_name("combo_3")
	btn_combo4.text = "Combo 4: " + _get_current_input_name("combo_4")



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
