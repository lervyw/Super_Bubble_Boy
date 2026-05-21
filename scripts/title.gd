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
@onready var controls_scroll: ScrollContainer = $ControlsMenu/ScrollContainer
@onready var logo_intro: TextureRect = $LogoIntro
@onready var menu_intro_background: TextureRect = $MenuIntroBackground

const LOGO_INTRO_PATH: String = "res://sprites/menu/logo_intro/LogoRes%d.png"
const MENU_INTRO_PATH: String = "res://sprites/menu/menu_intro/menu%d.png"
const LOGO_INTRO_FRAME_COUNT: int = 28
const MENU_INTRO_FRAME_COUNT: int = 56
const LOGO_INTRO_FPS: float = 12.0
const MENU_INTRO_FPS: float = 14.0
const MENU_IDLE_LOOP_FIRST_FRAME: int = 51
const MENU_IDLE_LOOP_LAST_FRAME: int = 56
const MENU_IDLE_LOOP_FPS: float = 8.0
const JOYPAD_AXIS_REBIND_THRESHOLD: float = 0.55
const JOYPAD_TRIGGER_REBIND_THRESHOLD: float = 0.20
const JOYPAD_TRIGGER_AXES: Array[int] = [4, 5]
const UI_JOYPAD_DEADZONE: float = 0.5


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
@onready var slider_master = $ConfigMenu/VBoxContainer/SliderMaster
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
@onready var btn_ultimate = $ControlsMenu/ScrollContainer/VBoxContainer/Controle13
@onready var btn_esquerda = $ControlsMenu/ScrollContainer/VBoxContainer/Controle14
@onready var btn_direita = $ControlsMenu/ScrollContainer/VBoxContainer/Controle15
@onready var btn_agachar = $ControlsMenu/ScrollContainer/VBoxContainer/Controle16
@onready var btn_dash = $ControlsMenu/ScrollContainer/VBoxContainer/Controle17
@onready var btn_pause = $ControlsMenu/ScrollContainer/VBoxContainer/Controle18

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
var intro_running: bool = true

# Teclas que você não deixa usar no rebind (pra evitar travar navegação/confirmar/sair)
var forbidden_keys: Array[int] = [
	KEY_ESCAPE,
	KEY_ENTER,
	KEY_KP_ENTER
]


# ================================
#             READY
# ================================
func _ready():
	_ensure_controller_ui_actions()

	# Estado inicial: mostra o menu principal e esconde as outras telas
	menu.visible = false
	config_menu.visible = false
	botoes_menu.visible = false
	if logo_intro:
		logo_intro.visible = true
	if menu_intro_background:
		menu_intro_background.visible = true

	# --- Conecta botões do menu principal ---
	_connect_pressed_once(btn_iniciar, _on_iniciar)        # inicia o jogo/cutscene
	_connect_pressed_once(btn_config, _open_config_menu)   # abre config
	_connect_pressed_once(btn_sair, _on_sair)              # fecha o jogo

	# --- Conecta sliders/botões da config ---
	# Ao mexer no slider, atualiza o volume via ConfigManager
	slider_master.value = ConfigManager.get_volume("master")
	slider_musica.value = ConfigManager.get_volume("music")
	slider_sfx.value = ConfigManager.get_volume("sfx")
	slider_master.value_changed.connect(func(val): ConfigManager.set_volume("master", val))
	slider_musica.value_changed.connect(func(val): ConfigManager.set_volume("music", val))
	slider_sfx.value_changed.connect(func(val): ConfigManager.set_volume("sfx", val))

	# Abre menu de controles / volta pro menu principal
	_connect_pressed_once(btn_cfg_botoes, _open_botoes_menu)
	_connect_pressed_once(btn_voltar_config, _back_to_menu)

	# --- Conecta botões do menu de controles (cada um chama rebind de uma ação) ---
	_connect_rebind_button_once(btn_pulo, "jump")
	_connect_rebind_button_once(btn_bolha, "forma1")
	_connect_rebind_button_once(btn_super, "forma2")
	_connect_rebind_button_once(btn_normal_form, "normal")
	_connect_rebind_button_once(btn_menu, "hud_menu")
	_connect_rebind_button_once(btn_ataque, "attack")
	_connect_rebind_button_once(btn_ataque_especial, "attack_special")
	_connect_rebind_button_once(btn_defesa, "defend")
	_connect_rebind_button_once(btn_ultimate, "ultimate_attack")
	_connect_rebind_button_once(btn_esquerda, "left")
	_connect_rebind_button_once(btn_direita, "right")
	_connect_rebind_button_once(btn_agachar, "crouch")
	_connect_rebind_button_once(btn_dash, "dash")
	_connect_rebind_button_once(btn_pause, "pause_menu")
	_connect_rebind_button_once(btn_combo1, "combo_1")
	_connect_rebind_button_once(btn_combo2, "combo_2")
	_connect_rebind_button_once(btn_combo3, "combo_3")
	_connect_rebind_button_once(btn_combo4, "combo_4")

	# Volta do menu de controles para o menu de config
	_connect_pressed_once(btn_voltar_botoes, _back_to_config_menu)
	_setup_controls_scroll_focus()

	# Atualiza o texto dos botões com o input atual (ex: "Pulo: Space")
	_update_control_labels()
	_play_startup_intro()


