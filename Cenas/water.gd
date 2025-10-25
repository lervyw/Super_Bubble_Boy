extends Area2D

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.in_water = true
		# Opcional: tocar som, mudar cor, etc
		print("Entrou na água")

func _on_body_exited(body):
	if body.is_in_group("player"):
		body.in_water = false
		print("Saiu da água")
