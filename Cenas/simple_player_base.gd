extends CharacterBody2D

@export var animation: AnimationPlayer
@export var animation_sprite: Sprite2D
@export var player_health:= 3 #vida do player
@export var max_health := 3 #vida maxima
#var is_invincible: bool = false


const SPEED = 160.0
const JUMP_VELOCITY = -400.0
@onready var life_bubbles: HBoxContainer = $HUD/HBoxContainer  # Referência ao container das bolhas

var main_sm: LimboHSM
var direction
var respawn_position
var transformacaoOn: bool
var transformado: bool 

signal change_life(player_health) #sinalizador de mundança de vida do player

func _ready():
	var hud = get_parent().get_node("HUD") #muita 
	connect("change_life", Callable(hud, "on_life_changed"))# porra
	emit_signal("change_life", max_health) # pro caraio do HUD
	
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
	print("walk_start")
func walk_update(delta: float):
	if velocity.x == 0:
		main_sm.dispatch(&"state_ended")

func jump_start():
	velocity.y = JUMP_VELOCITY
	print("jump_start")
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
	print("bolha_start")
	animation.play("Bubble_only")
	transformado = true
	transformacaoOn = false
	print("transformado:true transformacaoOn: false")

func bolha_update(delta: float):
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		print("bolha update")
		velocity.y = JUMP_VELOCITY
	if velocity.x != 0:
		print("bolha update walk")
	if Input.is_action_just_pressed("bolha") and transformado == true:
		animation.play("Transform2")
		await animation.animation_finished
		print("bolha update transform2")
		main_sm.dispatch(&"state_ended")

	#	print(animation.current_animation)

func die() -> void: # metodo de morte do player
	print("o jogador mamou")
	set_physics_process(false)
	position = respawn_position
	animation.play("Transform2")
	await animation.animation_finished
	set_physics_process(true)
	
func take_damage(amount: int): #metodo para o player levar dano
	#if is_invencible = false
	#	return
	player_health -= 1
	print("o jogador está com: ", player_health, " Vidas")
	emit_signal("change_life", player_health)
	#knockback()
	if player_health <= 0:
		die()
	
#func knockback():
	#var knockback_force: Vector2 = Vector2(-200, 200)
	#velocity = knockback_force
	#move_and_slide()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		#queue_free()
		pass