func _connect_pressed_once(button: BaseButton, callable: Callable) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(callable):
		button.pressed.connect(callable)


func _connect_rebind_button_once(button: BaseButton, action_name: String) -> void:
	if button == null:
		return
	var action_callable: Callable = func(): _start_rebind(action_name)
	if not button.pressed.is_connected(action_callable):
		button.pressed.connect(action_callable)


func _play_startup_intro() -> void:
	await _play_frame_sequence(logo_intro, LOGO_INTRO_PATH, LOGO_INTRO_FRAME_COUNT, LOGO_INTRO_FPS, false)

	if logo_intro:
		logo_intro.visible = false

	await _play_frame_sequence(menu_intro_background, MENU_INTRO_PATH, MENU_INTRO_FRAME_COUNT, MENU_INTRO_FPS, true)

	intro_running = false
	menu.visible = true
	_grab_focus_deferred(btn_iniciar)
	_loop_menu_idle_animation()


func _play_frame_sequence(target: TextureRect, path_pattern: String, frame_count: int, fps: float, keep_last_frame: bool) -> void:
	if target == null:
		return

	var frame_delay: float = 1.0 / maxf(fps, 1.0)
	target.visible = true

	for frame_number in range(1, frame_count + 1):
		var frame_path: String = path_pattern % frame_number
		if ResourceLoader.exists(frame_path):
			var texture: Texture2D = load(frame_path) as Texture2D
			if texture:
				target.texture = texture

		await get_tree().create_timer(frame_delay).timeout

	if not keep_last_frame:
		target.visible = false


func _loop_menu_idle_animation() -> void:
	if menu_intro_background == null:
		return

	var frame_delay: float = 1.0 / maxf(MENU_IDLE_LOOP_FPS, 1.0)

	while is_inside_tree():
		for frame_number in range(MENU_IDLE_LOOP_FIRST_FRAME, MENU_IDLE_LOOP_LAST_FRAME + 1):
			_set_menu_intro_frame(frame_number)
			await get_tree().create_timer(frame_delay).timeout

		for frame_number in range(MENU_IDLE_LOOP_LAST_FRAME - 1, MENU_IDLE_LOOP_FIRST_FRAME, -1):
			_set_menu_intro_frame(frame_number)
			await get_tree().create_timer(frame_delay).timeout


func _set_menu_intro_frame(frame_number: int) -> void:
	var frame_path: String = MENU_INTRO_PATH % frame_number
	if not ResourceLoader.exists(frame_path):
		return

	var texture: Texture2D = load(frame_path) as Texture2D
	if texture:
		menu_intro_background.texture = texture


# ================================
#          INPUT REBIND
# ================================
func _input(event: InputEvent):
	if intro_running:
		return

	# Se não estiver no modo "esperando rebind", ignora tudo
	if awaiting_rebind_action == "":
		return

	# --- Rebind por teclado ---
	if event is InputEventKey and event.pressed:
		# Bloqueia teclas proibidas
		if event.keycode in forbidden_keys:
			return

		# Finaliza o rebind usando esse evento
		_finish_rebind(event)
		return

	# --- Rebind por controle (joypad) ---
	if event is InputEventJoypadButton and event.pressed:
		_finish_rebind(event)
		return

	# --- Rebind por eixo/gatilho do controle (analógico, LT/L2, RT/R2) ---
	if event is InputEventJoypadMotion:
		var joy_event := _normalize_joy_motion_for_rebind(event)
		if joy_event:
			_finish_rebind(joy_event)
			return


