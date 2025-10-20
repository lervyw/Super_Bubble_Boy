extends Control
@export var ambiente: AudioStreamPlayer

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Cenas/intro.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
