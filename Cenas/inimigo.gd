extends State
class_name EnemyWalks

@export var enemy: CharacterBody2D
@export var speed: float = 100.0 # Velocidade de movimento
<<<<<<< HEAD
@export var move_range: float = 200.0 # Distância máxima de movimento em cada direção
@export var jump_force: float = -320.0 # Força do pulo
@export var gravity: float = 800.0 # Gravidade aplicada ao inimigo
@export var jump_interval: float = 2.0 # Intervalo entre os pulos, em segundos
=======
@export var move_range: float = 200.0 # Distância máxima que o inimigo percorre em cada direção
<<<<<<< HEAD
@export var start_direction: bool = true # Direção inicial (true = direita, false = esquerda)
=======
>>>>>>> 6f4102253283f33cafed42a1da30d88bcbca92f1
@export var start_direction: int = 1 # Direção inicial (1 = direita, -1 = esquerda)
@export var move_speed := 40.0
>>>>>>> 5cf4346c84676ec90ecb3a3455c361702391946a

var player: CharacterBody2D
var start_position: Vector2
var direction: int
var jump_timer: float = 0.0

func _ready() -> void:
<<<<<<< HEAD
	# Salva a posição inicial e define a direção inicial com base no bool
	start_position = position
	direction = 1 if start_direction else -1
=======
	# Salva a posição inicial e define a direção inicial
	start_position = enemy.position
	direction = start_direction
>>>>>>> 5cf4346c84676ec90ecb3a3455c361702391946a

func _physics_process(delta: float) -> void:
<<<<<<< HEAD
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
=======
	pass
	# Movimenta o inimigo na direção atual
	#move_and_slide()
	#velocity.x = direction * speed

	# Verifica se o inimigo atingiu os limites do movimento
	#if abs(position.x - start_position.x) >= move_range:
	#	direction *= -1 # Inverte a direção

func Enter():
	player = get_tree().get_first_node_in_group("Player")
	

func Physic_Update(delta: float):
	var direction = player.global_position - enemy.global_position

	if direction.lenght() > 25:
		enemy.velocity = direction.normalize() * move_speed
	else:
		enemy.velocity = Vector2()
	
	if direction.lenght() > 50:
		Transitioned.emit(self, "Idle")
>>>>>>> 6f4102253283f33cafed42a1da30d88bcbca92f1
