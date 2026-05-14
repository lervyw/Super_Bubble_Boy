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
	_apply_responsive_layout()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)

	# Inicializa diálogos
	if dialogs.size() > 0 and DialogBox:
		_set_current_dialog()
	else:
		dialogs_finished = true

	# Conecta botões
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.disabled = not dialogs_finished

	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		quit_button.disabled = not dialogs_finished

	# Inicia timer automático se necessário
	if not start_timer_after_dialogs or dialogs.is_empty():
		start_countdown()


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

	if timer_label:
		timer_label.anchor_left = 0.5
		timer_label.anchor_top = 0.0
		timer_label.anchor_right = 0.5
		timer_label.anchor_bottom = 0.0
		timer_label.offset_left = -18.0
		timer_label.offset_top = 150.0
		timer_label.offset_right = 22.0
		timer_label.offset_bottom = 178.0

	_place_button(continue_button, viewport_size, Vector2(-58.0, 186.0))
	_place_button(quit_button, viewport_size, Vector2(-58.0, 226.0))

	if animated_sprite:
		animated_sprite.position = Vector2(viewport_size.x * 0.72, viewport_size.y * 0.66)


func _fill_screen(node: Control) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _place_button(button: Button, viewport_size: Vector2, base_offset: Vector2) -> void:
	if not button:
		return

	var y := minf(base_offset.y, viewport_size.y - 52.0)
	button.anchor_left = 0.5
	button.anchor_top = 0.0
	button.anchor_right = 0.5
	button.anchor_bottom = 0.0
	button.offset_left = base_offset.x
	button.offset_top = y
	button.offset_right = base_offset.x + 116.0
	button.offset_bottom = y + 32.0
	button.scale = Vector2.ONE


# =======================
# ====== INPUT ==========
# =======================
func _input(event: InputEvent) -> void:
	# Durante diálogo
	if not dialogs_finished and dialogs.size() > 0:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("attack") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			advance_dialog()
		return

	# Após diálogo
	if dialogs_finished:
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
	if use_simple_dialog:
		current_dialog_index += 1

		if current_dialog_index < dialogs.size():
			_set_current_dialog()
		else:
			on_dialogs_finished()

		return

	# Sistema avançado (se usar DialogBox custom)
	if DialogBox.has_method("skip_dialog") and DialogBox.get("is_displaying"):
		DialogBox.skip_dialog()
		return

	current_dialog_index += 1
	if current_dialog_index < dialogs.size():
		_set_current_dialog()
	else:
		on_dialogs_finished()


func _set_current_dialog() -> void:
	if not DialogBox or current_dialog_index >= dialogs.size():
		return

	var dialog_text := dialogs[current_dialog_index]

	if DialogBox.has_method("set_dialog"):
		DialogBox.set_dialog(dialog_text)
	elif DialogBox is RichTextLabel or DialogBox is Label:
		DialogBox.text = dialog_text


func on_dialogs_finished() -> void:
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

func stop_countdown() -> void:
	is_counting = false

func update_timer_display() -> void:
	if timer_label:
		var seconds := int(ceil(time_remaining))
		timer_label.text = str(seconds)
		timer_label.modulate = Color.RED if seconds <= 3 and seconds > 0 else Color.WHITE


# =======================
# ===== AÇÕES ===========
# =======================

func _on_continue_pressed() -> void:
	print("▶ Continue selecionado")

	stop_countdown()
	_disable_buttons()

	if animated_sprite and animated_sprite.sprite_frames.has_animation(continue_animation_name):
		animated_sprite.play(continue_animation_name)

	await get_tree().create_timer(animation_delay).timeout

	# 🔥 Restaurar vidas e HP antes de reiniciar nível
	GameManager.restore_full_lives()
	#GameManager.restore_full_health()

	GameManager.restart_current_level()


func _on_quit_pressed() -> void:
	print("❌ Quit selecionado")

	stop_countdown()
	_disable_buttons()

	if animated_sprite and animated_sprite.sprite_frames.has_animation(giveup_animation_name):
		animated_sprite.play(giveup_animation_name)

	await get_tree().create_timer(animation_delay).timeout

	GameManager.reset_game()
	GameManager.goto_title()


func _on_timeout() -> void:
	print("⏱ Tempo esgotado → Quit automático")

	stop_countdown()
	_disable_buttons()

	if animated_sprite and animated_sprite.sprite_frames.has_animation(giveup_animation_name):
		animated_sprite.play(giveup_animation_name)

	await get_tree().create_timer(animation_delay).timeout

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
	current_dialog_index = dialogs.size()
	on_dialogs_finished()

func reset_dialogs() -> void:
	current_dialog_index = 0
	dialogs_finished = false
	if dialogs.size() > 0 and DialogBox:
		_set_current_dialog()

func add_time(seconds: float) -> void:
	time_remaining += seconds
	update_timer_display()

func set_time(seconds: float) -> void:
	time_remaining = seconds
	update_timer_display()

func get_time_remaining() -> float:
	return time_remaining

func pause_countdown() -> void:
	is_counting = false

func resume_countdown() -> void:
	is_counting = true

func get_progress() -> float:
	if dialogs.is_empty():
		return 1.0
	return float(current_dialog_index) / float(dialogs.size())
