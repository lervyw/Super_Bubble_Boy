# Script do Sprite2D para animações
extends Sprite2D
@export var pai2: Node
@export var player: Node
@export var animation: AnimationPlayer
var transformacaoOn: bool
var estado: int =0
var form: String = "normal"  # Formas: "normal", "bubble"
var normal_bubble = preload("res://Cenas/personagem.tscn").instantiate()
#@export var super_scene: PackedScene

func animate(direction: Vector2) -> void:
	
	verify_position(direction)
	if player.transformando_super  == true:
		animation.play("Transform3")
	elif player.transformando and transformacaoOn and estado == 0 and not player.transformando_super:
		animation.play("Transform")
		#set_physics_process(false)

	
	elif  direction.y != 0 and estado == 0:
		vertical_behavior(direction)
	elif pai2.estado == 0:
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
		#animation.play("Transform2")
		player.transformando = false
		transformacaoOn  = false
	
	estado = 0
	player.speed = 100
	player.jump_speed = -320
	player.player_gravity = 600
	


   # if not super_scene:
  #      print_error("A cena Super_bubble.tscn não foi atribuída ao script!")
   #     return

	# Instancia a cena
   #var super_bubble = super_scene.instantiate()

	# Define a posição do novo nó para coincidir com a posição atual
   # super_bubble_instance.transform = self.transform

	# Adiciona à cena principal
	#get_tree().get_current_scene().add_child(super_bubble_instance)

func _on_animacao_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Walk":
			#print(player.form)
			pass
			
		"Transform":
			estado = 1
			animation.play("Bubble_only")
			transformacaoOn = false
			player.transformando = false
			#player.set_physics_process(true)

			
		"Transform2":	
			estado = 0
			voltar()	
			print(transformacaoOn)
			print(pai2.estado)
			#player.set_physics_process(true)
		"Transform3":
			print("penis")
			player.transformando_super = false
		
			player.delete()
			
			
			
			# _instantiate_super_bubble()
			#pass
		"Bubble_only":
			if (estado ==1):
				
				pass
		
