extends CharacterBody2D
#script pro personagem, interage com outros scripts e mexe com a fisica do personagem
@onready var Player_sprite: Sprite2D = get_node("Textura2") #cria um objeto no Nó Textura2, onde o script de Textura altera as animações
@export var nivel: Node #cria um objeto no Nó nível
@export var ambiente: AudioStreamPlayer
@export var opera: AudioStreamPlayer
@export var hud: CanvasLayer

@export var attack_area: Area2D
@export var attack_shape: CollisionShape2D

var facing_right = true

var speed: int = 150 #variavel de velocidade do personagem
var jump_speed: int = -320 # força pra levar pra cima
var player_gravity: int = 400#gravidade normal
var transformando: bool = false #variavel para transformaçao nao loopar
var transformando_super: bool = false #variavel para transformaçao nao loopar
var jump_count: int #limitador de pulo
var Pode_Bolha: bool = false
var Pode_Super: bool = false
var dead: bool = false
var on_hit: bool = false
var attacking: bool = false
var parry: bool = false
var crouching: bool = false
var pode_abaixar: bool = true
var dash: bool = false


func _ready() -> void:
	#position.x = 350
	#position.y = 219
	ambiente.autoplay
	ambiente.playing
	opera.stream_paused = true
	attack_area.monitoring = false
	attack_shape.disabled = true

	
func _physics_process(delta: float) -> void: #main
	#print(attacking, " ",crouching," ", dash)
	
	action()	
	tocar()
	vertical_moviment_env()
	horizontal_moviment_env()
	
	gravity(delta)
	move_and_slide()
	Player_sprite.animate(velocity)
	
func horizontal_moviment_env() -> void:
	var input_direction: float = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	if Player_sprite.estado == 0 and dash:
		velocity.x = input_direction * speed * 2                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
	elif (not crouching ):
		velocity.x = input_direction * speed
	elif crouching:
		velocity.x = 0

func vertical_moviment_env() -> void:
	if is_on_floor()  :
		jump_count = 1
	if Input.is_action_just_pressed("ui_select") and not crouching:
		if Player_sprite.estado == 1 :
			velocity.y = jump_speed
			
		elif Player_sprite.estado != 1 and jump_count < 2:
			jump_count += 1
			velocity.y = jump_speed
		
			
func action() -> void:

	if Input.is_action_just_pressed("dash") and Player_sprite.estado == 0 and velocity.x != 0:
		dash = true
	if Input.is_action_pressed("up") and Input.is_action_just_pressed("attack"):
		parry = true
	if Input.is_action_pressed("down") and is_on_floor() and not attacking and not crouching and Player_sprite.estado != 1:
		crouching = true 
		pode_abaixar = false
		
	elif not Input.is_action_pressed("down") :
		crouching = false
		pode_abaixar = true
		Player_sprite.crouch_off = true
		
		
		
	if Input.is_action_just_pressed("attack") and not attacking and not crouching and is_on_floor() and Player_sprite.estado != 1:
		#attacking = true
		attack()
		#set_physics_process(false)
		
	
	if Input.is_action_just_pressed("forma1") and not transformando and Pode_Bolha == true :
		
		transformando = true
		set_physics_process(false)
		
	if Input.is_action_just_pressed("forma2") and not transformando and not transformando_super and Pode_Super == true :
		
		transformando_super  = true
		transformando = true
		set_physics_process(false)

func tocar():

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

func knockback():
	var direction = 1 if Player_sprite.flip_h else -1
	var knockback_distance = 50  # distância em pixels
	var knockback_duration = 0.2  # tempo em segundos
	
	var target_position = global_position + Vector2(direction * knockback_distance, -10)  # leve flutuação para cima
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_position, knockback_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	
func attack() -> void:
	attacking = true
	# Pausa controle, mas NÃO pausa a física inteira
	set_process_input(false)
	
	# Ativa a área de ataque
	attack_area.monitoring = true
	attack_shape.disabled = false
	
	# Toca animação (se houver)
	if Player_sprite.has_method("play"):
		Player_sprite.play("attack")
	
	# Duração do ataque (em segundos)
	await get_tree().create_timer(0.3).timeout
	
	# Desativa a área novamente
	attack_area.monitoring = false
	attack_shape.disabled = true
	
	# Libera o controle
	set_process_input(true)
	attacking = false
