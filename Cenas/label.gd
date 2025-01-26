extends Label

# Conectando o sinal no _ready
func _ready() -> void:
	# Verificando se o nó do jogador existe no caminho correto
	var player = get_parent().get_node("flopster")  # Certifique-se de que o caminho está correto
	if player:
		# Conectando o sinal 'change_life' ao método '_on_life_changed' com Callable
		player.connect("change_life", Callable(self, "_on_life_changed"))

# Método que atualiza o texto da Label com a nova quantidade de vidas
func _on_life_changed(new_life: int) -> void:
	text = "Vidas: %d" % new_life  # Atualiza o texto com a nova quantidade de vidas
