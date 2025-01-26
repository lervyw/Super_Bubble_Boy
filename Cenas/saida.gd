extends Area2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var spika: Sprite2D = $Spika


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_body_entered(body):
	if body.name == "Personagem2" && body.has_method("die"):
		body.die()
	
