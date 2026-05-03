extends Panel

@export var state_texture: TextureRect
@export var up_button: TextureRect
@export var down_button: TextureRect
@export var left_button: TextureRect
@export var right_button: TextureRect

@export var active_panel_texture: Texture2D
@export var inactive_panel_texture: Texture2D
@export var activation_frames: Array[Texture2D] = []
@export_range(0.01, 0.5, 0.01) var activation_frame_time: float = 0.04

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
@export var selected_scale := Vector2.ONE

@export var normal_modulate := Color(1, 1, 1, 1)
@export var selected_modulate := Color(1.35, 1.35, 1.35, 1)
@export var disabled_modulate := Color(0.42, 0.42, 0.42, 0.85)
@export var cooldown_empty_modulate := Color(0.28, 0.28, 0.28, 0.9)

var special_attack_enabled: bool = true
var ultimate_enabled: bool = true
var menu_active: bool = false
var current_action_selection: String = "none"
var animation_version: int = 0
var button_progress_bars: Dictionary = {}


func _ready() -> void:
	visible = true
	_prepare_button_layouts()
	set_menu_active(false)
	set_action_selection("none")


func set_menu_active(active: bool) -> void:
	menu_active = active
	visible = true
	animation_version += 1

	_set_buttons_visible(false)

	if menu_active:
		play_activation_animation(animation_version)
	else:
		_set_state_texture(inactive_panel_texture)


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
	if not menu_active:
		action_name = "none"
	current_action_selection = action_name

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

	_refresh_cooldown_visuals()


func set_special_attack_cooldown_progress(progress: float) -> void:
	if progress < 1.0:
		_reset_button_visual(right_button, right_normal_texture)
	_set_button_cooldown_progress(right_button, clampf(progress, 0.0, 1.0))


func set_ultimate_cooldown_progress(progress: float) -> void:
	if progress < 1.0:
		_reset_button_visual(up_button, up_normal_texture)
	_set_button_cooldown_progress(up_button, clampf(progress, 0.0, 1.0))


func set_defend_cooldown_progress(progress: float) -> void:
	if progress < 1.0:
		_reset_button_visual(left_button, left_normal_texture)
	_set_button_cooldown_progress(left_button, clampf(progress, 0.0, 1.0))


func set_placeholder_cooldown_progress(progress: float) -> void:
	if progress < 1.0:
		_reset_button_visual(down_button, down_normal_texture)
	_set_button_cooldown_progress(down_button, clampf(progress, 0.0, 1.0))


func play_activation_animation(version: int) -> void:
	if activation_frames.is_empty():
		_set_state_texture(active_panel_texture)
		_set_buttons_visible(true)
		return

	for frame in activation_frames:
		if version != animation_version or not menu_active:
			return

		_set_state_texture(frame)
		await get_tree().create_timer(activation_frame_time).timeout

	if version != animation_version or not menu_active:
		return

	_set_state_texture(activation_frames.back())
	_set_buttons_visible(true)


func _set_state_texture(texture: Texture2D) -> void:
	if not state_texture:
		return

	state_texture.visible = true
	if texture:
		state_texture.texture = texture


func _set_buttons_visible(buttons_visible: bool) -> void:
	for button in [up_button, down_button, left_button, right_button]:
		if button:
			button.visible = buttons_visible


func _prepare_button_layouts() -> void:
	for button in [up_button, down_button, left_button, right_button]:
		if button:
			button.scale = normal_scale
			button.pivot_offset = button.size * 0.5


func _reset_button_visual(node: TextureRect, texture: Texture2D) -> void:
	if not node:
		return

	node.scale = normal_scale
	node.self_modulate = normal_modulate
	if texture:
		node.texture = texture
	_set_progress_texture(node, texture)


func _highlight_button(node: TextureRect, texture: Texture2D) -> void:
	if not node:
		return

	node.scale = normal_scale
	node.self_modulate = selected_modulate
	if texture:
		node.texture = texture
	_set_progress_texture(node, texture)


func _set_button_disabled(node: TextureRect) -> void:
	if not node:
		return

	node.self_modulate = disabled_modulate
	if disabled_texture:
		node.texture = disabled_texture
		_set_progress_texture(node, disabled_texture)


func _set_button_cooldown_progress(node: TextureRect, progress: float) -> void:
	if not node:
		return

	var progress_fill := _get_or_create_progress_fill(node)
	_update_progress_fill(node, progress_fill, progress)
	progress_fill.visible = progress < 1.0

	if progress < 1.0:
		node.self_modulate = cooldown_empty_modulate
	else:
		progress_fill.visible = false
		_restore_available_button_visual(node)


func _get_or_create_progress_fill(node: TextureRect) -> Control:
	if button_progress_bars.has(node):
		return button_progress_bars[node]

	var progress_fill := Control.new()
	progress_fill.name = "CooldownFill"
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_fill.clip_contents = true
	progress_fill.visible = false

	var fill_texture := TextureRect.new()
	fill_texture.name = "FillTexture"
	fill_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_texture.texture = node.texture
	fill_texture.expand_mode = node.expand_mode
	fill_texture.stretch_mode = node.stretch_mode
	progress_fill.add_child(fill_texture)

	node.add_child(progress_fill)
	button_progress_bars[node] = progress_fill
	return progress_fill


func _set_progress_texture(node: TextureRect, texture: Texture2D) -> void:
	if not node or not button_progress_bars.has(node):
		return
	var fill_texture := button_progress_bars[node].get_node_or_null("FillTexture") as TextureRect
	if fill_texture:
		fill_texture.texture = texture


func _refresh_cooldown_visuals() -> void:
	for progress_fill in button_progress_bars.values():
		if progress_fill is Control and progress_fill.size.y < progress_fill.get_parent().size.y:
			progress_fill.visible = true


func _update_progress_fill(node: TextureRect, progress_fill: Control, progress: float) -> void:
	var full_size := node.size
	var fill_height := full_size.y * progress
	var fill_top := full_size.y - fill_height

	progress_fill.position = Vector2(0.0, fill_top)
	progress_fill.size = Vector2(full_size.x, fill_height)

	var fill_texture := progress_fill.get_node_or_null("FillTexture") as TextureRect
	if not fill_texture:
		return

	fill_texture.position = Vector2(0.0, -fill_top)
	fill_texture.size = full_size


func _restore_available_button_visual(node: TextureRect) -> void:
	if not node:
		return
	if node == up_button and not ultimate_enabled:
		return
	if node == right_button and not special_attack_enabled:
		return

	var selected := (
		(node == up_button and current_action_selection == "ultimate_attack")
		or (node == down_button and current_action_selection == "placeholder")
		or (node == left_button and current_action_selection == "defend")
		or (node == right_button and current_action_selection == "attack_special")
	)

	node.self_modulate = selected_modulate if selected else normal_modulate
