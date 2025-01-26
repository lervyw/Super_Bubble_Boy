extends Area2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var spika: Sprite2D = $Spika


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_body_entered(body):
<<<<<<< HEAD:Cenas/spikes_area.gd
	if body.name == "Personagem" && body.has_method("take_damage"):
		body.take_damage(1)
=======
	if body.name == "Personagem2" && body.has_method("die"):
		body.die()
>>>>>>> acc91df9c1a1af839379906b8c3a306ac663568f:Cenas/saida.gd
	
