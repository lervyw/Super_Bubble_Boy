extends Node2D
@export var player: Node
var inimigo = preload("res://Cenas/slime.tscn").instantiate()

	# Gera 10 inimigos em posições aleatórias
func _ready() -> void:
	pass
	for i in range(100):
		spawn_enemy()
		
		
		
func spawn_enemy():
	#5500
	var enemy_instance = inimigo
	var random_x = randf_range(35,200)
	inimigo.position = Vector2(random_x, -609)
	add_child(inimigo)
	#print ("inimigo pica")

	#var enemy_instance = inimigo
	
	
	# Define uma posição aleatória no intervalo especificado
	#var random_x = rand_range(35, 5500)
	#enemy_instance.position = Vector2(random_x, -609)
	
	# Adiciona o inimigo como filho deste nó
		
		
		
func reset_scene():
	#inimigo.transform = self.transform
	#get_parent().add_child(Player_sprite.super_bubble)
	#get_tree().root.add_child(Player_sprite.super_bubble)
	#self.queue_free()
	
		
	player.position.x = 288
	player.position.y = 207
	
	# Obtém o nome atual da cena
	if (player.dead):
		var current_scene = get_tree().current_scene
	# Reinicia a cena carregando-a novamente
		get_tree().reload_current_scene()
