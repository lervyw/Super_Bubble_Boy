extends Control

@export var ambiente: AudioStreamPlayer
@export var cena_inicial: PackedScene  # Arraste a cena aqui no inspetor

func _ready() -> void:
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_start"):
		_on_start_pressed()
	elif event.is_action_pressed("ui_select_input"):
		_on_quit_pressed()

func _on_start_pressed() -> void:
	if cena_inicial:
		get_tree().change_scene_to_packed(cena_inicial)
	else:
		push_error("Nenhuma cena inicial definida!")

func _on_quit_pressed() -> void:
	get_tree().quit()
