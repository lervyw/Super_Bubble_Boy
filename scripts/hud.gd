extends CanvasLayer

@export var player: CharacterBody2D
@export var stats: Node
@export var heart_icons: Array[TextureRect] = []
@export var hp_bar: TextureProgressBar

@export var menu_panel: Panel  # <<< NOVO

func _ready() -> void:
	if menu_panel:
		menu_panel.visible = false

func _process(delta: float) -> void:
	if not player:
		return

	if player.mode == player.GameMode.PLATAFORMA:
		_update_hearts()
		_set_hp_visible(false)
		# NÃO chamar _set_hearts_visible(true) → evitar reinicializar corações
	else:
		_update_hp_bar()
		_set_hearts_visible(false)
		_set_hp_visible(true)


# ================================
# ♥ CORAÇÕES (Modo Plataforma)
# ================================
func _update_hearts() -> void:
	var lives := GameManager.get_lives()

	for i in range(heart_icons.size()):
		var heart := heart_icons[i]
		if heart:
			# Coração visível apenas se índice < vidas
			heart.visible = i < lives


# ================================
# ♥ HP BAR (Modo Metroidvania)
# ================================
func _update_hp_bar() -> void:
	if not hp_bar or not stats:
		return

	var current: float = float(stats.current_health)
	var max_hp: float = float(stats.max_health)

	hp_bar.max_value = max_hp
	hp_bar.value = current


# ================================
# Visibilidade independente
# ================================
func _set_hearts_visible(v: bool) -> void:
	for h in heart_icons:
		if h:
			h.visible = v

func _set_hp_visible(v: bool) -> void:
	if hp_bar:
		hp_bar.visible = v


func show_menu():
	if menu_panel:
		menu_panel.visible = true

func hide_menu():
	if menu_panel:
		menu_panel.visible = false
