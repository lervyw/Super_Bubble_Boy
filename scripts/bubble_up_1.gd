extends "res://Cenas/powerup.gd"

func _ready():
	unlock_form = player.Form.BUBBLE
	health_increase = 1
	update_respawn = false   # Pode ativar se quiser
