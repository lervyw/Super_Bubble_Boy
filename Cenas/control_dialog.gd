extends Control

@export var DialogBox: RichTextLabel

@export_group("Diálogos")
@export var dialogs: Array[String] = [
	"Bubbleboy, nosso reino está em perigo.",
	"Um Sapo Maligno se esconde no castelo e ameaça tomar tudo para si.",
	"O Rei Slime guarda o portão, e suas tropas bloquearam o caminho até lá.",
	"Salve-nos, atravesse o reino e liberte todos dessa ameaça!"
]

@export_group("Botão de Avançar")
## Botão que avança os diálogos quando clicado
@export var advance_button: Button

@export_group("Configurações")
## Ação ao terminar diálogos (esconder, remover ou mudar cena)
@export_enum("Hide", "Remove", "Go To Level1", "Go To Title", "Go To Scene") var on_finish_action: int = 2

## Cena usada quando a ação final é "Go To Scene"
@export_file("*.tscn") var finish_scene_path: String = ""

## Texto do botão enquanto ainda existem falas para avançar
@export var advance_button_text: String = "Continuar"

## Texto do botão na última fala
@export var final_button_text: String = "Continuar"

## Tempo de espera antes de mudar de cena (em segundos)
@export_range(0.0, 5.0) var delay_before_scene_change: float = 0.5

var current_dialog_index: int = 0

func _ready() -> void:
	print("🎬 Cutscene iniciada")

	# Conecta o botão se existir
	if advance_button:
		advance_button.focus_mode = Control.FOCUS_ALL
		advance_button.text = advance_button_text
		advance_button.pressed.connect(_on_advance_button_pressed)
		advance_button.call_deferred("grab_focus")
		print("✅ Botão de avançar conectado")
	
	# Configura o primeiro diálogo
	if dialogs.size() > 0:
		DialogBox.set_dialog(dialogs[current_dialog_index])
		update_advance_button_text()
		print("📝 Diálogo 1/%d" % dialogs.size())
	else:
		push_warning("⚠️ Nenhum diálogo configurado!")

func _input(event: InputEvent) -> void:
	# Detecta clique do mouse, tecla de ação ou botão do controle
	if event.is_action_pressed("jump") or \
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
			update_advance_button_text()
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
		3:  # Go To Title - Vai para o menu
			print("🎬 Voltando ao menu principal...")
			go_to_title()
		4:  # Go To Scene - Vai para uma cena configurada
			print("🎬 Carregando cena configurada...")
			go_to_scene()
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

func go_to_title() -> void:
	"""Volta para o menu principal usando o GameManager"""
	if delay_before_scene_change > 0:
		await get_tree().create_timer(delay_before_scene_change).timeout

	GameManager.goto_title()

func go_to_scene() -> void:
	"""Vai para uma cena configurada no Inspector"""
	if finish_scene_path.is_empty():
		push_warning("⚠️ finish_scene_path vazio; voltando ao menu principal.")
		go_to_title()
		return

	if delay_before_scene_change > 0:
		await get_tree().create_timer(delay_before_scene_change).timeout

	get_tree().change_scene_to_file(finish_scene_path)

func update_advance_button_text() -> void:
	if not advance_button:
		return

	if dialogs.size() > 0 and current_dialog_index == dialogs.size() - 1:
		advance_button.text = final_button_text
	else:
		advance_button.text = advance_button_text

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
		update_advance_button_text()
	print("🔄 Diálogos reiniciados")

func get_progress() -> float:
	"""Retorna o progresso dos diálogos (0.0 a 1.0)"""
	if dialogs.size() == 0:
		return 1.0
	return float(current_dialog_index) / float(dialogs.size())
