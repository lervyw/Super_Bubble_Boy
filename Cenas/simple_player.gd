extends CharacterBody2D

@export var animation: AnimationPlayer
@export var animation_sprite: Sprite2D
@export var player_health:= 3
@export var max_health := 3

const SPEED = 160.0
const JUMP_VELOCITY = -400.0

var main_sm: LimboHSM
var direction
var respawn_position
var transformacaoOn: bool
var transformado: bool 
	

func _ready():
	initiate_state_machine()
	respawn_position = position

func _physics_process(delta: float):
	direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		main_sm.dispatch(&"to_jump")
	if Input.is_action_just_pressed("bolha") and transformacaoOn == true and transformado == false:
		main_sm.dispatch(&"transformar")
	flip_sprite(direction)
	move_and_slide()

func flip_sprite(direction):
	if direction == 1:
		animation_sprite.flip_h = false
	elif direction == -1:
		animation_sprite.flip_h = true

#func tranformar():
#	if Input.is_action_just_released("bolha") and transformacaoOn == true and transformado == false:
#		main_sm.dispatch(&"to_bolha")


func initiate_state_machine():
	main_sm = LimboHSM.new()
	add_child(main_sm)
	
	var idle_state = LimboState.new().named("idle").call_on_enter(idle_start).call_on_update(idle_update)
	var walk_state = LimboState.new().named("walk").call_on_enter(walk_start).call_on_update(walk_update)
	var jump_state = LimboState.new().named("jump").call_on_enter(jump_start).call_on_update(jump_update)
	var fall_state = LimboState.new().named("fall").call_on_enter(fall_start).call_on_update(fall_update)
	var bolha_state = LimboState.new().named("bolha").call_on_enter(bolha_start).call_on_update(bolha_update)

	
	main_sm.add_child(idle_state)
	main_sm.add_child(walk_state)
	main_sm.add_child(jump_state)
	main_sm.add_child(fall_state)
	main_sm.add_child(bolha_state)

	
	main_sm.initial_state = idle_state

	main_sm.add_transition(idle_state, walk_state, &"to_walk")
	main_sm.add_transition(main_sm.ANYSTATE, idle_state, &"state_ended")
	main_sm.add_transition(idle_state, jump_state, &"to_jump")	
	main_sm.add_transition(walk_state, jump_state, &"to_jump")
	main_sm.add_transition(walk_state, fall_state, &"to_fall")
	main_sm.add_transition(jump_state, fall_state, &"to_fall")
	main_sm.add_transition(main_sm.ANYSTATE, bolha_state, &"transformar")
	main_sm.add_transition(bolha_state, main_sm.ANYSTATE, &"destransformar")

		
	main_sm.initialize(self)
	main_sm.set_active(true)


func idle_start():
	animation.play("Idle")
	transformacaoOn = true
	transformado = false

func idle_update(delta: float):
			
	if velocity.x != 0:
		main_sm.dispatch(&"to_walk")
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		main_sm.dispatch(&"to_jump")
	if Input.is_action_just_pressed("bolha") and is_on_floor():
		main_sm.dispatch(&"transformar")

func walk_start():
	animation.play("Walk")
	print("tenis")
func walk_update(delta: float):
	if velocity.x == 0:
		main_sm.dispatch(&"state_ended")

func jump_start():
	velocity.y = JUMP_VELOCITY
	print("pulo")
	if velocity.y < 0:
		animation.play("Jump")
	
func jump_update(delta: float):
	if velocity.y > 0:
		main_sm.dispatch(&"to_fall")
	if Input.is_action_just_pressed("bolha") and is_on_floor():
		main_sm.dispatch(&"transformar")

func fall_start():
	animation.play("Fall")
	
func fall_update(delta: float):
	if is_on_floor():
		main_sm.dispatch(&"state_ended")

func bolha_start():
	animation.play("Transform")
	await animation.animation_finished
	print("paro")
	animation.play("Bubble_only")
	print("test")
	transformado = true
	transformacaoOn = false

func bolha_update(delta: float):
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		print("pulando")
		velocity.y = JUMP_VELOCITY
	if velocity.x != 0:
		print("andano")
	if Input.is_action_just_pressed("bolha") and transformado == true:
		animation.play("Transform2")
		await animation.animation_finished
		print("pica")
		main_sm.dispatch(&"state_ended")

	#	print(animation.current_animation)
	
func take_damage(amount: int): #metodo para o player levar dano
	
	knockback(direction)
	player_health -= 1
	print("o jogador está com: ", player_health, " Vidas")
	
	if player_health <= 0:
		die()
		
func knockback(direction: int) -> void:
	var knockback_force: Vector2
	if direction == 1:  # Se o personagem estiver olhando para a direita
		knockback_force = Vector2(-800, -800)  # Aplica o knockback para a esquerda (direção negativa)
	elif direction == -1:  # Se o personagem estiver olhando para a esquerda
		knockback_force = Vector2(800, -800)  # Aplica o knockback para a direita (direção positiva)
	# Adiciona a força de knockback à velocidade
	velocity += knockback_force
	move_and_slide()
	
func die() -> void:

	# Exibe um efeito visual ou som de morte, se necessário
	print("O jogador morreu") # Exemplo de mensagem para debug
	# Desativa o controle temporariamente
	set_physics_process(false)
	# Restaura a posição inicial ou posição de respawn
	position = respawn_position
	animation.play("Transform2")
	await animation.animation_finished
	# Reativa o controle
	set_physics_process(true)
