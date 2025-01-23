extends CharacterBody2D

@export var speed: float = 100.0 # Velocidade de movimento
@export var move_range: float = 200.0 # Distância máxima que o inimigo percorre em cada direção
@export var start_direction: bool = true # Direção inicial (true = direita, false = esquerda)

var start_position: Vector2
var direction: int

func _ready() -> void:
	# Salva a posição inicial e define a direção inicial com base no bool
	start_position = position
	direction = 1 if start_direction else -1

func _physics_process(delta: float) -> void:
	# Movimenta o inimigo na direção atual
	velocity.x = direction * speed
	move_and_slide()

	# Verifica se o inimigo atingiu os limites do movimento
	if abs(position.x - start_position.x) >= move_range:
		direction *= -1 # Inverte a direção
