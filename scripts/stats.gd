extends Node
var base_health: int = 3
var bonus_health : int
var current_health: int
var max_health: int

var blink_count := 0
const MAX_BLINKS := 4
@export var piscar_timer: Timer

@export var player: CharacterBody2D
@export var collision_area: Area2D
@export var invecibilidade: Timer
@export var textura: Sprite2D

func _ready() -> void:
	
	current_health = base_health + bonus_health
	max_health = current_health
	print("vida atual: ", current_health)
	
func update_helth(type: String, value: int):
	
	match type:
		"Increase":
			current_health += value
			if current_health >= max_health:
				current_health = max_health
	
		"Decrease":
			current_health -= value
			print("vida atual: ", current_health)
			if current_health <= 0:
				player.dead = true
			else:
				player.on_hit = true
			blink_count = 0
			piscar_timer.start()
				#player.attacking = false
	
#func _process(delta: float) -> void:
#	if Input.is_action_just_pressed("ui_down"):
#		update_helth("Decrease", 1)
#		pass

func _on_colisao_area(area: Area2D) -> void:
	#Este e a funcao para matar inimigos com um ataque
	if area.is_in_group("ebody"):
		update_helth("Decrease", 1)	
		collision_area.set_deferred("monitoring", false)
		player.knockback()
		invecibilidade.start()
		#invecibilidade.start(area.invencibilidade)			

		print('invencivel')

func _on_invencibilidade_timeout() -> void:
	collision_area.set_deferred("monitoring", true)
	pass # Replace with function body.
	


func _on_piscar_timer_timeout() -> void:
	if blink_count < MAX_BLINKS:
		blink_count += 1
		textura.visible = not textura.visible
		textura.modulate = Color(1, 0.5, 0.5) if blink_count % 2 == 0 else Color(1, 1, 1)
	else:
		piscar_timer.stop()
		textura.visible = true
		textura.modulate = Color(1, 1, 1)


func _on_matador_area_entered(area: Area2D) -> void:
	if area.is_in_group("slime"):
		collision_area.monitoring = false
		await get_tree().create_timer(0.5).timeout
		collision_area.monitoring = true
