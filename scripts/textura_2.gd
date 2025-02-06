# Script do Sprite2D para animações
extends Sprite2D
@export var player: Node
@export var animation: AnimationPlayer
@export var stats: Node
@export var nivel: Node
var transformacaoOn: bool
var estado : int 
var crouch_off: bool = false
#var form: String = "normal"  # Formas: "normal", "bubble"
#@export var super_scene: PackedScene

func animate(direction: Vector2) -> void:
	
	verify_position(direction)
	
	
	
	
	if player.on_hit or player.dead:
		hit_behavior()
	elif player.dash :
		animation.play("dash")
	elif player.transformando and not player.transformando_super and estado == 0:
		animation.play("Normal_Bolha")
		
	elif player.transformando and player.transformando_super and estado == 0 :
		animation.play("Normal_Super")	##
		
	elif player.transformando and not player.transformando_super and estado == 1 :
		animation.play("Bolha_Normal")#
		
	elif player.transformando and  player.transformando_super and estado == 1:
		animation.play("Bolha_Super")#
		
	elif player.transformando   and not player.transformando_super and estado == 2:
		animation.play("Super_Bolha")
		
	elif player.transformando   and  player.transformando_super and estado == 2:
		animation.play("Super_Normal")
		
	elif player.parry and estado == 2:
		animation.play("S_parry")
		
	elif player.attacking and estado == 2:
		animation.play("S_attack")
		
	elif player.attacking and estado == 0:
		animation.play("T_attack")
		
	elif player.crouching and player.is_on_floor()  and estado == 0:
		
		animation.play("N_c_loop")
		#player.set_physics_process(false)
		crouch_off = false
		
	elif player.crouching  and estado == 2:
		crouch_off = false
		animation.play("S_crouch")
		
		
	elif  direction.y != 0 and estado != 1:
		vertical_behavior(direction)
	elif estado != 1:
		horizontal_behavior(direction)
		
func transform():
	pass
func hit_behavior():
	#quando tiver a animaçao de super  trocar as animaçoes para S_Hit
	player.set_physics_process(false)
	if player.dead and estado == 0:
		animation.play("Dead_normal")
	elif player.dead and estado == 2:
		animation.play("S_dead")
	elif player.dead and estado== 1:
		animation.play("B_dead")
	elif player.on_hit and estado ==0 :
		animation.play("Hit")
	elif player.on_hit and estado == 1:
		animation.play("Hit_Bolha")
	elif player.on_hit and estado == 2:
		animation.play("Hit_Super")
			
		
		
	
		
		
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
	
	if 	player.transformando == true:
		player.transformando = false
		

		
	if player.transformando_super == true:
		player.transformando_super = false
		
		
	if(estado == 0):
		player.speed = 150
		player.jump_speed = -320
		player.player_gravity = 400
	elif(estado == 1):
		player.speed = 50
		player.jump_speed = -50
		player.player_gravity = 50	
	elif(estado == 2):
		player.speed = 100
		player.jump_speed = -420
		player.player_gravity = 600
	

func _on_animacao_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Walk":
		
			pass
			
		"Normal_Bolha":
			estado = 1
			animation.play("Bubble_only")
			voltar()			
			player.set_physics_process(true)
		"Normal_Super":
			estado = 2
			voltar()	
			player.transformando_super = false	
			player.set_physics_process(true)
		"Bolha_Normal":			
			estado = 0
			voltar()	
			player.set_physics_process(true)
		"Bolha_Super":			
			estado = 2
			voltar()
			player.set_physics_process(true)
		"Super_Normal":
			estado = 0
			voltar()	
			player.transformando_super = false
			player.set_physics_process(true)
		"Super_Bolha":
			estado = 1
			animation.play("Bubble_only")
			voltar()	
			player.transformando_super = false
			player.set_physics_process(true)
		"Bubble_only":
			if (estado ==1):
				
				pass
		"Hit":
			player.on_hit = false
			player.set_physics_process(true)
			
		"Dead_normal":
#			nivel.reset_scene()
			get_tree().reload_current_scene()
		"Hit_Bolha":
			player.on_hit = false
			player.set_physics_process(true)
			animation.play("Bubble_only")
		"Hit_Super":
			player.on_hit = false
			player.set_physics_process(true)
		"S_dead":
#			nivel.reset_scene()
			get_tree().reload_current_scene()
		"B_dead":
#			nivel.reset_scene()
			get_tree().reload_current_scene()
		"T_attack":
			player.attacking = false
			player.set_physics_process(true)
		"S_attack":
			player.set_physics_process(true)
			player.attacking = false
		"S_parry":
			player.set_physics_process(true)
			player.parry = false
			player.attacking = false
		"dash":
			player.set_physics_process(true)
			player.dash = false
		#"Normal_crouch":
		#	set_physics_process(false)
		#	animation.play("N_c_loop")
		#	player.crouching = false
			
		#"N_c_loop":
		#	set_physics_process(false)
		#	player.crouching = false
