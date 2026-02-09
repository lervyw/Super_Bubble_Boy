extends Area2D
# =========================================================
#  WATER ZONE
#  Área que simula água:
#  - Ativa física de água no player
#  - Diminui velocidade / gravidade (controlado no Player.gd)
#  - Troca estado para SWIM ao entrar
# =========================================================


# ================================
#        ENTRADA NA ÁGUA
# ================================
func _on_body_entered(body: Node) -> void:
	# Verifica se é o player e se ele possui a variável 'in_water'
	if body.is_in_group("jogador") and "in_water" in body:
		# Ativa flag de água (usada no Player.gd)
		body.in_water = true

		# Troca estado para SWIM, se suportado
		if "change_state" in body:
			body.change_state(body.State.SWIM)

		print("💧 Entrou na água")


# ================================
#          SAÍDA DA ÁGUA
# ================================
func _on_body_exited(body: Node) -> void:
	# Verifica se é o player e se ele possui a variável 'in_water'
	if body.is_in_group("jogador") and "in_water" in body:
		# Desativa flag de água
		body.in_water = false

		# Decide estado ao sair da água
		if "change_state" in body:
			# Se saiu e já está no chão, volta para IDLE
			if body.is_on_floor():
				body.change_state(body.State.IDLE)
			else:
				# Se saiu no ar, continua em JUMP
				body.change_state(body.State.JUMP)

		print("🌊 Saiu da água")
