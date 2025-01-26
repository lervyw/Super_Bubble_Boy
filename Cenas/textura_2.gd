# Script do Sprite2D para animações
extends Sprite2D
@export var player: Node
@export var animation: AnimationPlayer
var transformacaoOn: bool
var estado: int =0
#var form: String = "normal"  # Formas: "normal", "bubble"
#@export var super_scene: PackedScene

func animate(direction: Vector2) -> void:
	
	verify_position(direction)
	if player.transformando_super  == true:
		animation.play("Transform3")
	elif player.transformando and transformacaoOn and estado == 0 and not player.transformando_super:
		animation.play("Transform")
		#set_physics_process(false)
	
	
	elif  direction.y != 0 and estado != 1:
		vertical_behavior(direction)
	elif estado != 1:
		horizontal_behavior(direction)
		
	
		
		
			
		
		
	
		
		
func verify_position(direction: Vector2) -> void:
	if direction.x > 0:
		flip_h = false
	elif direction.x < 0:
		flip_h = true

func horizontal_behavior(direction: Vector2) -> void:
	if(player.transformando_super == false and estado == 0):
		if direction.x != 0:
			animation.play("Walk")
		else :
			animation.play("Idle")
	if estado == 2:
		if direction.x != 0:
			animation.play("S_Walk")
		else :
			animation.play("S_Idle")
func vertical_behavior(direction: Vector2) -> void:
	if(estado == 0):
		if direction.y > 0 :
			animation.play("Fall")
		elif direction.y < 0 :
			animation.play("Jump")
	elif(estado == 2):
		if direction.y > 0 :
			animation.play("S_Fall")
		elif direction.y < 0 :
			animation.play("S_Jump")
		

func voltar():
	
	if 	player.transformando == true and transformacaoOn == true:
		
		player.transformando = false
		transformacaoOn  = false
	
	if(estado == 0):
		player.speed = 100
		player.jump_speed = -320
		player.player_gravity = 600
	elif(estado == 1):
		player.speed = 50
		player.jump_speed = -50
		player.player_gravity = 50	
	elif(estado == 2):
		player.speed = 100
		player.jump_speed = -320
		player.player_gravity = 600
	elif(estado == 2):
		estado = 0

func _on_animacao_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Walk":
		
			pass
			
		"Transform":
			estado = 1
			animation.play("Bubble_only")
			voltar()	
			

			
		"Transform2":	
			estado = 0
			voltar()	
			print(transformacaoOn)
			print(estado)
			
		"Transform3":
			estado = 2
			voltar()	
			player.transformando_super = false
			
			print("penis")
			
			# _instantiate_super_bubble()
			#pass
		"Bubble_only":
			if (estado ==1):
				
				pass
		
