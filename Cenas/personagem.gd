
extends CharacterBody2D

@onready var Player_sprite: Sprite2D = get_node("Textura")
@export var speed: int
@export var jump_speed: int
@export var player_gravity: int
var transformando: bool
var jump_count: int
var form: String = "normal"  # Formas: "normal", "bubble"

func _physics_process(delta: float) -> void:
	# Verifica se o botão para transformação foi pressionado
	if Input.is_action_just_pressed("ui_accept"):
		transformando = true
		transform()
		

	# Adiciona a gravidade e movimentação
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
		jump_count += 1
		velocity.y = jump_speed
	#print(velocity)

func gravity(delta: float) -> void:
	velocity.y += delta * player_gravity
	if velocity.y >= player_gravity:
		velocity.y = player_gravity

# Método de transformação
func transform() -> void:
	if form == "normal" and transformando == true:
		# Executa a animação de transformação para "bubble"
		Player_sprite.mudarforma()
		#Player_sprite.animation.play("Transform")
		
		#wait aPlayer_sprite.animation.animation_finished  # Aguarda a animação "Transform"
		
		# Muda para a forma "bubble" e ajusta as propriedades
		#form = "bubble"
		#speed = 150
		#jump_speed = -300
		#player_gravity = 800
		#Player_sprite.animation.play("Bubble_only")

	elif form == "bubble":
		# Executa a animação de transformação de volta para "normal"
		Player_sprite.animation.play("Transform2")
		await Player_sprite.animation.animation_finished  # Aguarda a animação "Transform2"
		
		# Volta para a forma "normal" e ajusta as propriedades
		form = "normal"
		speed = 200
		jump_speed = -400
		player_gravity = 1000
		Player_sprite.animation.play("Idle")
