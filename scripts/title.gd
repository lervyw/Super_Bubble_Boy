extends Control

# Containers principais
@onready var main_menu = $MainMenu
@onready var config_menu = $ConfigMenu
@onready var controls_menu = $ControlsMenu

# Botões do MainMenu
@onready var btn_start = $MainMenu/VBoxContainer/Start
@onready var btn_config = $MainMenu/VBoxContainer/Config
@onready var btn_quit = $MainMenu/VBoxContainer/Quit

# Botões do ConfigMenu
@onready var btn_cfg_volume = $ConfigMenu/VBoxContainer/VolumeConfig
@onready var btn_cfg_controls = $ConfigMenu/VBoxContainer/Controles
@onready var btn_cfg_back = $ConfigMenu/VBoxContainer/Voltar

# Botões do ControlsMenu
@onready var btn_controls_back = $ControlsMenu/VBoxContainer/Voltar


func _ready():
	set_process_input(true)

	# estados iniciais
	main_menu.visible = true
	config_menu.visible = false
	controls_menu.visible = false

	# MAIN MENU
	btn_start.pressed.connect(_on_start_pressed)
	btn_config.pressed.connect(_on_open_config_menu)
	btn_quit.pressed.connect(_on_quit_pressed)

	# CONFIG MENU
	btn_cfg_controls.pressed.connect(_on_open_controls_menu)
	btn_cfg_back.pressed.connect(_on_back_to_main)

	# CONTROLS MENU
	btn_controls_back.pressed.connect(_on_back_to_config)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_start"):
		_on_start_pressed()
	elif event.is_action_pressed("ui_select_input"):
		_on_quit_pressed()


# ===============================
#        AÇÕES DO JOGO
# ===============================
func _on_start_pressed():
	print("▶️ Iniciando jogo…")
	GameManager.goto_cutscene()

func _on_quit_pressed():
	print("👋 Saindo do jogo…")
	get_tree().quit()

# ===============================
#        NAVEGAÇÃO ENTRE MENUS
# ===============================
func _on_open_config_menu():
	main_menu.visible = false
	config_menu.visible = true
	controls_menu.visible = false

func _on_open_controls_menu():
	main_menu.visible = false
	config_menu.visible = false
	controls_menu.visible = true

func _on_back_to_main():
	main_menu.visible = true
	config_menu.visible = false
	controls_menu.visible = false

func _on_back_to_config():
	main_menu.visible = false
	config_menu.visible = true
	controls_menu.visible = false
