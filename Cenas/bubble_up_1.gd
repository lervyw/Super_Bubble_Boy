extends Area2D
@export var player: Node

func _on_body_entered(body: Node2D) -> void:
	player.Pode_Bolha = true
	queue_free()
	
