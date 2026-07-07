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

## Duração do ciclo completo em segundos quando não há AnimationPlayer.
@export_range(5.0, 300.0, 1.0) var cycle_duration: float = 72.0

## Posição inicial no ciclo. 0.0 = dia claro, 0.5 = noite.
@export_range(0.0, 1.0, 0.01) var start_progress: float = 0.18

@export var day_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var dusk_color: Color = Color(0.82, 0.62, 0.88, 1.0)
@export var night_color: Color = Color(0.22, 0.20, 0.34, 1.0)
@export var dawn_color: Color = Color(0.58, 0.72, 0.95, 1.0)


## ================================
##           CONFIGURAÇÕES
## ================================

## “Quão escuro” fica de noite (1.0 = claro, 0.0 = muito escuro)
@export_range(0.0, 1.0) var night_darkness: float = 0.3

## Se true, tenta integrar com Parallax (mesmo que CanvasModulate já influencie)
@export var affect_parallax: bool = true
@export_range(0.0, 1.0, 0.01) var parallax_influence: float = 0.48
@export_range(0.0, 1.0, 0.01) var parallax_desaturation: float = 0.35
@export var parallax_night_floor: Color = Color(0.34, 0.34, 0.42, 1.0)


## ================================
##            ESTADOS
## ================================

# Dois períodos simplificados do ciclo
enum DAY_STATE { NOON, EVENING }

# Estado atual do dia
var dayTime: DAY_STATE = DAY_STATE.NOON

# Progresso do ciclo (0.0 = dia, 1.0 = noite)
var current_progress: float = 0.0
var _elapsed: float = 0.0
var _parallax_items: Array[CanvasItem] = []


## ================================
##              READY
## ================================
func _ready() -> void:
	# Permite que outros scripts encontrem este sistema por grupo
	add_to_group("dayAndNightCycle")
	current_progress = start_progress
	_elapsed = cycle_duration * start_progress
	color = _get_cycle_color(current_progress)

	# Se configurado, prepara integração com o parallax
	if affect_parallax:
		call_deferred("_setup_parallax_modulation")


## ================================
##             PROCESS
## ================================
func _process(delta: float) -> void:
	if animation_player and animation_player.current_animation_length > 0.0:
		_update_from_animation_player()
	else:
		_update_from_timer(delta)


func _update_from_animation_player() -> void:
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
		_set_day_state(DAY_STATE.EVENING)
	elif animationPos < animationLength && dayTime != DAY_STATE.NOON:
		_set_day_state(DAY_STATE.NOON)

	color = _get_cycle_color(current_progress)


func _update_from_timer(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, cycle_duration)
	current_progress = _elapsed / cycle_duration
	day_night_progress.emit(current_progress)

	if affect_parallax:
		_update_parallax_brightness()

	if current_progress >= 0.38 and current_progress <= 0.72:
		_set_day_state(DAY_STATE.EVENING)
	else:
		_set_day_state(DAY_STATE.NOON)

	color = _get_cycle_color(current_progress)


func _set_day_state(new_state: DAY_STATE) -> void:
	if dayTime == new_state:
		return

	dayTime = new_state
	changeDayTime.emit(dayTime)
	if dayTime == DAY_STATE.EVENING:
		print("Noite chegou!")
	else:
		print("Dia chegou!")


func _get_cycle_color(progress: float) -> Color:
	if progress < 0.28:
		return day_color.lerp(dusk_color, progress / 0.28)
	if progress < 0.50:
		return dusk_color.lerp(night_color, (progress - 0.28) / 0.22)
	if progress < 0.72:
		return night_color.lerp(dawn_color, (progress - 0.50) / 0.22)
	return dawn_color.lerp(day_color, (progress - 0.72) / 0.28)


## ================================
##         PARALLAX (OPCIONAL)
## ================================
func _setup_parallax_modulation() -> void:
	"""Procura o ParallaxBackground e prepara compensação suave contra o escuro global."""
	_parallax_items.clear()
	var parallax := get_tree().get_first_node_in_group("parallax")
	if not parallax:
		var scene := get_tree().current_scene
		if scene:
			parallax = scene.find_child("ParallaxBackground", true, false)

	if parallax:
		_collect_parallax_canvas_items(parallax)
		print("Parallax encontrado e recebera dia/noite suavizado")

func _update_parallax_brightness() -> void:
	"""Aplica dia/noite no parallax de forma mais leve e menos saturada que no mapa."""
	if _parallax_items.is_empty():
		_setup_parallax_modulation()
		if _parallax_items.is_empty():
			return

	var parallax_color := _get_parallax_color(current_progress)
	for item in _parallax_items:
		if is_instance_valid(item):
			item.modulate = parallax_color


func _collect_parallax_canvas_items(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			_parallax_items.append(child)
		_collect_parallax_canvas_items(child)


func _get_parallax_color(progress: float) -> Color:
	var cycle_color := _get_cycle_color(progress)
	var gray := (cycle_color.r + cycle_color.g + cycle_color.b) / 3.0
	var desaturated := cycle_color.lerp(Color(gray, gray, gray, 1.0), parallax_desaturation)
	var softened := Color(1.0, 1.0, 1.0, 1.0).lerp(desaturated, parallax_influence)

	if progress >= 0.38 and progress <= 0.72:
		softened = softened.lerp(parallax_night_floor, 0.35)

	return Color(
		clampf(softened.r, 0.0, 1.0),
		clampf(softened.g, 0.0, 1.0),
		clampf(softened.b, 0.0, 1.0),
		1.0
	)


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
