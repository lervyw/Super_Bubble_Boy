extends Control

# =======================
# ====== DIÁLOGOS =======
# =======================
@export_group("Diálogo")
@export var DialogBox: Node

@export_subgroup("Textos dos Diálogos")
@export var dialogs: Array[String] = [
	"Você pode tentar de novo",
	"Se quiser...",
	"Vai continuar?"
]

@export var use_simple_dialog: bool = true

# =======================
# ====== ANIMAÇÃO =======
# =======================
@export_group("Animação")
@export var animated_sprite: AnimatedSprite2D
@export var continue_animation_name: String = "continue"
@export var giveup_animation_name: String = "giveup"
@export_range(0.0, 5.0) var animation_delay: float = 1.5

# =======================
# ====== BOTÕES =========
# =======================
@export_group("Botões")
@export var continue_button: Button
@export var quit_button: Button

# =======================
# ===== TIMER ===========
# =======================
@export_group("Timer Display")
@export var timer_label: Label

@export_group("Configurações")
@export_range(1.0, 60.0) var countdown_time: float = 10.0
@export var start_timer_after_dialogs: bool = true

# =======================
# ===== VARIÁVEIS =======
# =======================
var current_dialog_index: int = 0
var time_remaining: float = 0.0
var is_counting: bool = false
var dialogs_finished: bool = false

# =======================
# ====== READY ==========
# =======================
func _ready() -> void:
	print("🎮 Continue Screen carregado")
	print("   Nível atual: " + GameManager.get_current_level())
	
	# Valida AnimatedSprite2D
	if not animated_sprite:
		push_warning("⚠️ AnimatedSprite2D não configurado!")
	
	# Inicializa diálogos
	if dialogs.size() > 0 and DialogBox:
		_set_current_dialog()
		print("📝 Diálogo 1/%d iniciado" % dialogs.size())
	else:
		if not DialogBox:
			push_warning("⚠️ DialogBox não configurado!")
		if dialogs.is_empty():
			push_warning("⚠️ Nenhum diálogo configurado!")
		dialogs_finished = true

	# Conecta botões
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.disabled = not dialogs_finished
		print("✅ Botão Continue conectado")
	else:
		push_warning("⚠️ Botão Continue não configurado!")

	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		quit_button.disabled = not dialogs_finished
		print("✅ Botão Desistir conectado")
	else:
		push_warning("⚠️ Botão Desistir não configurado!")

	# Inicia timer
	if not start_timer_after_dialogs or dialogs.is_empty():
		start_countdown()

# =======================
# ====== INPUT ==========
# =======================
func _input(event: InputEvent) -> void:
	# Durante os diálogos - avança com qualquer input
	if not dialogs_finished and dialogs.size() > 0:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("attack") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			advance_dialog()
	
	# Após diálogos - atalhos de teclado
	elif dialogs_finished:
		if event.is_action_pressed("jump") or event.is_action_pressed("ui_up"):
			if continue_button and not continue_button.disabled:
				_on_continue_pressed()
		elif event.is_action_pressed("dash"):
			if quit_button and not quit_button.disabled:
				_on_quit_pressed()

# =======================
# ===== PROCESS =========
# =======================
func _process(delta: float) -> void:
	if is_counting:
		time_remaining -= delta
		update_timer_display()
		if time_remaining <= 0.0:
			time_remaining = 0.0
			_on_timeout()

# =======================
# ===== DIALOGOS ========
# =======================
func advance_dialog() -> void:
	if not DialogBox:
		return

	if use_simple_dialog:
		current_dialog_index += 1
		if current_dialog_index < dialogs.size():
			_set_current_dialog()
			print("📝 Diálogo %d/%d" % [current_dialog_index + 1, dialogs.size()])
		else:
			on_dialogs_finished()
		return

	# Sistema avançado de diálogos
	if DialogBox.has_method("skip_dialog") and DialogBox.get("is_displaying"):
		DialogBox.skip_dialog()
		return

	var can_advance := true
	if DialogBox.has_method("is_ready_to_advance"):
		can_advance = DialogBox.is_ready_to_advance()

	if can_advance:
		current_dialog_index += 1
		if current_dialog_index < dialogs.size():
			_set_current_dialog()
			print("📝 Diálogo %d/%d" % [current_dialog_index + 1, dialogs.size()])
		else:
			on_dialogs_finished()

