extends CharacterBody2D

@onready var Player_sprite: Sprite2D = get_node("Textura")
@export var speed: int
@export var jump_speed: int
@export var player_gravity: int
@export var respawn_position: Vector2
#@onready var Super_Bubble = "res://Cenas/Super_bubble.tscn"
@onready var Super_Bubble_scene: PackedScene = preload("res://Cenas/Super_bubble.tscn")
@export var super_scene: Resource  # Aqui você associa "super.tscn" pelo editor
var estado: int =0
var transformando: bool = false
var jump_count: int


func _physics_process(delta: float) -> void:
	trans()	
	horizontal_moviment_env()
	vertical_moviment_env()
	gravity(delta)
	move_and_slide()
	Player_sprite.animate(velocity)
	print("estado: ", Player_sprite.estado)
	print("esta transformando em tex: ", Player_sprite.transformacaoOn)
	print("esta transformando em player: ",transformando, "\n")
func horizontal_moviment_env() -> void:
	var input_direction: float = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	velocity.x = input_direction * speed

func vertical_moviment_env() -> void:
	if is_on_floor():
		jump_count = 1
	if Input.is_action_just_pressed("ui_select") and jump_count < 2:
		if estado == 0:
			jump_count += 1
			velocity.y = jump_speed
		else:
			velocity.y = jump_speed
	#print(velocity)
	#print(velocity)
func trans() -> void:
	
	if Input.is_action_just_pressed("forma1") and not transformando :
		transformando1()
		
	if Input.is_action_just_pressed("forma2") and not transformando :
		transformando2()
		transformando = true
		
		
func transformando1():
	
	if estado == 1:
		Player_sprite.voltar()
	elif estado == 0:
		transformando = true
		Player_sprite.transformacaoOn  = true	
			#Player_sprite.estado = 0
func transformando2():
	pass
func voltar():
	
	if 	transformando == true and Player_sprite.transformacaoOn == true:
		Player_sprite.animation.play("Transform2")
		transformando = false
		Player_sprite.transformacaoOn  = false
		estado = 0
		speed = 100
		jump_speed = -320
		player_gravity = 600	
	
		
func gravity(delta: float) -> void:
	velocity.y += delta * player_gravity
	if velocity.y >= player_gravity:
		velocity.y = player_gravity

# Método de transformação

func die() -> void:
	# Exibe um efeito visual ou som de morte, se necessário
	print("O jogador morreu!") # Exemplo de mensagem para debug
	# Desativa o controle temporariamente
	set_physics_process(false)
	# Restaura a posição inicial ou posição de respawn
	position = respawn_position
	# Reativa o controle
	set_physics_process(true)




#func _on_animation_finished(anim_name: StringName) -> void:
#	if (anim_name == "Walk"):
###		print("gay")
#		pass # Replace with function body.
