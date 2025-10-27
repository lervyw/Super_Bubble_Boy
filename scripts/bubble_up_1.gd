extends Area2D
@export var player: CharacterBody2D
@export var status: Node

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		status.update_helth("Increase", 1)
		player.unlocked_forms[player.Form.BUBBLE] = true
		queue_free()
