extends Control

@onready var slider_master = $VBoxContainer/VolumeMaster/HSlider
@onready var slider_music = $VBoxContainer/VolumeMusic/HSlider
@onready var slider_sfx = $VBoxContainer/VolumeSFX/HSlider
@onready var btn_voltar = $VBoxContainer/Voltar

var awaiting_action := ""
const JOYPAD_AXIS_REBIND_THRESHOLD: float = 0.55


func _ready():
	# Carrega valores atuais
	slider_master.value = ConfigManager.get_volume("master")
	slider_music.value = ConfigManager.get_volume("music")
	slider_sfx.value = ConfigManager.get_volume("sfx")

	# Conectar sliders
	slider_master.value_changed.connect(func(val): ConfigManager.set_volume("master", val))
	slider_music.value_changed.connect(func(val): ConfigManager.set_volume("music", val))
	slider_sfx.value_changed.connect(func(val): ConfigManager.set_volume("sfx", val))

	# Conectar botões de rebind
	_connect_rebind_button("Pular", "player_jump")
	_connect_rebind_button("Dash", "player_dash")
	_connect_rebind_button("Transformar", "player_transform")

	btn_voltar.pressed.connect(_on_voltar)


# =========================================
#              REBIND AÇÕES
# =========================================
func _connect_rebind_button(container_name: String, action_name: String):
	var container := $VBoxContainer.get_node(container_name)
	var button := container.get_child(1)
	button.pressed.connect(func(): _start_rebind(action_name))

func _start_rebind(action_name: String):
	awaiting_action = action_name
	print("Pressione uma tecla ou botão para:", action_name)


func _input(event):
	if awaiting_action == "":
		return

	if event is InputEventKey and event.pressed:
		ConfigManager.rebind_action(awaiting_action, event)
		print("Ação", awaiting_action, "→", event.physical_keycode)
		awaiting_action = ""
		accept_event()

	elif event is InputEventJoypadButton and event.pressed:
		ConfigManager.rebind_action(awaiting_action, event)
		print("Ação", awaiting_action, "→", event.button_index)
		awaiting_action = ""
		accept_event()

	elif event is InputEventJoypadMotion and absf(event.axis_value) >= JOYPAD_AXIS_REBIND_THRESHOLD:
		var joy_event := event.duplicate() as InputEventJoypadMotion
		joy_event.axis_value = 1.0 if event.axis_value > 0.0 else -1.0
		ConfigManager.rebind_action(awaiting_action, joy_event)
		print("Ação", awaiting_action, "→ eixo", joy_event.axis, joy_event.axis_value)
		awaiting_action = ""
		accept_event()


# =========================================
#                 VOLTAR
# =========================================
func _on_voltar():
	queue_free()

	# Reexibir menu principal (caso esteja na mesma cena)
	var menu = get_tree().current_scene.get_node_or_null("MenuPrincipal")
	if menu:
		menu.show()
