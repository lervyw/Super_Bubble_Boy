extends Control

@export var DialogBox: RichTextLabel

@export_group("Diálogos")
@export var dialogs: Array[String] = [
	"você é um garoto com cabeça de bolha",
	"precisa destruir um sapo maligno",
	"e assim salvar o universo",
	"slimes serão invocados para lhe impedir",
	"colete os Power Ups e ache o sapo",
	"você tem 5 minutos para isso",
	"use as setas para se mover",
	"L1 e R1 para se transformar",
	"Triângulo para DASH, QUADRADO para atacar, X para pular",
	"BOA SORTE!"
]

@export_group("Botão de Avançar")
## Botão que avança os diálogos quando clicado
@export var advance_button: Button

@export_group("Configurações")
## Ação ao terminar diálogos (esconder, remover ou mudar cena)
@export_enum("Hide", "Remove", "Go To Level1") var on_finish_action: int = 2

## Tempo de espera antes de mudar de cena (em segundos)
@export_range(0.0, 5.0) var delay_before_scene_change: float = 0.5

var current_dialog_index: int = 0

func _ready() -> void:
	print("🎬 Cutscene iniciada")
	_apply_responsive_layout()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	
	# Configura o primeiro diálogo
	if dialogs.size() > 0:
		DialogBox.set_dialog(dialogs[current_dialog_index])
		print("📝 Diálogo 1/%d" % dialogs.size())
	else:
		push_warning("⚠️ Nenhum diálogo configurado!")
	
	# Conecta o botão se existir
	if advance_button:
		advance_button.pressed.connect(_on_advance_button_pressed)
		print("✅ Botão de avançar conectado")


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	_fill_screen(self)

	var background := get_node_or_null("Background") as TextureRect
	if background:
		_fill_screen(background)
		background.scale = Vector2.ONE
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var dialog_border := get_node_or_null("Border") as TextureRect
	if dialog_border:
		dialog_border.anchor_left = 0.5
		dialog_border.anchor_top = 0.0
		dialog_border.anchor_right = 0.5
		dialog_border.anchor_bottom = 0.0
		dialog_border.offset_left = -132.0
		dialog_border.offset_top = 18.0
		dialog_border.offset_right = 132.0
		dialog_border.offset_bottom = 166.0
		dialog_border.scale = Vector2.ONE
		dialog_border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dialog_border.stretch_mode = TextureRect.STRETCH_SCALE

	var dialog_container := get_node_or_null("Node/CharacterNode/MarginContainer") as Control
	if dialog_container:
		dialog_container.anchor_left = 0.5
		dialog_container.anchor_top = 0.0
		dialog_container.anchor_right = 0.5
		dialog_container.anchor_bottom = 0.0
		dialog_container.offset_left = -104.0
		dialog_container.offset_top = 30.0
		dialog_container.offset_right = 104.0
		dialog_container.offset_bottom = 136.0

	if advance_button:
		advance_button.anchor_left = 0.5
		advance_button.anchor_top = 0.0
		advance_button.anchor_right = 0.5
		advance_button.anchor_bottom = 0.0
		advance_button.offset_left = -58.0
		advance_button.offset_top = minf(190.0, viewport_size.y - 48.0)
		advance_button.offset_right = 58.0
		advance_button.offset_bottom = minf(222.0, viewport_size.y - 16.0)
		advance_button.scale = Vector2.ONE

	var fernanda := get_node_or_null("Node/CharacterNode/AnimatedSprite2D") as AnimatedSprite2D
	if fernanda:
		fernanda.position = Vector2(viewport_size.x * 0.78, viewport_size.y * 0.72)

	var bubble := get_node_or_null("Node/AnimatedSprite2D") as AnimatedSprite2D
	if bubble:
		bubble.position = Vector2(viewport_size.x * 0.22, viewport_size.y * 0.72)


func _fill_screen(node: Control) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0

func _input(event: InputEvent) -> void:
	# Detecta clique do mouse, tecla de ação ou botão do controle
	if event.is_action_pressed("jump") or \
	   event.is_action_pressed("attack") or \
	   (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		advance_dialog()

func _on_advance_button_pressed() -> void:
	"""Callback do botão de avançar"""
	advance_dialog()

func advance_dialog() -> void:
	"""Avança para o próximo diálogo"""
	# Se ainda está exibindo, pula para o final
	if DialogBox.is_displaying:
		DialogBox.skip_dialog()
		return
	
	# Se pode avançar, vai para o próximo diálogo
	if DialogBox.is_ready_to_advance():
		current_dialog_index += 1
		
		if current_dialog_index < dialogs.size():
			DialogBox.set_dialog(dialogs[current_dialog_index])
			print("📝 Diálogo %d/%d" % [current_dialog_index + 1, dialogs.size()])
		else:
			# Terminou todos os diálogos
			on_dialogs_finished()

func on_dialogs_finished() -> void:
	"""Executado quando todos os diálogos terminam"""
	print("✅ Todos os diálogos foram exibidos!")
	
	# Desabilita o botão se existir
	if advance_button:
		advance_button.disabled = true
	
	# Executa a ação configurada
	match on_finish_action:
		0:  # Hide - Esconde o diálogo
			print("👻 Escondendo cutscene...")
			hide_dialog()
		1:  # Remove - Remove o diálogo da cena
			print("🗑️ Removendo cutscene...")
			remove_dialog()
		2:  # Go To Level1 - Vai para o Level1
			print("🎬 Carregando Level 1...")
			go_to_level1()
		_:
			push_warning("⚠️ Ação de finalização inválida!")

func hide_dialog() -> void:
	"""Esconde o controle de diálogo"""
	visible = false

func remove_dialog() -> void:
	"""Remove o controle de diálogo da árvore"""
	queue_free()

func go_to_level1() -> void:
	"""Vai para o Level 1 usando o GameManager"""
	# Aguarda um pouco antes de mudar de cena
	if delay_before_scene_change > 0:
		await get_tree().create_timer(delay_before_scene_change).timeout
	
	print("🎮 Iniciando Level 1 via GameManager...")
	GameManager.goto_level1()

# ===== FUNÇÕES PÚBLICAS =====

func skip_all_dialogs() -> void:
	"""Pula todos os diálogos e vai direto para a finalização"""
	current_dialog_index = dialogs.size()
	on_dialogs_finished()

func reset_dialogs() -> void:
	"""Reinicia os diálogos do início"""
	current_dialog_index = 0
	if dialogs.size() > 0:
		DialogBox.set_dialog(dialogs[current_dialog_index])
	print("🔄 Diálogos reiniciados")

func get_progress() -> float:
	"""Retorna o progresso dos diálogos (0.0 a 1.0)"""
	if dialogs.size() == 0:
		return 1.0
	return float(current_dialog_index) / float(dialogs.size())
