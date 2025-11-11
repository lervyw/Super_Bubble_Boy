extends Area2D

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("jogador") and "in_water" in body:
		body.in_water = true
		if "change_state" in body:
			body.change_state(body.State.SWIM)
		print("💧 Entrou na água")

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("jogador") and "in_water" in body:
		body.in_water = false
		if "change_state" in body:
			if body.is_on_floor():
				body.change_state(body.State.IDLE)
			else:
				body.change_state(body.State.JUMP)
		print("🌊 Saiu da água")
