extends Node2D
@export var player_normal: Node
@export var player_super: Node
var estado: int = 0
const SUPER_BUBBLE_SCENE_PATH := "res://Cenas/Super_bubble.tscn"
var super_bubble: Node = null

func iniciar():
	if estado != 3:
		#player_super.visible = false
		pass
func mudar():
	if super_bubble == null:
		var scene: PackedScene = null
		if ResourceLoader.exists(SUPER_BUBBLE_SCENE_PATH):
			scene = load(SUPER_BUBBLE_SCENE_PATH) as PackedScene
		if scene == null:
			push_warning("Cena legada nao encontrada: %s" % SUPER_BUBBLE_SCENE_PATH)
			return
		super_bubble = scene.instantiate()
	super_bubble.transform = player_normal.transform
	#add_child(super_bubble)
	add_child(super_bubble)
	player_normal.queue_free()
	
