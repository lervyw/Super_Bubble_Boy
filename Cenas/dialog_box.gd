# DialogBox.gd - Versão com Timer interno (mais estável)
extends RichTextLabel

const CHARACTER_SPEED: float = 0.035

var is_displaying: bool = false
var can_advance: bool = false
var _display_timer: Timer
var _current_text: String = ""
var _current_index: int = 0

func _ready():
	# Cria o timer internamente
	_display_timer = Timer.new()
	_display_timer.wait_time = CHARACTER_SPEED
	_display_timer.one_shot = false
	_display_timer.timeout.connect(_on_display_tick)
	add_child(_display_timer)

func set_dialog(string: String):
	# Para qualquer animação anterior
	if _display_timer and _display_timer.is_inside_tree():
		_display_timer.stop()
	
	visible_characters = 0
	text = string
	_current_text = string
	_current_index = 0
	is_displaying = true
	can_advance = false
	
	# Se o timer existe e está na árvore, inicia
	if _display_timer and _display_timer.is_inside_tree():
		_display_timer.start()
	else:
		# Fallback: mostra tudo imediatamente
		visible_characters = text.length()
		is_displaying = false
		can_advance = true

func _on_display_tick():
	if _current_index < _current_text.length():
		_current_index += 1
		visible_characters = _current_index
	else:
		# Terminou de exibir
		_display_timer.stop()
		is_displaying = false
		can_advance = true

func is_ready_to_advance() -> bool:
	return can_advance

func skip_dialog():
	if is_displaying:
		if _display_timer:
			_display_timer.stop()
		visible_characters = text.length()
		is_displaying = false
		can_advance = true