func _normalize_joy_motion_for_rebind(event: InputEventJoypadMotion) -> InputEventJoypadMotion:
	var joy_event := event.duplicate() as InputEventJoypadMotion

	if _is_joypad_trigger_axis(event.axis):
		if event.axis_value < JOYPAD_TRIGGER_REBIND_THRESHOLD:
			return null
		joy_event.axis_value = 1.0
		return joy_event

	if absf(event.axis_value) < JOYPAD_AXIS_REBIND_THRESHOLD:
		return null

	joy_event.axis_value = 1.0 if event.axis_value > 0.0 else -1.0
	return joy_event


func _is_joypad_trigger_axis(axis: int) -> bool:
	return axis in JOYPAD_TRIGGER_AXES


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
	if intro_running:
		return
	# Troca visibilidade: só a config fica visível
	menu.visible = false
	config_menu.visible = true
	botoes_menu.visible = false
	_grab_focus_deferred(btn_cfg_botoes)

func _back_to_menu():
	if intro_running:
		return
	# Volta para o menu principal
	menu.visible = true
	config_menu.visible = false
	botoes_menu.visible = false
	_grab_focus_deferred(btn_iniciar)

func _open_botoes_menu():
	if intro_running:
		return
	# Abre a tela de rebind/controles
	menu.visible = false
	config_menu.visible = false
	botoes_menu.visible = true
	if controls_scroll:
		controls_scroll.scroll_vertical = 0
	_grab_focus_deferred(btn_pulo)

func _back_to_config_menu():
	if intro_running:
		return
	# Volta do rebind para config
	menu.visible = false
	config_menu.visible = true
	botoes_menu.visible = false
	_grab_focus_deferred(btn_cfg_botoes)


func _grab_focus_deferred(control: Control) -> void:
	if not control:
		return
	control.call_deferred("grab_focus")
	call_deferred("_scroll_focused_control_into_view", control)


func _setup_controls_scroll_focus() -> void:
	if controls_scroll:
		controls_scroll.set("follow_focus", true)

	var control_buttons: Array[Control] = [
		btn_pulo,
		btn_bolha,
		btn_super,
		btn_normal_form,
		btn_menu,
		btn_ataque,
		btn_ataque_especial,
		btn_defesa,
		btn_combo1,
		btn_combo2,
		btn_combo3,
		btn_combo4,
		btn_ultimate,
		btn_esquerda,
		btn_direita,
		btn_agachar,
		btn_dash,
		btn_pause,
		btn_voltar_botoes,
	]

	for button in control_buttons:
		var focus_callable := _on_control_button_focus_entered.bind(button)
		if button and not button.focus_entered.is_connected(focus_callable):
			button.focus_entered.connect(focus_callable)


func _on_control_button_focus_entered(control: Control) -> void:
	_scroll_focused_control_into_view(control)


func _scroll_focused_control_into_view(control: Control) -> void:
	if not controls_scroll or not control:
		return
	if not botoes_menu.visible:
		return

	var top := control.position.y
	var bottom := top + control.size.y
	var view_top := float(controls_scroll.scroll_vertical)
	var view_bottom := view_top + controls_scroll.size.y
	var padding := 12.0

	if top < view_top + padding:
		controls_scroll.scroll_vertical = max(int(top - padding), 0)
	elif bottom > view_bottom - padding:
		controls_scroll.scroll_vertical = max(int(bottom - controls_scroll.size.y + padding), 0)


func _ensure_controller_ui_actions() -> void:
	_ensure_action("ui_accept")
	_ensure_action("ui_select")
	_ensure_action("ui_cancel")
	_ensure_action("ui_up")
	_ensure_action("ui_down")
	_ensure_action("ui_left")
	_ensure_action("ui_right")

	_add_joy_button_once("ui_accept", 0)
	_add_joy_button_once("ui_select", 0)
	_add_joy_button_once("ui_cancel", 1)
	_add_joy_button_once("ui_up", 11)
	_add_joy_button_once("ui_down", 12)
	_add_joy_button_once("ui_left", 13)
	_add_joy_button_once("ui_right", 14)

	_add_joy_axis_once("ui_left", 0, -1.0)
	_add_joy_axis_once("ui_right", 0, 1.0)
	_add_joy_axis_once("ui_up", 1, -1.0)
	_add_joy_axis_once("ui_down", 1, 1.0)


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, UI_JOYPAD_DEADZONE)


func _add_joy_button_once(action_name: StringName, button_index: int) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and event.button_index == button_index:
			return

	var joy_event := InputEventJoypadButton.new()
	joy_event.device = -1
	joy_event.button_index = button_index
	InputMap.action_add_event(action_name, joy_event)


