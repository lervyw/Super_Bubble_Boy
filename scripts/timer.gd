extends CanvasLayer
# =========================================================
#  LEVEL TIMER (HUD)
#  Responsável por:
#  - Contar o tempo do nível
#  - Atualizar o texto do HUD
#  - Aplicar feedback visual (cores)
#  - Encerrar o jogo quando o tempo acaba
# =========================================================


# ================================
#           CONFIGURAÇÕES
# ================================

# Tempo inicial do nível (em segundos)
@export var time_left: float = 180.0  # 180s = 3 minutos
@export var start_enabled: bool = false

# Referência ao player (para matar quando o tempo acabar)
@export var player: CharacterBody2D

# Label que exibe o tempo na tela
@export var tempo: Label

# Controla se o timer está rodando ou pausado
var timer_running: bool = false


# ================================
#             READY
# ================================
func _ready() -> void:
	# Atualiza o texto inicial do timer
	update_timer_text()
	timer_running = start_enabled
	visible = start_enabled

	# Valida referências para evitar erros silenciosos
	if start_enabled and not player:
		push_warning("⚠️ Player não configurado no Timer!")
	if not tempo:
		push_warning("⚠️ Label de tempo não configurado no Timer!")


# ================================
#            PROCESS
# ================================
func _process(delta: float) -> void:
	# Se o timer estiver pausado, não faz nada
	if not timer_running:
		return

	if time_left <= 0.0:
		time_left = 0
		timer_running = false
		on_timer_end()
		return

	time_left = maxf(time_left - delta, 0.0)
	update_timer_text()

	if time_left <= 0.0:
		timer_running = false
		on_timer_end()


# ================================
#        ATUALIZAÇÃO DO HUD
# ================================
func update_timer_text() -> void:
	# Se não houver label, ignora
	if not tempo:
		return

	# Separa segundos e centésimos
	var seconds = int(time_left)
	var milliseconds = int((time_left - seconds) * 100)

	# Formata como "SS:CC"
	tempo.text = "%02d:%02d" % [seconds, milliseconds]

	# Feedback visual conforme o tempo acaba
	if time_left <= 10.0:
		tempo.modulate = Color.RED
	elif time_left <= 30.0:
		tempo.modulate = Color.YELLOW
	else:
		tempo.modulate = Color.WHITE


# ================================
#        FIM DO TEMPO
# ================================
func on_timer_end() -> void:
	"""Chamado quando o tempo acaba"""
	print("Tempo esgotado!")

	# Garante que o player existe
	if not player:
		push_error("❌ Player não configurado!")
		return

	# Deixa o Player decidir como consumir vida, morrer e ir para Continue.
	if player.has_method("handle_level_timeout"):
		player.handle_level_timeout()
	elif player.has_method("die"):
		player.die()


# ================================
#     FUNÇÕES PÚBLICAS ÚTEIS
# ================================

func add_time(seconds: float) -> void:
	"""Adiciona tempo extra ao timer (power-up)"""
	time_left += seconds
	update_timer_text()
	print("➕ Tempo adicionado: +%.0fs" % seconds)

func remove_time(seconds: float) -> void:
	"""Remove tempo do timer (penalidade)"""
	time_left -= seconds

	# Se zerar ou ficar negativo, encerra o timer
	if time_left < 0:
		time_left = 0
		on_timer_end()

	update_timer_text()
	print("➖ Tempo removido: -%.0fs" % seconds)

func pause_timer() -> void:
	"""Pausa o timer"""
	timer_running = false
	print("Timer pausado")

func resume_timer() -> void:
	"""Retoma o timer"""
	timer_running = true
	visible = true
	print("Timer resumido")

func reset_timer(new_time: float = 180.0) -> void:
	"""Reinicia o timer com um novo valor"""
	time_left = new_time
	timer_running = true
	visible = true
	update_timer_text()
	print("Timer reiniciado")

func configure_level_timer(enabled: bool, seconds: float, target_player: CharacterBody2D = null) -> void:
	"""Configura o timer a partir do controlador do nível."""
	if target_player:
		player = target_player

	time_left = maxf(seconds, 0.0)
	timer_running = enabled and time_left > 0.0
	visible = enabled
	update_timer_text()

	if timer_running and not player:
		push_warning("Timer habilitado sem player configurado.")

func get_time_remaining() -> float:
	"""Retorna o tempo restante em segundos"""
	return time_left
