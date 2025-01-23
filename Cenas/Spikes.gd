extends Area2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var spike: Sprite2D = $Spike


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	collision_shape_2d.shape.size = spike.get_rect().size

func _on_body_entered(body: Node2D) -> void:
	# Verifica se o corpo que entrou é o jogador e se ele tem o método 'die'
	if body.name == "Personagem" and body.has_method("die"):
		# Chama o método 'die' no jogador
		body.die()
