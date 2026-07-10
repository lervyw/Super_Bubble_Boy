extends Area2D

enum State { IDLE, DIALOG_ACTIVE, DIALOG_FINISHED }

@export var dialog_speed: float = 0.035
@export var interaction_radius: float = 64.0
@export var player_group: StringName = &"jogador"

var state: int = State.IDLE
var player_node: Node = null
var current_dialog_index: int = 0
var dialogs: Array[String] = [
	"Você está próximo da entrada do castelo.",
	"Lembre-se que o Slime Rei está protegendo a entrada e ele é muito forte!",
	"Eu poderia te acompanhar, mas recusaram minha ajuda, você está por si só."
]

var _display_timer: Timer
var _current_text: String = ""
var _current_char_index: int = 0
var _is_typing: bool = false

@onready var dialog_panel: Panel = $"../DialogPanel"
@onready var name_label: Label = $"../DialogPanel/NameLabel"
@onready var dialog_label: RichTextLabel = $"../DialogPanel/DialogLabel"
@onready var continue_prompt: Button = $"../DialogPanel/ContinuePrompt"
@onready var prompt_label: Label = $"../PromptLabel"
var prompt_icon: TextureRect


func _ready():
	prompt_icon = TextureRect.new()
	prompt_icon.name = "InputPromptIcon"
	prompt_icon.custom_minimum_size = Vector2(16, 16)
	prompt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prompt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prompt_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_icon.position = Vector2(24, 2)
	prompt_label.add_child(prompt_icon)
	prompt_label.text = "Falar"
	if not ControllerMapper.input_source_changed.is_connected(_on_input_source_changed):
		ControllerMapper.input_source_changed.connect(_on_input_source_changed)
	_update_prompt_icon()
	dialog_panel.visible = false
	continue_prompt.visible = false
	prompt_label.visible = false

	_display_timer = Timer.new()
	_display_timer.wait_time = dialog_speed
	_display_timer.one_shot = false
	_display_timer.timeout.connect(_on_display_tick)
	add_child(_display_timer)

	continue_prompt.pressed.connect(_on_continue_pressed)


func _on_input_source_changed(_source: int, _controller_type: int) -> void:
	_update_prompt_icon()


func _update_prompt_icon() -> void:
	if prompt_icon:
		prompt_icon.texture = PromptIcons.for_action(&"attack")


func _process(_delta: float):
	var player = _find_player_in_range()

	if player:
		player_node = player
		if state == State.IDLE:
			start_dialog()
			return
		elif state == State.DIALOG_FINISHED:
			prompt_label.visible = true
			if Input.is_action_just_pressed("attack"):
				print("[Fabian] C manual — restartando diálogo")
				start_dialog()
			return
	else:
		if state != State.DIALOG_ACTIVE:
			prompt_label.visible = false
			player_node = null

	if state == State.DIALOG_ACTIVE:
		if Input.is_action_just_pressed("attack"):
			advance_dialog()


func _find_player_in_range():
	for group_name in [player_group, &"player"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is CharacterBody2D:
				if global_position.distance_to(node.global_position) <= interaction_radius:
					return node
	return null


func start_dialog():
	if state == State.DIALOG_ACTIVE:
		return
	state = State.DIALOG_ACTIVE
	current_dialog_index = 0

	player_node.set_process(false)
	player_node.set_physics_process(false)
	player_node.set_process_input(false)
	player_node.set_process_unhandled_input(false)

	dialog_panel.visible = true
	prompt_label.visible = false
	show_current_dialog()


func show_current_dialog():
	if current_dialog_index >= dialogs.size():
		end_dialog()
		return

	name_label.text = "Fabian"
	_current_text = dialogs[current_dialog_index]
	_current_char_index = 0
	dialog_label.visible_characters = 0
	dialog_label.text = _current_text
	continue_prompt.visible = false
	_is_typing = true
	_display_timer.start()


func _on_display_tick():
	if _current_char_index < _current_text.length():
		_current_char_index += 1
		dialog_label.visible_characters = _current_char_index
	else:
		_display_timer.stop()
		_is_typing = false
		continue_prompt.visible = true


func _on_continue_pressed():
	advance_dialog()


func advance_dialog():
	if _is_typing:
		_display_timer.stop()
		dialog_label.visible_characters = _current_text.length()
		_is_typing = false
		continue_prompt.visible = true
		return

	current_dialog_index += 1
	show_current_dialog()


func end_dialog():
	_display_timer.stop()
	state = State.DIALOG_FINISHED
	dialog_panel.visible = false

	if player_node:
		player_node.set_process(true)
		player_node.set_physics_process(true)
		player_node.set_process_input(true)
		player_node.set_process_unhandled_input(true)

	if _find_player_in_range():
		prompt_label.visible = true
