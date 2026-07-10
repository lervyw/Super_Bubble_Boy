class_name VirtualJoystick
extends Control

## Virtual Joystick by Marco Fazio, adapted locally for Super Bubble Boy.
## Source: https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot

@export var pressed_color := Color.GRAY
@export_range(0, 200, 1) var deadzone_size: float = 10.0
@export_range(1, 500, 1) var clampzone_size: float = 75.0

enum JoystickMode { FIXED, DYNAMIC, FOLLOWING }
@export var joystick_mode := JoystickMode.FIXED

enum VisibilityMode { ALWAYS, TOUCHSCREEN_ONLY, WHEN_TOUCHED }
@export var visibility_mode := VisibilityMode.ALWAYS

@export var use_input_actions := false
@export var action_left := "ui_left"
@export var action_right := "ui_right"
@export var action_up := "ui_up"
@export var action_down := "ui_down"

var is_pressed := false
var output := Vector2.ZERO
var _touch_index: int = -1
var _pressed_actions: Array[String] = []

@onready var _base: Control = $Base
@onready var _tip: Control = $Base/Tip
@onready var _base_default_position: Vector2 = _base.position
@onready var _tip_default_position: Vector2 = _tip.position
@onready var _default_color: Color = _tip.modulate


func _ready() -> void:
	if not DisplayServer.is_touchscreen_available() and visibility_mode == VisibilityMode.TOUCHSCREEN_ONLY:
		hide()
	if visibility_mode == VisibilityMode.WHEN_TOUCHED:
		hide()
	_reset()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and _is_point_inside_joystick_area(event.position):
				if joystick_mode != JoystickMode.FIXED or _is_point_inside_base(event.position):
					if joystick_mode != JoystickMode.FIXED:
						_move_base(event.position)
					if visibility_mode == VisibilityMode.WHEN_TOUCHED:
						show()
					_touch_index = event.index
					_tip.modulate = pressed_color
					_update_joystick(event.position)
					get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_reset()
			if visibility_mode == VisibilityMode.WHEN_TOUCHED:
				hide()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()


func reset_joystick() -> void:
	_reset()


func _move_base(new_position: Vector2) -> void:
	_base.global_position = new_position - _base.pivot_offset * get_global_transform_with_canvas().get_scale()


func _move_tip(new_position: Vector2) -> void:
	_tip.global_position = new_position - _tip.pivot_offset * _base.get_global_transform_with_canvas().get_scale()


func _is_point_inside_joystick_area(point: Vector2) -> bool:
	var rect := get_global_rect()
	return rect.has_point(point)


func _get_base_radius() -> Vector2:
	return _base.size * _base.get_global_transform_with_canvas().get_scale() / 2.0


func _is_point_inside_base(point: Vector2) -> bool:
	var radius := _get_base_radius()
	var center := _base.global_position + radius
	return point.distance_squared_to(center) <= radius.x * radius.x


func _update_joystick(touch_position: Vector2) -> void:
	var radius := _get_base_radius()
	var center := _base.global_position + radius
	var vector := (touch_position - center).limit_length(clampzone_size)
	if joystick_mode == JoystickMode.FOLLOWING and touch_position.distance_to(center) > clampzone_size:
		_move_base(touch_position - vector)
	_move_tip(center + vector)
	if vector.length_squared() > deadzone_size * deadzone_size:
		is_pressed = true
		output = (vector - vector.normalized() * deadzone_size) / maxf(clampzone_size - deadzone_size, 1.0)
	else:
		is_pressed = false
		output = Vector2.ZERO
	if use_input_actions:
		_apply_input_actions()


func _apply_input_actions() -> void:
	_release_input_actions()
	var actions := [action_left, action_right, action_up, action_down]
	var strengths := [-output.x, output.x, -output.y, output.y]
	for index in actions.size():
		if strengths[index] > 0.0:
			Input.action_press(actions[index], strengths[index])
			_pressed_actions.append(actions[index])


func _release_input_actions() -> void:
	for action in _pressed_actions:
		Input.action_release(action)
	_pressed_actions.clear()


func _reset() -> void:
	is_pressed = false
	output = Vector2.ZERO
	_touch_index = -1
	if is_instance_valid(_tip):
		_tip.modulate = _default_color
		_tip.position = _tip_default_position
	if is_instance_valid(_base):
		_base.position = _base_default_position
	_release_input_actions()
