extends CanvasModulate
class_name DayAndNightCycle

## Sinal emitido quando muda o período do dia
signal changeDayTime(dayTime: DAY_STATE)

## Sinal emitido a cada frame com o progresso (0.0 a 1.0)
signal day_night_progress(progress: float)

@export var animation_player: AnimationPlayer

## Intensidade do escurecimento (0.0 = totalmente escuro, 1.0 = totalmente claro)
@export_range(0.0, 1.0) var night_darkness: float = 0.3

## Aplica escurecimento no parallax automaticamente
@export var affect_parallax: bool = true

enum DAY_STATE { NOON, EVENING }

var dayTime: DAY_STATE = DAY_STATE.NOON
var current_progress: float = 0.0  # Progresso 0.0 (dia) a 1.0 (noite)

func _ready() -> void:
	add_to_group("dayAndNightCycle")
	
	# Conecta ao parallax se existir
	if affect_parallax:
		_setup_parallax_modulation()

func _process(delta: float) -> void:
	if not animation_player:
		return
	
	var animationPos = animation_player.current_animation_position
	var animationLength = animation_player.current_animation_length / 2
	
	# Calcula progresso normalizado (0.0 = dia, 1.0 = noite)
	current_progress = animationPos / animation_player.current_animation_length
	day_night_progress.emit(current_progress)
	
	# Aplica escurecimento no parallax
	if affect_parallax:
		_update_parallax_brightness()
	
	# Detecta mudança de período
	if animationPos > animationLength && dayTime != DAY_STATE.EVENING:
		dayTime = DAY_STATE.EVENING
		changeDayTime.emit(dayTime)
		print("🌙 Noite chegou!")
	elif animationPos < animationLength && dayTime != DAY_STATE.NOON:
		dayTime = DAY_STATE.NOON
		changeDayTime.emit(dayTime)
		print("☀️ Dia chegou!")

func _setup_parallax_modulation() -> void:
	"""Prepara o parallax para receber modulação de cor"""
	var parallax = get_tree().get_first_node_in_group("parallax")
	if parallax and parallax is ParallaxBackground:
		# O parallax será afetado pelo CanvasModulate automaticamente
		print("✅ Parallax encontrado e será afetado pelo ciclo dia/noite")

func _update_parallax_brightness() -> void:
	"""Atualiza o brilho do parallax baseado no ciclo"""
	# O CanvasModulate já afeta o parallax automaticamente
	# Esta função pode ser usada para ajustes extras se necessário
	pass

func get_current_brightness() -> float:
	"""Retorna o brilho atual (0.0 = noite, 1.0 = dia)"""
	return lerp(1.0, night_darkness, current_progress)

func is_night() -> bool:
	"""Verifica se está de noite"""
	return dayTime == DAY_STATE.EVENING

func is_day() -> bool:
	"""Verifica se está de dia"""
	return dayTime == DAY_STATE.NOON
