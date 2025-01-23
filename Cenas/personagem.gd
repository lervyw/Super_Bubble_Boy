extends CharacterBody2D

@onready var Player_sprite: Sprite2D = get_node("Textura")
@export var speed: int
@export var jump_speed: int
@export var player_gravity: int
@export var respawn_position: Vector2
var transformando: bool
var jump_count: int

	

func _physics_process(delta: float) -> void:
	# Verifica se o botão para transformação foi pressionado
	# Player_sprite.trans()
	# Adiciona a gravidade e movimentação
	trans()	
	horizontal_moviment_env()
	vertical_moviment_env()
	gravity(delta)
	move_and_slide()
	Player_sprite.animate(velocity)
	

func horizontal_moviment_env() -> void:
	var input_direction: float = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	velocity.x = input_direction * speed

func vertical_moviment_env() -> void:
	if is_on_floor():
		jump_count = 1
	if Input.is_action_just_pressed("ui_select") and jump_count < 2:
		if Player_sprite.estado == 0:
			jump_count += 1
			velocity.y = jump_speed
		else:
			velocity.y = jump_speed
	#print(velocity)
func trans() -> void:
	#var cond: bool = not transformando
	
	if Input.is_action_just_pressed("ui_accept") and not transformando:
		transformando = true
		Player_sprite.transformacaoOn  = true
		if Player_sprite.transformacaoOn and transformando and Player_sprite.estado == 1:
			Player_sprite.voltar()
			#Player_sprite.estado = 0
			
			#Player_sprite.voltar()
		
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
