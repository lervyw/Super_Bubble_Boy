extends Control

@export var DialogBox: RichTextLabel

@export_group("Diálogos")
@export var dialogs: Array[String] = [
	"você é um garoto com cabeça de bolha",
	"precisa destruir um sapo maligno",
	"e assim salvar o mundo",
	"slimes serão invocados para lhe impedir",
	"colete os Power Ups e ache o sapo",
	"você tem 5 minutos para isso",
	"use as setas para se mover",
	"L1 e R1 para se transformar",
	"Triângulo para DASH, QUADRADO para atacar, X para pular",
	"BOA SORTE!"
]

@export_group("Próxima Cena")
## Cena a ser carregada após terminar os diálogos
@export_file("*.tscn") var next_scene_path: String = ""

@export_group("Botão de Avançar")
## Botão que avança os diálogos quando clicado
@export var advance_button: Button

@export_group("Configurações")
## Ação ao terminar diálogos (esconder, remover ou mudar cena)
@export_enum("Hide", "Remove", "Change Scene") var on_finish_action: int = 2

## Tempo de espera antes de mudar de cena (em segundos)
@export_range(0.0, 5.0) var delay_before_scene_change: float = 0.5

var current_dialog_index: int = 0

func _ready() -> void:
	# Configura o primeiro diálogo
	if dialogs.size() > 0:
		DialogBox.set_dialog(dialogs[current_dialog_index])
	else:
		push_warning("⚠️ Nenhum diálogo configurado!")
	
	# Conecta o botão se existir
	if advance_button:
		advance_button.pressed.connect(_on_advance_button_pressed)
		print("✅ Botão de avançar conectado")
	
	# Valida se tem cena configurada para transição
	if on_finish_action == 2 and next_scene_path.is_empty():
		push_warning("⚠️ Ação 'Change Scene' selecionada mas nenhuma cena configurada!")

func _input(event: InputEvent) -> void:
	# Detecta clique do mouse, tecla de ação ou botão do controle
	if event.is_action_pressed("ui_accept") or \
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
			print("👻 Escondendo diálogo...")
			hide_dialog()
		1:  # Remove - Remove o diálogo da cena
			print("🗑️ Removendo diálogo...")
			remove_dialog()
		2:  # Change Scene - Muda de cena
			print("🎬 Carregando próxima cena...")
			change_to_next_scene()
		_:
			push_warning("⚠️ Ação de finalização inválida!")

func hide_dialog() -> void:
	"""Esconde o controle de diálogo"""
	visible = false

func remove_dialog() -> void:
	"""Remove o controle de diálogo da árvore"""
	queue_free()

func change_to_next_scene() -> void:
	"""Muda para a próxima cena configurada"""
	if next_scene_path.is_empty():
		push_error("❌ Caminho da próxima cena não configurado!")
		return
	
	if not FileAccess.file_exists(next_scene_path):
		push_error("❌ Arquivo de cena não encontrado: %s" % next_scene_path)
		return
	
	# Aguarda um pouco antes de mudar de cena (para dar tempo do último diálogo ser lido)
	await get_tree().create_timer(delay_before_scene_change).timeout
	
	print("🎬 Mudando para: %s" % next_scene_path)
	get_tree().change_scene_to_file(next_scene_path)

# ===== FUNÇÕES PÚBLICAS ÚTEIS =====

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

func set_next_scene(scene_path: String) -> void:
	"""Configura a próxima cena programaticamente"""
	next_scene_path = scene_path
	print("🎯 Próxima cena definida: %s" % scene_path)

func get_progress() -> float:
	"""Retorna o progresso dos diálogos (0.0 a 1.0)"""
	if dialogs.size() == 0:
		return 1.0
	return float(current_dialog_index) / float(dialogs.size())
