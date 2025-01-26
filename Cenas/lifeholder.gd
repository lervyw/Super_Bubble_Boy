extends Control

@onready var life: TextureRect = $life

var life_size: int = 8

# Chamado quando o nó entra na árvore da cena pela primeira vez.
func _ready() -> void:
	# Define o tamanho do TextureRect diretamente no Godot 4
	life.size = Vector2(3 * life_size, life.size.y)
