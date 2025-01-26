extends Area2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var spika: Sprite2D = $Spika
@export var animation: AnimationPlayer

# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#collision_shape_2d.shape.size = spika.get_rect().size


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_body_entered(body):
<<<<<<< HEAD
	if body.name == "Personagem2" && body.has_method("die"):
=======
	if body.name == "Player" && body.has_method("die"):
>>>>>>> 04249abbcc840472d86577cb4db29bb062f21f96
		body.die()
	
