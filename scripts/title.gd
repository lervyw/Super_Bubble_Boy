extends Control

@export var ambiente: AudioStreamPlayer

func _ready() -> void:
	set_process_input(true)
	print("🎮 Menu Principal carregado")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_start"):
		_on_start_pressed()
	elif event.is_action_pressed("ui_select_input"):
		_on_quit_pressed()

func _on_start_pressed() -> void:
	print("▶️ Iniciando jogo...")
	#GameManager.goto_level1()
	GameManager.goto_cutscene()
func _on_quit_pressed() -> void:
	print("👋 Saindo do jogo...")
	get_tree().quit()
