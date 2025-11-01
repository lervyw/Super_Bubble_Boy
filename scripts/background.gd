extends ParallaxBackground

## ========================================
## SCRIPT DE PARALLAX AUTOMÁTICO
## ========================================
## Movimenta camadas de parallax automaticamente
## com repetição infinita (mirroring)
## ========================================

@export_group("Controles Gerais")
## Ativa/desativa o movimento automático
@export var can_process: bool = true

## Direção do movimento
@export_enum("Esquerda:-1", "Direita:1") var direction: int = -1

@export_group("Velocidades")
## Velocidade de cada camada (índice 0 = Layer1, 1 = Layer2, etc)
## Valores maiores = movimento mais rápido
@export var layer_speed: Array[float] = [0.0, 10.0, 20.0, 40.0]

## Multiplicador global de velocidade (facilita ajustes rápidos)
@export_range(0.0, 5.0, 0.1) var speed_multiplier: float = 1.0

@export_group("Repetição (Mirroring)")
## Largura para repetição automática
## 0 = Auto-detecta baseado na textura
## Valor manual = força uma largura específica
@export var mirror_width: float = 0.0

## Configura mirroring automaticamente no _ready
@export var auto_setup_mirroring: bool = true

func _ready() -> void:
	# Configura o processamento
	set_physics_process(can_process)
	
	# Valida arrays de velocidade
	_validate_setup()
	
	# Configura mirroring automático
	if auto_setup_mirroring:
		_setup_mirroring()

func _physics_process(delta: float) -> void:
	"""Move todas as camadas de parallax"""
	for index in get_child_count():
		var child = get_child(index)
		
		# Só processa ParallaxLayers
		if not child is ParallaxLayer:
			continue
		
		# Verifica se há velocidade definida para essa layer
		if index >= layer_speed.size():
			continue
		
		# Calcula velocidade final
		var final_speed = layer_speed[index] * speed_multiplier * direction
		
		# Aplica movimento
		child.motion_offset.x += delta * final_speed

func _setup_mirroring() -> void:
	"""Configura repetição infinita para todas as camadas"""
	print("🎨 Configurando Parallax Mirroring...")
	
	for index in get_child_count():
		var child = get_child(index)
		
		if not child is ParallaxLayer:
			continue
		
		var layer = child as ParallaxLayer
		var sprite: Sprite2D = _find_sprite_in_layer(layer)
		
		if not sprite:
			push_warning("⚠️ Layer '%s' não tem Sprite2D! Pule esta layer ou adicione um sprite." % layer.name)
			continue
		
		if not sprite.texture:
			push_warning("⚠️ Sprite2D em '%s' não tem textura!" % layer.name)
			continue
		
		# Calcula largura considerando scale e region
		var width = _calculate_sprite_width(sprite)
		
		# Usa largura manual se definida, senão usa a detectada
		var final_width = mirror_width if mirror_width > 0 else width
		
		# Configura o mirroring
		layer.motion_mirroring.x = final_width
		layer.motion_mirroring.y = 0  # Não repete verticalmente
		
		print("  ✅ '%s': Mirroring X = %.0f px" % [layer.name, final_width])

func _find_sprite_in_layer(layer: ParallaxLayer) -> Sprite2D:
	"""Encontra o primeiro Sprite2D dentro de uma ParallaxLayer"""
	for child in layer.get_children():
		if child is Sprite2D:
			return child
	return null

func _calculate_sprite_width(sprite: Sprite2D) -> float:
	"""Calcula a largura real de um sprite considerando scale e region"""
	var width: float = 0.0
	
	# Se usa Region, pega a largura da region
	if sprite.region_enabled:
		width = sprite.region_rect.size.x
	else:
		# Senão, pega a largura da textura
		width = sprite.texture.get_width()
	
	# Multiplica pelo scale
	width *= sprite.scale.x
	
	return width

func _validate_setup() -> void:
	"""Valida a configuração e avisa sobre problemas"""
	var layer_count = get_child_count()
	
	# Conta quantas são ParallaxLayers
	var parallax_layer_count = 0
	for child in get_children():
		if child is ParallaxLayer:
			parallax_layer_count += 1
	
	# Verifica se tem velocidades suficientes
	if layer_speed.size() < parallax_layer_count:
		push_warning("⚠️ PARALLAX: Você tem %d ParallaxLayers mas só %d velocidades definidas!" % [parallax_layer_count, layer_speed.size()])
		
		# Preenche com zeros
		while layer_speed.size() < parallax_layer_count:
			layer_speed.append(0.0)
			print("  ➕ Adicionada velocidade 0.0 para layer %d" % layer_speed.size())
	
	print("📊 Parallax Stats: %d layers, %d velocidades" % [parallax_layer_count, layer_speed.size()])

# ========================================
# FUNÇÕES PÚBLICAS (podem ser chamadas de fora)
# ========================================

func set_speed_multiplier(value: float) -> void:
	"""Muda o multiplicador de velocidade em runtime"""
	speed_multiplier = clamp(value, 0.0, 5.0)
	print("🎚️ Speed multiplier alterado para: %.2f" % speed_multiplier)

func pause_parallax() -> void:
	"""Pausa o movimento do parallax"""
	set_physics_process(false)
	print("⏸️ Parallax pausado")

func resume_parallax() -> void:
	"""Resume o movimento do parallax"""
	set_physics_process(true)
	print("▶️ Parallax resumido")

func reverse_direction() -> void:
	"""Inverte a direção do movimento"""
	direction *= -1
	print("🔄 Direção invertida: %s" % ("Direita" if direction > 0 else "Esquerda"))

func set_layer_speed(layer_index: int, speed: float) -> void:
	"""Altera a velocidade de uma layer específica"""
	if layer_index >= 0 and layer_index < layer_speed.size():
		layer_speed[layer_index] = speed
		print("🎯 Layer %d velocidade alterada para: %.2f" % [layer_index, speed])
	else:
		push_warning("⚠️ Índice de layer inválido: %d" % layer_index)

func reset_offsets() -> void:
	"""Reseta a posição de todas as layers"""
	for child in get_children():
		if child is ParallaxLayer:
			child.motion_offset = Vector2.ZERO
	print("🔄 Offsets resetados")
