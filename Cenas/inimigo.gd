extends CharacterBody2D

@export var speed: float = 100.0 # Velocidade de movimento
@export var move_range: float = 200.0 # Distância máxima de movimento em cada direção
@export var jump_force: float = -320.0 # Força do pulo
@export var gravity: float = 800.0 # Gravidade aplicada ao inimigo
@export var jump_interval: float = 2.0 # Intervalo entre os pulos, em segundos
@export var start_direction: int = 1 # Direção inicial (1 = direita, -1 = esquerda)

var start_position: Vector2
var direction: int
var jump_timer: float = 0.0

func _ready() -> void:
	# Salva a posição inicial e define a direção inicial
	start_position = position
	direction = start_direction

func _physics_process(delta: float) -> void:
	# Aplica gravidade
	velocity.y += gravity * delta

	# Movimenta o inimigo horizontalmente
	velocity.x = direction * speed

	# Faz o inimigo pular em intervalos regulares
	jump_timer += delta
	if jump_timer >= jump_interval and is_on_floor():
		velocity.y = jump_force
		jump_timer = 0.0

	# Move o inimigo
	move_and_slide()

	# Verifica se o inimigo atingiu os limites de movimento
	if abs(position.x - start_position.x) >= move_range:
		direction *= -1 # Inverte a direção
