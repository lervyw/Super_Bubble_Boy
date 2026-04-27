extends Panel

@export var up_button: TextureRect
@export var down_button: TextureRect
@export var left_button: TextureRect
@export var right_button: TextureRect

@export var up_normal_texture: Texture2D
@export var up_selected_texture: Texture2D
@export var down_normal_texture: Texture2D
@export var down_selected_texture: Texture2D
@export var left_normal_texture: Texture2D
@export var left_selected_texture: Texture2D
@export var right_normal_texture: Texture2D
@export var right_selected_texture: Texture2D
@export var disabled_texture: Texture2D

@export var normal_scale := Vector2.ONE
@export var selected_scale := Vector2(1.12, 1.12)

@export var normal_modulate := Color(1, 1, 1, 1)
@export var selected_modulate := Color(1.35, 1.35, 1.35, 1)
@export var disabled_modulate := Color(0.42, 0.42, 0.42, 0.85)

var special_attack_enabled: bool = true
var ultimate_enabled: bool = true


func _ready() -> void:
	visible = false
	set_action_selection("none")


func set_special_attack_enabled(enabled: bool) -> void:
	if special_attack_enabled == enabled:
		return
	special_attack_enabled = enabled
	set_action_selection("none")


func set_ultimate_enabled(enabled: bool) -> void:
	if ultimate_enabled == enabled:
		return
	ultimate_enabled = enabled
	set_action_selection("none")


func set_action_selection(action_name: String) -> void:
	_reset_button_visual(up_button, up_normal_texture)
	_reset_button_visual(down_button, down_normal_texture)
	_reset_button_visual(left_button, left_normal_texture)
	_reset_button_visual(right_button, right_normal_texture)

	if not ultimate_enabled:
		_set_button_disabled(up_button)
	if not special_attack_enabled:
		_set_button_disabled(right_button)

	match action_name:
		"ultimate_attack":
			if ultimate_enabled:
				_highlight_button(up_button, up_selected_texture)
		"placeholder":
			_highlight_button(down_button, down_selected_texture)
		"defend":
			_highlight_button(left_button, left_selected_texture)
		"attack_special":
			if special_attack_enabled:
				_highlight_button(right_button, right_selected_texture)


func _reset_button_visual(node: TextureRect, texture: Texture2D) -> void:
	if not node:
		return

	node.scale = normal_scale
	node.modulate = normal_modulate
	if texture:
		node.texture = texture


func _highlight_button(node: TextureRect, texture: Texture2D) -> void:
	if not node:
		return

	node.scale = selected_scale
	node.modulate = selected_modulate
	if texture:
		node.texture = texture


func _set_button_disabled(node: TextureRect) -> void:
	if not node:
		return

	node.modulate = disabled_modulate
	if disabled_texture:
		node.texture = disabled_texture
