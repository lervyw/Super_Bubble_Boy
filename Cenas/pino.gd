extends Sprite2D


# Sinal para detectar quando algo entra na área de colisão
signal player_died

func _on_body_entered(body: Node) -> void:
	# Verifica se o corpo que entrou é o jogador
	if body.is_in_group("player"):
		# Emite o sinal de que o jogador morreu (pode ser usado para gerenciar o jogo)
		emit_signal("player_died")
		# Executa a lógica de morte do jogador
		body.die()
