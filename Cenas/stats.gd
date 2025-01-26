extends Node
var base_health: int = 3
var bonus_health : int
var current_health: int
var max_health: int
@export var player: Node
func _ready() -> void:
	current_health = base_health + bonus_health
	max_health = current_health
func update_helth(type: String, value: int):
	match type:
		"Increase":
			current_health += value
			if current_health >= max_health:
				current_health = max_health
	
		"Decrease":
			current_health -= value
			if current_health <= 0:
				player.dead = true
			else:
				player.on_hit = true
				#player.attacking = false
			
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_down"):
		update_helth("Decrease", 1)