func _set_current_dialog() -> void:
	if not DialogBox or current_dialog_index >= dialogs.size():
		return

	var dialog_text = dialogs[current_dialog_index]
	
	if DialogBox.has_method("set_dialog"):
		DialogBox.set_dialog(dialog_text)
	elif DialogBox is RichTextLabel or DialogBox is Label:
		DialogBox.text = dialog_text
	else:
		push_warning("⚠️ DialogBox não suporta set_dialog() nem é Label/RichTextLabel")

func on_dialogs_finished() -> void:
	print("✅ Diálogos finalizados!")
	dialogs_finished = true
	
	if continue_button:
		continue_button.disabled = false
	if quit_button:
		quit_button.disabled = false
	
	if start_timer_after_dialogs:
		start_countdown()

# =======================
# ===== TIMER ===========
# =======================
func start_countdown() -> void:
	time_remaining = countdown_time
	is_counting = true
	update_timer_display()
	print("⏰ Timer iniciado: %.0f segundos" % countdown_time)

func stop_countdown() -> void:
	is_counting = false
	print("⏸️ Timer parado")

func update_timer_display() -> void:
	if timer_label:
		var seconds: int = int(ceil(time_remaining))
		timer_label.text = str(seconds)
		
		# Muda cor para vermelho nos últimos 3 segundos
		if seconds <= 3 and seconds > 0:
			timer_label.modulate = Color.RED
		else:
			timer_label.modulate = Color.WHITE

# =======================
# ===== AÇÕES ===========
# =======================
func _on_continue_pressed() -> void:
	print("✅ Continue pressionado - Reproduzindo animação...")
	stop_countdown()
	_disable_buttons()

	# Animação de continue
	if animated_sprite and animated_sprite.sprite_frames.has_animation(continue_animation_name):
		animated_sprite.play(continue_animation_name)
		print("🎬 Animação '%s' iniciada" % continue_animation_name)

	await get_tree().create_timer(animation_delay).timeout

	# 🔥 NÃO reset_game() aqui!!
	# resetar vidas é via GameManager, não resetar tudo

	print("🎮 Carregando nível novamente...")

	# Restaura apenas vidas e HP
	GameManager.restore_full_lives()

	# Se tiver stats globais, reseta
	GameManager.restore_full_health()

	GameManager.restart_current_level()



func _on_quit_pressed() -> void:
	print("❌ Desistir pressionado - Reproduzindo animação...")
	stop_countdown()
	_disable_buttons()

	if animated_sprite and animated_sprite.sprite_frames.has_animation(giveup_animation_name):
		animated_sprite.play(giveup_animation_name)

	await get_tree().create_timer(animation_delay).timeout

	print("🏠 Voltando ao menu...")

	# Aqui sim resetamos tudo
	GameManager.reset_game()
	GameManager.goto_title()



func _on_timeout() -> void:
	print("⏰ Timeout! Reproduzindo animação de desistir...")
	stop_countdown()
	_disable_buttons()

	if animated_sprite and animated_sprite.sprite_frames.has_animation(giveup_animation_name):
		animated_sprite.play(giveup_animation_name)

	await get_tree().create_timer(animation_delay).timeout

	print("🏠 Voltando ao menu...")

	GameManager.reset_game()
	GameManager.goto_title()



func _disable_buttons() -> void:
	if continue_button:
		continue_button.disabled = true
	if quit_button:
		quit_button.disabled = true

# =======================
# ===== UTILITÁRIAS =====
# =======================
func skip_all_dialogs() -> void:
	"""Pula todos os diálogos restantes"""
	current_dialog_index = dialogs.size()
	on_dialogs_finished()

func reset_dialogs() -> void:
	"""Reseta os diálogos para o início"""
	current_dialog_index = 0
	dialogs_finished = false
	if dialogs.size() > 0 and DialogBox:
		_set_current_dialog()

func add_time(seconds: float) -> void:
	"""Adiciona tempo ao contador"""
	time_remaining += seconds
	update_timer_display()

func set_time(seconds: float) -> void:
	"""Define um novo tempo"""
	time_remaining = seconds
	update_timer_display()

func get_time_remaining() -> float:
	"""Retorna o tempo restante"""
	return time_remaining

func pause_countdown() -> void:
	"""Pausa o contador sem resetar"""
	is_counting = false

func resume_countdown() -> void:
	"""Resume o contador"""
	is_counting = true

func get_progress() -> float:
	"""Retorna o progresso dos diálogos (0.0 a 1.0)"""
	if dialogs.is_empty():
		return 1.0
	return float(current_dialog_index) / float(dialogs.size())
