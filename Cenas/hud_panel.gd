extends Panel

@export var attack_special_button: Control
@export var defend_button: Control

@export var normal_scale := Vector2.ONE
@export var selected_scale := Vector2(1.12, 1.12)

@export var normal_modulate := Color(1, 1, 1, 1)
@export var selected_modulate := Color(1.3, 1.3, 1.3, 1)

func _ready() -> void:
	visible = false
	set_action_selection("none")

func set_action_selection(action_name: String) -> void:
	_reset_button_visual(attack_special_button)
	_reset_button_visual(defend_button)

	match action_name:
		"attack_special":
			_highlight_button(attack_special_button)

		"defend":
			_highlight_button(defend_button)

func _reset_button_visual(node: Control) -> void:
	if not node:
		return

	node.scale = normal_scale
	node.modulate = normal_modulate

func _highlight_button(node: Control) -> void:
	if not node:
		return

	node.scale = selected_scale
	node.modulate = selected_modulate
