extends Node2D
@export var player_normal: Node
@export var player_super: Node
var estado: int = 0
var super_bubble = preload("res://Cenas/Super_bubble.tscn").instantiate()
func iniciar():
	if estado != 3:
		#player_super.visible = false
		pass
func mudar():
	
	super_bubble.transform = player_normal.transform
	#add_child(super_bubble)
	add_child(super_bubble)
	player_normal.queue_free()
	
