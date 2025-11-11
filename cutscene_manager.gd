extends Node

@onready var dialog_box = $"../DialogBox"
@onready var player = $"../Player" # opcional, caso queira pausar o controle

var cutscene_playing = false

func _ready():
	# Exemplo: inicia a cutscene de introdução automaticamente
	play_cutscene("intro")
	
func play_cutscene(name: String):
	cutscene_playing = true
	if player:
		player.set_process_input(false)

	match name:
		"intro":
			var dialogs = [
				{
					"name": "Hana",
					"text": "Bem-vindo ao Vale da Lua. O vento sopra diferente hoje...",
					"portrait": "res://assets/portraits/hana.png"
				},
				{
					"name": "Protagonista",
					"text": "Eu senti isso também. Parece que algo está para acontecer.",
					"portrait": "res://assets/portraits/player.png"
				},
				{
					"name": "Hana",
					"text": "Fique atento. Nem tudo aqui é o que parece...",
					"portrait": "res://assets/portraits/hana.png"
				}
			]
			dialog_box.start_dialog(dialogs)
	
	# Quando terminar a cutscene
	dialog_box.connect("dialog_finished", Callable(self, "_on_dialog_finished"))

func _on_dialog_finished():
	cutscene_playing = false
	if player:
		player.set_process_input(true)
