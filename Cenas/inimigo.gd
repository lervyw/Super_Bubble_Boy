extends CharacterBody2D

@export var speed: float = 100.0 # Velocidade de movimento
@export var move_range: float = 200.0 # Distância máxima que o inimigo percorre em cada direção
@export var start_direction: int = 1 # Direção inicial (1 = direita, -1 = esquerda)

var start_position: Vector2
var direction: int

func _ready() -> void:
	# Salva a posição inicial e define a direção inicial
	start_position = position
	direction = start_direction

func _physics_process(delta: float) -> void:
	# Movimenta o inimigo na direção atual
	velocity.x = direction * speed
	move_and_slide()

	# Verifica se o inimigo atingiu os limites do movimento
	if abs(position.x - start_position.x) >= move_range:
		direction *= -1 # Inverte a direção
