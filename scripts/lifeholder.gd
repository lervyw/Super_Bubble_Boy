extends Control

@onready var life: TextureRect = $life

var life_size: int = 8  # Tamanho de cada unidade de vida visual

func on_life_changed(player_life: int) -> void:
	life.size = Vector2(player_life * life_size, life.size.y)
