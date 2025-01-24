extends CharacterBody2D
#personagem
@onready var Player_sprite: Sprite2D = get_node("Textura")
@export var speed: int
@export var jump_speed: int
@export var player_gravity: int
@export var respawn_position: Vector2
#@onready var Super_Bubble = "res://Cenas/Super_bubble.tscn"
#@export var super_scene: Resource  # Aqui você associa "super.tscn" pelo editor
var estado: int =0
var transformando: bool = false
var transformando_super: bool
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
	print("esta transformando super: ",transformando_super)
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
		elif estado == 1:
			velocity.y = jump_speed
		
	#print(velocity)
	#print(velocity)
func trans() -> void:
	
	if Input.is_action_just_pressed("forma1") and not transformando and not transformando_super :
		transformando1()
		#set_physics_process(false)
	if Input.is_action_just_pressed("forma2") and not transformando :
		transformando2()
		#set_physics_process(false)
		
		
func transformando1():
	
	if estado == 1:
		Player_sprite.animation.play("Transform2")
		
		transformando = true
		Player_sprite.transformacaoOn  = true	
		#Player_sprite.
		estado = 0
	elif estado == 0:
		Player_sprite.animation.play("Transform")
		transformando = true
		Player_sprite.transformacaoOn  = true	
		estado = 1
			#Player_sprite.estado = 0
func transformando2():
	#var super_scene_instance = super_scene.
	transformando_super  = true
	if estado == 1:
		Player_sprite.animation.play("Transform3")
		#Player_sprite.
		estado = 3
	elif estado == 0 and transformando_super == true:
		Player_sprite.animation.play("Transform3")
		estado = 3
	#super_scene_instance.position = self.position
	#get_parent().add_child(super_scene_instance)
	#queue_free()
	#estado = 3
	#Player_sprite.animation.play("Transform3")
		#transformando = true
		#Player_sprite.transformacaoOn  = true	
		
		
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
