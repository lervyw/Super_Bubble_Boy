extends State
class_name EnemyWalks

@export var enemy: CharacterBody2D
@export var speed: float = 100.0 # Velocidade de movimento
@export var move_range: float = 200.0 # Distância máxima que o inimigo percorre em cada direção
@export var start_direction: int = 1 # Direção inicial (1 = direita, -1 = esquerda)
@export var move_speed := 40.0

var player: CharacterBody2D
var start_position: Vector2
var direction: int

func _ready() -> void:
	# Salva a posição inicial e define a direção inicial
	start_position = enemy.position
	direction = start_direction

func _physics_process(delta: float) -> void:
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
