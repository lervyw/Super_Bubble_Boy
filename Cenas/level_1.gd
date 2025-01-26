extends Node2D
@export var player: Node
func reset_scene():
	player.position.x = 288
	player.position.y = 207
	# Obtém o nome atual da cena
	if (player.dead):
		var current_scene = get_tree().current_scene
	# Reinicia a cena carregando-a novamente
		get_tree().reload_current_scene()
