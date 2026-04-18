extends CanvasModulate
class_name DayAndNightCycle
# =========================================================
#  CICLO DIA/NOITE
#  Script que usa um AnimationPlayer como “relógio”:
#  - Lê a posição da animação e transforma em progresso (0..1)
#  - Emite sinais para outros sistemas reagirem (HUD, inimigos, etc)
#  - Troca estado entre DIA e NOITE (NOON / EVENING)
#  - Opcionalmente “afeta” parallax (na prática, CanvasModulate já afeta)
# =========================================================


## ================================
##              SINAIS
## ================================

## Dispara quando muda o período do dia (DIA <-> NOITE)
signal changeDayTime(dayTime: DAY_STATE)

## Dispara todo frame com o progresso do ciclo (0.0 a 1.0)
signal day_night_progress(progress: float)


## ================================
##           REFERÊNCIAS
## ================================

# AnimationPlayer usado como base do tempo (posição da animação = hora do dia)
@export var animation_player: AnimationPlayer


## ================================
##           CONFIGURAÇÕES
## ================================

## “Quão escuro” fica de noite (1.0 = claro, 0.0 = muito escuro)
@export_range(0.0, 1.0) var night_darkness: float = 0.3

## Se true, tenta integrar com Parallax (mesmo que CanvasModulate já influencie)
@export var affect_parallax: bool = true


## ================================
##            ESTADOS
## ================================

# Dois períodos simplificados do ciclo
enum DAY_STATE { NOON, EVENING }

# Estado atual do dia
var dayTime: DAY_STATE = DAY_STATE.NOON

# Progresso do ciclo (0.0 = dia, 1.0 = noite)
var current_progress: float = 0.0


## ================================
##              READY
## ================================
func _ready() -> void:
	# Permite que outros scripts encontrem este sistema por grupo
	add_to_group("dayAndNightCycle")

	# Se configurado, prepara integração com o parallax
	if affect_parallax:
		_setup_parallax_modulation()


## ================================
##             PROCESS
## ================================
func _process(delta: float) -> void:
	# Sem AnimationPlayer não existe ciclo (ele é o “relógio”)
	if not animation_player:
		return

	# Posição atual da animação (em segundos)
	var animationPos = animation_player.current_animation_position

	# Metade da animação = ponto onde você considera “virou noite”
	var animationLength = animation_player.current_animation_length / 2

	# Calcula progresso normalizado do ciclo (0.0 -> 1.0)
	current_progress = animationPos / animation_player.current_animation_length

	# Emite progresso (outros sistemas podem usar pra luz, spawn, etc)
	day_night_progress.emit(current_progress)

	# Ajustes extras no parallax (se você quiser)
	if affect_parallax:
		_update_parallax_brightness()

	# Detecta mudança de período (dia/noite) baseado na metade da animação
	if animationPos > animationLength && dayTime != DAY_STATE.EVENING:
		dayTime = DAY_STATE.EVENING
		changeDayTime.emit(dayTime)
		print("🌙 Noite chegou!")
	elif animationPos < animationLength && dayTime != DAY_STATE.NOON:
		dayTime = DAY_STATE.NOON
		changeDayTime.emit(dayTime)
		print("☀️ Dia chegou!")


## ================================
##         PARALLAX (OPCIONAL)
## ================================
func _setup_parallax_modulation() -> void:
	"""Procura um ParallaxBackground e confirma que será afetado"""
	var parallax = get_tree().get_first_node_in_group("parallax")
	if parallax and parallax is ParallaxBackground:
		# CanvasModulate já colore tudo que está no Canvas (incluindo parallax)
		print("✅ Parallax encontrado e será afetado pelo ciclo dia/noite")

func _update_parallax_brightness() -> void:
	"""Hook para ajustes extras (CanvasModulate já faz o básico)"""
	# Aqui você poderia, por exemplo, ajustar modulate/energia de luzes do parallax
	pass


## ================================
##          UTILITÁRIOS
## ================================
func get_current_brightness() -> float:
	"""Retorna o brilho atual (0.0 = noite, 1.0 = dia)"""
	# Interpola de 1.0 (dia) até night_darkness (noite)
	return lerp(1.0, night_darkness, current_progress)

func is_night() -> bool:
	"""Retorna true se está no período de noite"""
	return dayTime == DAY_STATE.EVENING

func is_day() -> bool:
	"""Retorna true se está no período de dia"""
	return dayTime == DAY_STATE.NOON
