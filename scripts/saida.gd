extends Area2D
@export var collision_shape_2d: CollisionShape2D
@export var spika: Sprite2D
@export var pai : Node

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_body_entered(body):
	if body.name == "Personagem2" && body.has_method("die"):
		pai.reset_scene()
	
