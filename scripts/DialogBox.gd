extends Control

@onready var name_label = $Panel/Name
@onready var text_label = $Panel/Text
@onready var portrait = $Panel/Portrait
@onready var type_timer = $Timer

# Variáveis de controle
var full_text = ""
var displayed_text = ""
var text_speed = 0.03  # segundos por caractere
var typing = false
var dialog_index = 0
var dialogs = []  # lista de falas

func _ready():
	hide() # começa invisível
	type_timer.timeout.connect(_on_type_timer_timeout)

func start_dialog(_dialogs: Array):
	dialogs = _dialogs
	dialog_index = 0
	show()
	_show_current_dialog()

func _show_current_dialog():
	if dialog_index >= dialogs.size():
		hide()
		emit_signal("dialog_finished")
		return

	var dialog = dialogs[dialog_index]
	name_label.text = dialog.get("name", "")
	portrait.texture = load(dialog.get("portrait", ""))
	full_text = dialog.get("text", "")
	displayed_text = ""
	text_label.text = ""
	typing = true
	type_timer.start(text_speed)

func _on_type_timer_timeout():
	if typing:
		if displayed_text.length() < full_text.length():
			displayed_text += full_text[displayed_text.length()]
			text_label.text = displayed_text
		else:
			typing = false
			type_timer.stop()

func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		if typing:
			# Pula digitação
			typing = false
			text_label.text = full_text
			type_timer.stop()
		else:
			# Próximo diálogo
			dialog_index += 1
			_show_current_dialog()
