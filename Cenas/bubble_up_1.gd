extends Area2D
@export var player: Node
@export var status: Node
func _on_body_entered(body: Node2D) -> void:
	status.update_helth("Increase", 1)
	player.Pode_Bolha = true
	queue_free()
	
