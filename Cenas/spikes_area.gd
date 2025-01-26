extends Area2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var spika: Sprite2D = $Spika
@export var animation: AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	collision_shape_2d.shape.size = spika.get_rect().size


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_body_entered(body):
	if body.name == "Personagem" && body.has_method("take_damage"):
		body.take_damage(1)
	
