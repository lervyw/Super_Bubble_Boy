extends Node2D
func reset_scene():
	# Obtém o nome atual da cena
	var current_scene = get_tree().current_scene
	# Reinicia a cena carregando-a novamente
	get_tree().reload_current_scene()
