extends Node2D
class_name Lamp

## Luz que a lâmpada emite
@onready var light: PointLight2D = $PointLight2D

## Sprite da lâmpada (opcional)
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

## Partículas de luz (opcional)
@onready var particles: CPUParticles2D = $CPUParticles2D if has_node("CPUParticles2D") else null

@export_group("Configurações de Luz")
## Energia da luz durante a noite
@export_range(0.0, 3.0) var night_energy: float = 1.5

## Energia da luz durante o dia (geralmente 0)
@export_range(0.0, 3.0) var day_energy: float = 0.0

## Alcance da luz
@export_range(0.0, 1000.0) var light_range: float = 200.0

## Cor da luz
@export var light_color: Color = Color(1.0, 0.9, 0.6)  # Amarelo quente

@export_group("Comportamento")
## A lâmpada acende automaticamente baseado no ciclo dia/noite
@export var auto_toggle: bool = true

## Efeito de cintilação (flicker)
@export var enable_flicker: bool = true
@export_range(0.0, 0.3) var flicker_intensity: float = 0.1

## Velocidade da transição de ligar/desligar
@export_range(0.1, 5.0) var fade_speed: float = 2.0

var is_on: bool = false
var target_energy: float = 0.0
var day_night_cycle: DayAndNightCycle = null

func _ready() -> void:
	# Configura a luz
	if light:
		light.enabled = true
		light.texture_scale = light_range / 100.0  # Ajusta escala
		light.color = light_color
		light.energy = 0.0  # Começa apagada
	else:
		# Cria PointLight2D se não existir
		_create_light()
	
	# Conecta ao sistema de dia/noite
	_connect_to_day_night_cycle()
	
	print("💡 Lâmpada criada em: ", global_position)

func _create_light() -> void:
	"""Cria um PointLight2D se não existir"""
	light = PointLight2D.new()
	add_child(light)
	light.enabled = true
	light.texture_scale = light_range / 100.0
	light.color = light_color
	light.energy = 0.0
	
	# Textura padrão (círculo)
	# Godot 4 usa uma textura padrão automaticamente

func _connect_to_day_night_cycle() -> void:
	"""Conecta aos sinais do ciclo dia/noite"""
	day_night_cycle = get_tree().get_first_node_in_group("dayAndNightCycle")
	
	if day_night_cycle:
		day_night_cycle.changeDayTime.connect(_on_day_time_changed)
		day_night_cycle.day_night_progress.connect(_on_day_night_progress)
		print("  ✅ Conectada ao ciclo dia/noite")
	else:
		push_warning("⚠️ Lâmpada: Ciclo dia/noite não encontrado!")

func _process(delta: float) -> void:
	if not light:
		return
	
	# Transição suave de energia
	light.energy = lerp(light.energy, target_energy, fade_speed * delta)
	
	# Efeito de cintilação
	if enable_flicker and is_on:
		var flicker = randf_range(-flicker_intensity, flicker_intensity)
		light.energy = target_energy + flicker

func _on_day_time_changed(day_state: DayAndNightCycle.DAY_STATE) -> void:
	"""Callback quando muda o período do dia"""
	if not auto_toggle:
		return
	
	match day_state:
		DayAndNightCycle.DAY_STATE.EVENING:
			turn_on()
		DayAndNightCycle.DAY_STATE.NOON:
			turn_off()

func _on_day_night_progress(progress: float) -> void:
	"""Callback com o progresso do ciclo (0.0 = dia, 1.0 = noite)"""
	# Pode usar para transições mais suaves
	if auto_toggle:
		target_energy = lerp(day_energy, night_energy, progress)

func turn_on() -> void:
	"""Liga a lâmpada"""
	is_on = true
	target_energy = night_energy
	
	if particles:
		particles.emitting = true
	
	print("💡 Lâmpada LIGADA")

func turn_off() -> void:
	"""Desliga a lâmpada"""
	is_on = false
	target_energy = day_energy
	
	if particles:
		particles.emitting = false
	
	print("💡 Lâmpada DESLIGADA")

func toggle() -> void:
	"""Alterna estado da lâmpada"""
	if is_on:
		turn_off()
	else:
		turn_on()

func set_light_color(color: Color) -> void:
	"""Muda a cor da luz"""
	light_color = color
	if light:
		light.color = color

func set_light_range(range_value: float) -> void:
	"""Muda o alcance da luz"""
	light_range = range_value
	if light:
		light.texture_scale = range_value / 100.0
