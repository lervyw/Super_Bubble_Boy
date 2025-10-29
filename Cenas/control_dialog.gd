# Control.gd
extends Control

@export var DialogBox: RichTextLabel
@export var dialogs: Array[String] = [
	"Bom dia.",
	"Eu estou devendo muit imposto.",
	"A faço a conta fica aonde?."
]

var current_dialog_index: int = 0

func _ready():
	if dialogs.size() > 0:
		DialogBox.set_dialog(dialogs[current_dialog_index])

func _input(event):
	# Detecta clique do mouse ou tecla de ação
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		advance_dialog()

func advance_dialog():
	# Se ainda está exibindo, pula para o final
	if DialogBox.is_displaying:
		DialogBox.skip_dialog()
		return
	
	# Se pode avançar, vai para o próximo diálogo
	if DialogBox.is_ready_to_advance():
		current_dialog_index += 1
		
		if current_dialog_index < dialogs.size():
			DialogBox.set_dialog(dialogs[current_dialog_index])
		else:
			# Terminou todos os diálogos
			on_dialogs_finished()

func on_dialogs_finished():
	# Aqui você pode adicionar o que acontece quando terminar todos os diálogos
	print("Todos os diálogos foram exibidos!")
	# Exemplos:
	# queue_free()  # Remove o diálogo
	# visible = false  # Esconde o diálogo
	# get_tree().change_scene_to_file("res://proxima_cena.tscn")  # Muda de cena
