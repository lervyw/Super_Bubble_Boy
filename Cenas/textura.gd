# Script do Sprite2D para animações
extends Sprite2D
@export var player: Node
@export var animation: AnimationPlayer
var transformacaoOn: bool
var form: String = "normal"  # Formas: "normal", "bubble"

func animate(direction: Vector2) -> void:
	
	verify_position(direction)
	if transformacaoOn :
		animation.play("Transform")
		
	elif direction.y != 0:
		vertical_behavior(direction)
	else:
		horizontal_behavior(direction)

func verify_position(direction: Vector2) -> void:
	if direction.x > 0:
		flip_h = false
	elif direction.x < 0:
		flip_h = true

func horizontal_behavior(direction: Vector2) -> void:
	if player.transformando:
		animation.play("Transform")
		
	if direction.x != 0:
		animation.play("Walk")
	
	else:
		animation.play("Idle")

func vertical_behavior(direction: Vector2) -> void:
	if direction.y > 0:
		animation.play("Fall")
	elif direction.y < 0:
		animation.play("Jump")

#func mudarforma():
	
	
	#await animation.animation_finished 
#func trans() -> void:
#	if Input.is_action_just_pressed("ui_accept"):
#		transformando = true
#		if form == "normal" and transformando == true:
		# Executa a animação de transformação para "bubble"
#			transformando = false
			
			
	#player.set_physics_process(false)
#			_on_animacao_animation_finished("Transform")
		#Player_sprite.animation.play("Transform")
			
		#wait aPlayer_sprite.animation.animation_finished  # Aguarda a animação "Transform"
		
		# Muda para a forma "bubble" e ajusta as propriedades
		#form = "bubble"
		#speed = 150
		#jump_speed = -300
		#player_gravity = 800
		#Player_sprite.animation.play("Bubble_only")

		
#		elif form == "bubble" and transformando == true:
		# Executa a animação de transformação de volta para "normal"
#			animation.play("Transform2")
			#await Player_sprite.animation.animation_finished  # Aguarda a animação "Transform2"
		
		# Volta para a forma "normal" e ajusta as propriedades
#			form = "normal"
		#	speed = 200
		#	jump_speed = -400
		#	player_gravity = 1000
		#	Player_sprite.animation.play("Idle")
	
func _on_animacao_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Walk":
			#print(player.form)
			pass
			
		"Transform":
			print(form)
			transformacaoOn = false
			player.transformando = false
			#transformando = false # Replace with function body.
		
