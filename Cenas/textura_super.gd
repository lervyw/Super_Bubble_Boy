# Script do Sprite2D para animações
extends Sprite2D
@export var player: Node
@export var animation: AnimationPlayer
var transformacaoOn: bool
var estado: int =0
var form: String = "normal"  # Formas: "normal", "bubble"

func animate(direction: Vector2) -> void:
	
	verify_position(direction)
	
	if transformacaoOn and player.transformando and estado == 0:
		animation.play("Transform")
		estado = 1
	
	elif direction.y != 0 and estado == 0:
		vertical_behavior(direction)
	elif estado == 0:
		horizontal_behavior(direction)
	
	#
		
		
	if estado == 1 : 
		player.speed = 50
		player.jump_speed = -50
		player.player_gravity = 50			
		
		
	
		
		
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
	
	else :
		animation.play("Idle")

func vertical_behavior(direction: Vector2) -> void:
	if direction.y > 0 :
		animation.play("Fall")
	elif direction.y < 0 :
		animation.play("Jump")
		
		

func voltar():
	
	if 	player.transformando == true and transformacaoOn == true:
		animation.play("Transform2")
		player.transformando = false
		transformacaoOn  = false
		estado = 0
		player.speed = 100
		player.jump_speed = -320
		player.player_gravity = 600
	
func _on_animacao_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Walk":
			#print(player.form)
			pass
			
		"Transform":
			animation.play("Bubble_only")
			transformacaoOn = false
			player.transformando = false
			print(transformacaoOn)
			print(estado)
			
		"Transform2":	
			
			transformacaoOn = false
			player.transformando = false
			print(transformacaoOn)
			print(estado)
			
		
