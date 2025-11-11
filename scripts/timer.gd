extends CanvasLayer

@export var time_left: float = 180.0  # Tempo em segundos (180 = 3 minutos)
@export var player: CharacterBody2D
@export var tempo: Label

var timer_running: bool = true

func _ready() -> void:
	update_timer_text()
	
	# Valida configurações
	if not player:
		push_warning("⚠️ Player não configurado no Timer!")
	if not tempo:
		push_warning("⚠️ Label de tempo não configurado no Timer!")

func _process(delta: float) -> void:
	if not timer_running:
		return
	
	if time_left > 0:
		time_left -= delta
		update_timer_text()
	else:
		time_left = 0
		timer_running = false
		on_timer_end()

func update_timer_text() -> void:
	if not tempo:
		return
	
	var seconds = int(time_left)
	var milliseconds = int((time_left - seconds) * 100)  # Centésimos de segundo
	tempo.text = "%02d:%02d" % [seconds, milliseconds]
	
	# Efeito visual quando está acabando
	if time_left <= 10.0:
		tempo.modulate = Color.RED
	elif time_left <= 30.0:
		tempo.modulate = Color.YELLOW
	else:
		tempo.modulate = Color.WHITE

func on_timer_end() -> void:
	"""Chamado quando o tempo acaba - mata o player"""
	print("⏰ Tempo esgotado! Game Over!")
	
	if not player:
		push_error("❌ Player não configurado!")
		return
	
	# Mata o player usando a função force_die()
	player.die()

# ===== FUNÇÕES PÚBLICAS ÚTEIS =====

func add_time(seconds: float) -> void:
	"""Adiciona tempo extra ao timer (power-up)"""
	time_left += seconds
	update_timer_text()
	print("➕ Tempo adicionado: +%.0fs" % seconds)

func remove_time(seconds: float) -> void:
	"""Remove tempo do timer (penalidade)"""
	time_left -= seconds
	if time_left < 0:
		time_left = 0
		on_timer_end()
	update_timer_text()
	print("➖ Tempo removido: -%.0fs" % seconds)

func pause_timer() -> void:
	"""Pausa o timer"""
	timer_running = false
	print("⏸️ Timer pausado")

func resume_timer() -> void:
	"""Resume o timer"""
	timer_running = true
	print("▶️ Timer resumido")

func reset_timer(new_time: float = 180.0) -> void:
	"""Reinicia o timer"""
	time_left = new_time
	timer_running = true
	update_timer_text()
	print("🔄 Timer reiniciado")

func get_time_remaining() -> float:
	"""Retorna o tempo restante"""
	return time_left