func _add_joy_axis_once(action_name: StringName, axis: int, axis_value: float) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion and event.axis == axis and sign(event.axis_value) == sign(axis_value):
			return

	var joy_event := InputEventJoypadMotion.new()
	joy_event.device = -1
	joy_event.axis = axis
	joy_event.axis_value = axis_value
	InputMap.action_add_event(action_name, joy_event)


# ================================
#        SISTEMA DE REBIND
# ================================
func _start_rebind(action_name: String):
	# Entra no modo "aguardando input" e define qual ação será alterada
	awaiting_rebind_action = action_name
	_set_rebind_prompt("Pressione tecla, botão, analógico ou gatilho")
	print("Pressione tecla, botão, analógico ou gatilho para redefinir:", action_name)

func _finish_rebind(event: InputEvent):
	# Aplica o rebind no ConfigManager (provavelmente mexe no InputMap e salva)
	ConfigManager.rebind_action(awaiting_rebind_action, event)
	print("✔ Ação configurada:", awaiting_rebind_action)

	# Sai do modo rebind e atualiza textos na UI
	awaiting_rebind_action = ""
	_update_control_labels()


# ================================
#   VISUAL / LABELS
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
	btn_ultimate.text = "Ultimate: " + _get_current_input_name("ultimate_attack")
	btn_esquerda.text = "Esquerda: " + _get_current_input_name("left")
	btn_direita.text = "Direita: " + _get_current_input_name("right")
	btn_agachar.text = "Agachar: " + _get_current_input_name("crouch")
	btn_dash.text = "Dash: " + _get_current_input_name("dash")
	btn_pause.text = "Pausa: " + _get_current_input_name("pause_menu")

	btn_combo1.text = "Combo 1: " + _get_current_input_name("combo_1")
	btn_combo2.text = "Combo 2: " + _get_current_input_name("combo_2")
	btn_combo3.text = "Combo 3: " + _get_current_input_name("combo_3")
	btn_combo4.text = "Combo 4: " + _get_current_input_name("combo_4")
	_set_rebind_prompt("Selecione uma ação para remapear")


func _get_current_input_name(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.is_empty():
		return "<nenhum>"

	var has_controller := ControllerMapper.has_controller()
	var ev: InputEvent = events[0]

	for event in events:
		if has_controller:
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				ev = event
				break
		else:
			if event is InputEventKey:
				ev = event
				break

	if ev is InputEventKey:
		var keycode: int = ev.physical_keycode
		if keycode == 0:
			keycode = ev.keycode
		return OS.get_keycode_string(keycode)

	if ev is InputEventJoypadButton:
		return _get_joy_button_name(ev.button_index)

	if ev is InputEventJoypadMotion:
		return _get_joy_axis_name(ev.axis, ev.axis_value)

	return "<desconhecido>"


func _set_rebind_prompt(text: String) -> void:
	var prompt: Node = $ControlsMenu/ScrollContainer/VBoxContainer.get_node_or_null("RebindPrompt")
	if prompt:
		(prompt as Label).text = text


func _get_joy_button_name(button_index: int) -> String:
	return ControllerMapper.get_button_name(button_index) if ControllerMapper.has_controller() else _legacy_joy_button_name(button_index)


func _get_joy_axis_name(axis: int, axis_value: float) -> String:
	return ControllerMapper.get_axis_name(axis, axis_value) if ControllerMapper.has_controller() else _legacy_joy_axis_name(axis, axis_value)


func _legacy_joy_button_name(button_index: int) -> String:
	match button_index:
		0: return "A / X"
		1: return "B / Circulo"
		2: return "X / Quadrado"
		3: return "Y / Triangulo"
		4: return "Back / Share"
		6: return "Start / Options"
		9: return "LB / L1"
		10: return "RB / R1"
		11: return "D-Pad Cima"
		12: return "D-Pad Baixo"
		13: return "D-Pad Esquerda"
		14: return "D-Pad Direita"
		_: return "Botao %d" % button_index


func _legacy_joy_axis_name(axis: int, axis_value: float) -> String:
	var direction := "+" if axis_value >= 0.0 else "-"
	match axis:
		0: return "Analogico Esquerdo %sX" % direction
		1: return "Analogico Esquerdo %sY" % direction
		2: return "Analogico Direito %sX" % direction
		3: return "Analogico Direito %sY" % direction
		4: return "LT / L2"
		5: return "RT / R2"
		_: return "Eixo %d%s" % [axis, direction]
