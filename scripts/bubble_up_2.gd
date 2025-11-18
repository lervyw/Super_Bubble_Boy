extends "res://Cenas/powerup.gd"

func _ready():
	unlock_form = player.Form.SUPER
	health_increase = 2
	max_health_increase = 2
	update_respawn = false  # opcional
