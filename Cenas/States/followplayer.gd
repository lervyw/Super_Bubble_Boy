extends State
class_name EnemyFollow

@export var enemy: CharacterBody2D
@export var move_speed := 40.0
@export var direction : float
var player: CharacterBody2D


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
