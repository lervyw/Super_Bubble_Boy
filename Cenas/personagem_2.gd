extends CharacterBody2D
#personagem 
@onready var Player_sprite: Sprite2D = get_node("Textura2")
@export var nivel: Node
var speed: int = 100
var jump_speed: int = -320
var player_gravity: int = 600
@export var respawn_position: Vector2
@export var ambiente: AudioStreamPlayer
@export var opera: AudioStreamPlayer
var transformando: bool = false
var transformando_super: bool = false
var jump_count: int
var Pode_Bolha: bool
var Pode_Super: bool
var dead: bool = false
var on_hit: bool = false
func _ready() -> void:
	position.x = 350
	position.y = 219
func _physics_process(delta: float) -> void:

	trans()	
	tocar()
	vertical_moviment_env()
	horizontal_moviment_env()
	
	gravity(delta)
	move_and_slide()
	Player_sprite.animate(velocity)
	
func horizontal_moviment_env() -> void:
	var input_direction: float = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	velocity.x = input_direction * speed

func vertical_moviment_env() -> void:
	if is_on_floor()  :
		jump_count = 1
	if Input.is_action_just_pressed("ui_select") and jump_count < 2:
		if Player_sprite.estado == 1:
			velocity.y = jump_speed
		elif Player_sprite.estado == 0 or Player_sprite.estado ==2:
			jump_count += 1
			velocity.y = jump_speed
		
		
	#print(velocity)
	#print(velocity)
func trans() -> void:
	
	if Input.is_action_just_pressed("forma1") and not transformando and not transformando_super and not Player_sprite.transformacaoOn :
		transformando1()
		#set_physics_process(false)
	if Input.is_action_just_pressed("forma2") and not transformando and not transformando_super and not Player_sprite.transformacaoOn :
		transformando2()
		#set_physics_process(false)
		
		
func transformando1():
	
	if Player_sprite.estado == 0:
		
		transformando = true
		Player_sprite.transformacaoOn  = true	
		
		
	
	elif Player_sprite.estado == 1:
		#Player_sprite.animation.play("Transform2")

		transformando = true
		Player_sprite.transformacaoOn  = true	
		#Player_sprite.
		
	
	elif Player_sprite.estado == 2:
		#Player_sprite.animation.play("Transform4")
		transformando = true
		Player_sprite.transformacaoOn  = true	
		
			#Player_sprite.estado = 0
func transformando2():
	#var super_scene_instance = super_scene.
	if Player_sprite.estado == 1:
		#Player_sprite.animation.play("Transform3")
		transformando_super  = true
		transformando = true
		Player_sprite.transformacaoOn  = true	
		#Player_sprite.
		
	elif Player_sprite.estado == 0:
		#Player_sprite.animation.play("Transform3")
		transformando_super  = true
		transformando = true
		Player_sprite.transformacaoOn  = true	
		
	elif Player_sprite.estado == 2:
		transformando_super  = true
		transformando = true
		Player_sprite.transformacaoOn  = true	
		
	
	
	
	

func tocar():
	#var audio_player = AudioStreamPlayer.new()
	#audio_player.stream = music
	#get_parent().add_child(audio_player)

	if (Player_sprite.estado != 2):
		ambiente.stream_paused = false
		ambiente.autoplay
		ambiente.playing 	
		opera.stream_paused = true
	else:
		opera.stream_paused = false
		opera.autoplay
		opera.playing
		ambiente.stream_paused = true
		
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
	#position = respawn_position
	nivel.reset_scene()
	# Reativa o controle
	set_physics_process(true)

func delete():
	#Player_sprite.super_bubble.transform = self.transform
	Player_sprite.super_bubble.transform = self.transform
	get_parent().add_child(Player_sprite.super_bubble)
	#get_tree().root.add_child(Player_sprite.super_bubble)
	self.queue_free()

func knockback(direction: int = -1): # O parâmetro `direction` indica para onde o jogador será empurrado (-1 para esquerda, 1 para direita)
	var knockback_force: Vector2 = Vector2(direction * 800, -800) # Para trás na direção X e para cima na direção Y
	velocity += knockback_force # Adiciona a força de knockback à velocidade atual
	move_and_slide()
