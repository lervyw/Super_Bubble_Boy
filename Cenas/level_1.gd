extends Node2D
@export var player: Node
@export var inimigo: PackedScene
@export var status: Node
var enemies = 0
var target = 20
#var inimigo = preload("res://Cenas/slime.tscn").instantiate()

	# Gera 10 inimigos em posições aleatórias
func _ready() -> void:
	
	while enemies < target:
		enemies += 1
		spawn_enemy()
		await get_tree().create_timer(0.3).timeout
		
func spawn_enemy():
	#5500
	
	
	var random_x = randf_range(35,5500)
	var enemy_instance = inimigo.instantiate()
	add_child(enemy_instance)
	enemy_instance.position = Vector2(random_x, -654)
		
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
	
	status.update_helth("Decrease", 1)
	player.position.x = 288
	player.position.y = 207
	
	# Obtém o nome atual da cena
	if (player.dead):
		var current_scene = get_tree().current_scene
	# Reinicia a cena carregando-a novamente
		get_tree().reload_current_scene()
