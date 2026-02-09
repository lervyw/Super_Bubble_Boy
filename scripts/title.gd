extends Control

# =========================================================
#  ESTE SCRIPT CONTROLA O MENU PRINCIPAL + CONFIG + CONTROLES
#  - Alterna quais telas estão visíveis
#  - Ajusta volumes (música e SFX)
#  - Faz rebind (troca) de teclas/botões do InputMap
# =========================================================


# ================================
#           CONTAINERS
# ================================
# Referências para as 3 telas (containers) do menu
@onready var menu = $MainMenu
@onready var config_menu = $ConfigMenu
@onready var botoes_menu = $ControlsMenu


# ================================
#         MENU PRINCIPAL
# ================================
# Botões do menu principal
@onready var btn_iniciar = $MainMenu/VBoxContainer/Start
@onready var btn_config = $MainMenu/VBoxContainer/Config
@onready var btn_sair = $MainMenu/VBoxContainer/Quit


# ================================
#       CONFIG (VOLUME)
# ================================
# Sliders e botões da tela de configurações (volume + ir pro rebind)
@onready var slider_musica = $ConfigMenu/VBoxContainer/SliderMusica
@onready var slider_sfx = $ConfigMenu/VBoxContainer/SliderEfeitos
@onready var btn_cfg_botoes = $ConfigMenu/VBoxContainer/ConfigurarBotoes
@onready var btn_voltar_config = $ConfigMenu/VBoxContainer/Voltar


# ================================
#        MENU DE BOTÕES
# ================================
# Botões que mostram/alteram cada ação do InputMap (rebind)
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

# Botão de voltar do menu de controles para o menu config
@onready var btn_voltar_botoes = $ControlsMenu/ScrollContainer/VBoxContainer/Voltar


# ================================
#      SISTEMA DE REBIND DO MENU
# ================================
# Guarda qual ação está esperando receber uma nova tecla/botão
var awaiting_rebind_action: String = ""

# Teclas que você não deixa usar no rebind (pra evitar travar navegação/confirmar/sair)
var forbidden_keys = [
	KEY_ESCAPE,
	KEY_ENTER,
	KEY_KP_ENTER
]


# ================================
#             READY
# ================================
func _ready():
	# Estado inicial: mostra o menu principal e esconde as outras telas
	menu.visible = true
	config_menu.visible = false
	botoes_menu.visible = false

	# --- Conecta botões do menu principal ---
	btn_iniciar.pressed.connect(_on_iniciar)        # inicia o jogo/cutscene
	btn_config.pressed.connect(_open_config_menu)   # abre config
	btn_sair.pressed.connect(_on_sair)              # fecha o jogo

	# --- Conecta sliders/botões da config ---
	# Ao mexer no slider, atualiza o volume via ConfigManager
	slider_musica.value_changed.connect(func(val): ConfigManager.set_volume("music", val))
	slider_sfx.value_changed.connect(func(val): ConfigManager.set_volume("sfx", val))

	# Abre menu de controles / volta pro menu principal
	btn_cfg_botoes.pressed.connect(_open_botoes_menu)
	btn_voltar_config.pressed.connect(_back_to_menu)

	# --- Conecta botões do menu de controles (cada um chama rebind de uma ação) ---
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

	# Volta do menu de controles para o menu de config
	btn_voltar_botoes.pressed.connect(_back_to_config_menu)

	# Atualiza o texto dos botões com o input atual (ex: "Pulo: Space")
	_update_control_labels()


# ================================
#          INPUT REBIND
# ================================
func _input(event: InputEvent):
	# Se não estiver no modo "esperando rebind", ignora tudo
	if awaiting_rebind_action == "":
		return

	# --- Rebind por teclado ---
	if event is InputEventKey and event.pressed:
		# Bloqueia teclas proibidas
		if event.keycode in forbidden_keys:
			return
		# Evita inputs sem caractere (algumas teclas especiais)
		if event.unicode == 0:
			return

		# Finaliza o rebind usando esse evento
		_finish_rebind(event)
		return

	# --- Rebind por controle (joypad) ---
	if event is InputEventJoypadButton and event.pressed:
		_finish_rebind(event)
		return


# ================================
#              MENUS
# ================================
func _on_iniciar():
	# Começa o jogo indo para a cutscene (centralizado no GameManager)
	GameManager.goto_cutscene()

func _on_sair():
	# Sai do jogo
	get_tree().quit()

func _open_config_menu():
	# Troca visibilidade: só a config fica visível
	menu.visible = false
	config_menu.visible = true
	botoes_menu.visible = false

func _back_to_menu():
	# Volta para o menu principal
	menu.visible = true
	config_menu.visible = false
	botoes_menu.visible = false

func _open_botoes_menu():
	# Abre a tela de rebind/controles
	menu.visible = false
	config_menu.visible = false
	botoes_menu.visible = true

func _back_to_config_menu():
	# Volta do rebind para config
	menu.visible = false
	config_menu.visible = true
	botoes_menu.visible = false


# ================================
#        SISTEMA DE REBIND
# ================================
func _start_rebind(action_name: String):
	# Entra no modo "aguardando input" e define qual ação será alterada
	awaiting_rebind_action = action_name
	print("🎮 Pressione um botão para redefinir:", action_name)

func _finish_rebind(event: InputEvent):
	# Aplica o rebind no ConfigManager (provavelmente mexe no InputMap e salva)
	ConfigManager.rebind_action(awaiting_rebind_action, event)
	print("✔ Ação configurada:", awaiting_rebind_action)

	# Sai do modo rebind e atualiza textos na UI
	awaiting_rebind_action = ""
	_update_control_labels()


# ================================
#   VISUAL (ESTILO GZDOOM)
# ================================
func _update_control_labels():
	# Atualiza o texto de cada botão para mostrar qual tecla/botão está configurado agora
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
	# Pega os eventos (inputs) cadastrados nessa ação no InputMap
	var events = InputMap.action_get_events(action)

	# Se não tem nada configurado, mostra "<nenhum>"
	if events.is_empty():
		return "<nenhum>"

	# Pega o primeiro evento (você está exibindo só 1 binding por ação)
	var ev = events[0]

	# Se for teclado, converte keycode para string legível
	if ev is InputEventKey:
		return OS.get_keycode_string(ev.physical_keycode)

	# Se for controle, mostra o índice do botão
	if ev is InputEventJoypadButton:
		return "Botão %d" % ev.button_index

	# Fallback pra casos não tratados (mouse, eixo analógico, etc.)
	return "<desconhecido>"
