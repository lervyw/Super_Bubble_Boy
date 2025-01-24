extends CharacterBody2D

@export var animation: AnimationPlayer
@export var animation_sprite: Sprite2D

const SPEED = 160.0
const JUMP_VELOCITY = -400.0

var main_sm: LimboHSM
var direction
var respawn_position
	

func _ready():
	initiate_state_machine()
	respawn_position = position

func _physics_process(delta: float):
	direction = Input.get_axis("ui_left", "ui_right")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	#print(main_sm.get_active_state())
	# Add the gravity.
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		main_sm.dispatch(&"to_jump")

	if not is_on_floor():
		velocity += get_gravity() * delta
		#main_sm.dispatch(&"to_fall")
		
			
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	
	flip_sprite(direction)
	move_and_slide()

func flip_sprite(direction):
	if direction == 1:
		animation_sprite.flip_h = false
	elif direction == -1:
		animation_sprite.flip_h = true

func _unhandled_input(event):
#	if Input.is_action_just_pressed("up"):
#		main_sm.dispatch(&"to_jump")
	if event.is_action_released("attack"):
		main_sm.dispatch(&"to_attack")

func initiate_state_machine():
	main_sm = LimboHSM.new()
	add_child(main_sm)
	
	var idle_state = LimboState.new().named("idle").call_on_enter(idle_start).call_on_update(idle_update)
	var walk_state = LimboState.new().named("walk").call_on_enter(walk_start).call_on_update(walk_update)
	var jump_state = LimboState.new().named("jump").call_on_enter(jump_start).call_on_update(jump_update)
	var fall_state = LimboState.new().named("fall").call_on_enter(fall_start).call_on_update(fall_update)
	var attack_state = LimboState.new().named("attack").call_on_enter(attack_start).call_on_update(attack_update)
	
	main_sm.add_child(idle_state)
	main_sm.add_child(walk_state)
	main_sm.add_child(jump_state)
	main_sm.add_child(fall_state)
	main_sm.add_child(attack_state)
	
	main_sm.initial_state = idle_state

	main_sm.add_transition(idle_state, walk_state, &"to_walk")
	main_sm.add_transition(main_sm.ANYSTATE, idle_state, &"state_ended")
	main_sm.add_transition(idle_state, jump_state, &"to_jump")
	main_sm.add_transition(walk_state, jump_state, &"to_jump")
	main_sm.add_transition(walk_state, fall_state, &"to_fall")
	main_sm.add_transition(jump_state, fall_state, &"to_fall")
	main_sm.add_transition(main_sm.ANYSTATE, attack_state, &"to_attack")
		
	main_sm.initialize(self)
	main_sm.set_active(true)


func idle_start():
	animation.play("Idle")	
func idle_update(delta: float):
	if velocity.x != 0:
		main_sm.dispatch(&"to_walk")

func walk_start():
	animation.play("Walk")
func walk_update(delta: float):
	if velocity.x == 0:
		main_sm.dispatch(&"state_ended")

func jump_start():
	velocity.y = JUMP_VELOCITY
	if velocity.y < 0:
		animation.play("Jump")
		
func jump_update(delta: float):
	if velocity.y > 0:
		main_sm.dispatch(&"to_fall")
		
func fall_start():
	animation.play("Fall")
	
func fall_update(delta: float):
	if is_on_floor():
		main_sm.dispatch(&"state_ended")


func attack_start():
	animation.play("Transform")
	
func attack_update(delta: float):
	pass
	#direction = 1
	#if animation.current_animation != "Transform":
	#	main_sm.dispath(&"state_ended")
	#	print(animation.current_animation)
	
func die() -> void:
	# Exibe um efeito visual ou som de morte, se necessário
	print("O jogador morreu!") # Exemplo de mensagem para debug
	# Desativa o controle temporariamente
	set_physics_process(false)
	# Restaura a posição inicial ou posição de respawn
	position = respawn_position
	# Reativa o controle
	set_physics_process(true)
