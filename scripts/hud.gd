extends CanvasLayer

@export var player: CharacterBody2D
@export var stats: Node
@export var heart_icons: Array[TextureRect] = []
@export var hp_bar: TextureProgressBar
@export var mana_bar: TextureProgressBar
@export var stamina_bar: TextureProgressBar
@export var ultimate_bar: TextureProgressBar
@export var ultimate_ready_icon: TextureRect
@export var boss_hp_bar: TextureProgressBar
@export var menu_panel: Panel
@export var pause_menu_panel: Control
@export var warning_label: Label
@export var passive_toggle: CheckButton
@export var passive_icons: Array[TextureRect] = []
@export var pause_passive_icons: Array[Control] = []
@export var resume_button: Button
@export var main_menu_button: Button
@export var quit_button: Button
@export var ultimate_cooldown_bar: TextureProgressBar
@export var time_bubble_panel: Control
@export var time_bubble_label: Label
@export var ultimate_cooldown_bar_position: Vector2 = Vector2(14.0, 19.0)
@export var ultimate_cooldown_bar_size: Vector2 = Vector2(24.0, 52.0)

@export var soap_label: Label

const PASSIVE_ICON_STOMP := preload("res://sprites/assets/bolha_ressonante.png")
const PASSIVE_ICON_RUN := preload("res://sprites/assets/Corrida.png")
const UI_JOYPAD_DEADZONE: float = 0.5
const UI_NAV_ACTIONS: Array[StringName] = [
	&"ui_accept",
	&"ui_select",
	&"ui_cancel",
	&"ui_up",
	&"ui_down",
	&"ui_left",
	&"ui_right",
	&"ui_start",
	&"pause_menu",
]

var boss_target: Node = null
var pause_menu_open: bool = false
var warning_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_controller_ui_actions()

	if menu_panel:
		menu_panel.visible = true
		if menu_panel.has_method("set_menu_active"):
			menu_panel.set_menu_active(false)
	if pause_menu_panel:
		pause_menu_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_menu_panel.visible = false
		apply_pause_menu_aero_style()
	if passive_toggle:
		passive_toggle.process_mode = Node.PROCESS_MODE_ALWAYS
		passive_toggle.visible = true
		if not passive_toggle.toggled.is_connected(_on_passive_toggle_toggled):
			passive_toggle.toggled.connect(_on_passive_toggle_toggled)
	for i in pause_passive_icons.size():
		var icon = pause_passive_icons[i] as Button
		if icon:
			icon.process_mode = Node.PROCESS_MODE_ALWAYS
			if not icon.pressed.is_connected(_on_pause_passive_icon_pressed.bind(i)):
				icon.pressed.connect(_on_pause_passive_icon_pressed.bind(i))

	_setup_pause_focus_order()
	if ultimate_bar:
		ultimate_bar.min_value = 0.0
		ultimate_bar.max_value = 1.0
		ultimate_bar.fill_mode = 3
		ultimate_bar.value = 0.0
	setup_ultimate_cooldown_bar()
	if ultimate_ready_icon:
		ultimate_ready_icon.visible = false
		ultimate_ready_icon.modulate.a = 0.0
	if warning_label:
		warning_label.visible = false
		warning_label.modulate.a = 0.0
	if resume_button:
		resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
		if not resume_button.pressed.is_connected(close_pause_menu):
			resume_button.pressed.connect(close_pause_menu)
	if main_menu_button:
		main_menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
		if not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
			main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button:
		quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
		if not quit_button.pressed.is_connected(_on_quit_pressed):
			quit_button.pressed.connect(_on_quit_pressed)
	if boss_hp_bar:
		boss_hp_bar.visible = false
	if time_bubble_panel:
		time_bubble_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_start"):
		toggle_pause_menu()
		_mark_input_handled()
		return
	if pause_menu_open and event.is_action_pressed("ui_cancel"):
		close_pause_menu()
		_mark_input_handled()
		return
	if pause_menu_open and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select")):
		for btn in [resume_button, main_menu_button, quit_button, passive_toggle]:
			if btn and btn.has_focus():
				_mark_input_handled()
				btn.pressed.emit()
				return
		for icon in pause_passive_icons:
			if icon and icon is Button and icon.has_focus():
				_mark_input_handled()
				icon.pressed.emit()
				return


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.set_input_as_handled()


func _process(delta: float) -> void:
	if not player:
		return

	_update_hp_bar()
	_set_hearts_visible(false)
	_set_hp_visible(true)

	_update_mana_bar()
	_set_mana_visible(_is_mana_visible())
	_update_stamina_bar()
	_update_ultimate_bar(delta)
	_update_passive_icons()
	_update_menu_panel_state()
	_update_pause_menu_state()
	_update_time_bubble_counter()
	_update_soap_counter()


func _update_hearts() -> void:
	var lives := GameManager.get_lives()

	for i in range(heart_icons.size()):
		var heart := heart_icons[i]
		if heart:
			heart.visible = i < lives


func _update_hp_bar() -> void:
	if not hp_bar or not stats:
		return

	var current: float = float(stats.current_health)
	var max_hp: float = float(stats.max_health)
	hp_bar.max_value = max_hp
	hp_bar.value = current


func _update_mana_bar() -> void:
	if not mana_bar or not stats:
		return

	mana_bar.max_value = float(stats.get("max_mana"))
	mana_bar.value = float(stats.get("current_mana"))


func _update_stamina_bar() -> void:
	if not stamina_bar or not stats:
		return

	stamina_bar.max_value = float(stats.get("max_stamina"))
	stamina_bar.value = float(stats.get("current_stamina"))


func _update_ultimate_bar(_delta: float) -> void:
	if not player:
		return

	var cooldown_progress: float = 1.0
	if player.has_method("get_ultimate_cooldown_progress"):
		cooldown_progress = player.get_ultimate_cooldown_progress()

	_update_ultimate_cooldown_bar(cooldown_progress)
	_update_ultimate_ready_icon(cooldown_progress)


func _update_ultimate_ready_icon(cooldown_progress: float) -> void:
	if not ultimate_ready_icon:
		return

	var ready := cooldown_progress >= 1.0
	if player and player.has_method("can_use_ultimate_attack"):
		ready = player.can_use_ultimate_attack()

	ultimate_ready_icon.visible = ready
	ultimate_ready_icon.modulate.a = 1.0 if ready else 0.0


func setup_ultimate_cooldown_bar() -> void:
	if ultimate_cooldown_bar:
		ultimate_cooldown_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ultimate_cooldown_bar.min_value = 0.0
		ultimate_cooldown_bar.max_value = 100.0
		ultimate_cooldown_bar.fill_mode = 3
		_update_ultimate_cooldown_bar(0.0)
		return

	ultimate_cooldown_bar = TextureProgressBar.new()
	ultimate_cooldown_bar.name = "UltimateCooldownBar"
	ultimate_cooldown_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_cooldown_bar.position = ultimate_cooldown_bar_position
	ultimate_cooldown_bar.size = ultimate_cooldown_bar_size
	ultimate_cooldown_bar.min_value = 0.0
	ultimate_cooldown_bar.max_value = 100.0
	ultimate_cooldown_bar.fill_mode = 3
	add_child(ultimate_cooldown_bar)
	if ultimate_ready_icon:
		move_child(ultimate_cooldown_bar, ultimate_ready_icon.get_index())

	_update_ultimate_cooldown_bar(0.0)


func _update_ultimate_cooldown_bar(progress: float) -> void:
	if not ultimate_cooldown_bar:
		return

	ultimate_cooldown_bar.value = clampf(progress, 0.0, 1.0) * ultimate_cooldown_bar.max_value


func show_mana_warning(message: String = "sem mana suficiente") -> void:
	show_warning_message(message)


func show_warning_message(message: String) -> void:
	if not warning_label:
		return

	if warning_tween:
		warning_tween.kill()

	warning_label.text = message
	warning_label.visible = true
	warning_label.modulate = Color(1, 1, 1, 1)
	warning_label.position = Vector2(110.0, 104.0)

	warning_tween = create_tween()
	warning_tween.set_parallel(true)
	warning_tween.tween_property(warning_label, "position:x", 106.0, 0.05)
	warning_tween.tween_property(warning_label, "position:x", 114.0, 0.05).set_delay(0.05)
	warning_tween.tween_property(warning_label, "position:x", 108.0, 0.05).set_delay(0.10)
	warning_tween.tween_property(warning_label, "position:x", 112.0, 0.05).set_delay(0.15)
	warning_tween.tween_property(warning_label, "position:x", 110.0, 0.05).set_delay(0.20)
	warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.35).set_delay(0.65)

	await warning_tween.finished
	if warning_label:
		warning_label.visible = false


func _is_mana_visible() -> bool:
	if stats and stats.has_method("is_mana_visible"):
		return stats.is_mana_visible()
	if player and player.has_method("can_use_mana_system"):
		return player.can_use_mana_system()
	return false


func _update_menu_panel_state() -> void:
	if not menu_panel:
		return
	if menu_panel.has_method("set_special_attack_enabled") and player:
		menu_panel.set_special_attack_enabled(player.can_use_mana_attacks())
	if menu_panel.has_method("set_ultimate_enabled") and player:
		menu_panel.set_ultimate_enabled(player.allow_ultimate_input and player.ultimate_attack_enabled and player.can_use_mana_attacks())
	if player.form == player.Form.SUPER and player.has_method("get_super_wheel_cooldown_progress"):
		menu_panel.set_ultimate_cooldown_progress(player.get_super_wheel_cooldown_progress(0))
		menu_panel.set_special_attack_cooldown_progress(player.get_super_wheel_cooldown_progress(1))
		menu_panel.set_bubble_projectile_cooldown_progress(player.get_super_wheel_cooldown_progress(2))
		menu_panel.set_placeholder_cooldown_progress(player.get_super_wheel_cooldown_progress(3))
	else:
		if menu_panel.has_method("set_ultimate_cooldown_progress"):
			menu_panel.set_ultimate_cooldown_progress(1.0)
		if menu_panel.has_method("set_special_attack_cooldown_progress") and player and player.has_method("get_active_attack_cooldown_progress"):
			menu_panel.set_special_attack_cooldown_progress(player.get_active_attack_cooldown_progress())
		if menu_panel.has_method("set_bubble_projectile_cooldown_progress") and player and player.has_method("get_bubble_projectile_cooldown_progress"):
			menu_panel.set_bubble_projectile_cooldown_progress(player.get_bubble_projectile_cooldown_progress())
		if menu_panel.has_method("set_placeholder_cooldown_progress"):
			menu_panel.set_placeholder_cooldown_progress(1.0)

	_sync_wheel_slot_unlocks()


func _update_time_bubble_counter() -> void:
	if not time_bubble_panel or not time_bubble_label or not player:
		return
	var active: bool = player.has_method("is_time_bubble_active") and bool(player.is_time_bubble_active())
	time_bubble_panel.visible = active
	if active and player.has_method("get_time_bubble_time_left"):
		time_bubble_label.text = "%.1f" % player.get_time_bubble_time_left()


func _sync_wheel_slot_unlocks() -> void:
	if not player or not menu_panel or not menu_panel.has_method("set_slot_unlocked"):
		return
	if not player.has_method("is_wheel_slot_unlocked"):
		return

	menu_panel.set_slot_unlocked("ultimate_attack", player.is_wheel_slot_unlocked(0))
	menu_panel.set_slot_unlocked("attack_special", player.is_wheel_slot_unlocked(1))
	menu_panel.set_slot_unlocked("bubble_projectile", player.is_wheel_slot_unlocked(2))
	menu_panel.set_slot_unlocked("placeholder", player.is_wheel_slot_unlocked(3))


func _update_pause_menu_state() -> void:
	if not pause_menu_open:
		return
	if passive_toggle and player:
		var passives_enabled := _are_player_passives_enabled()
		if passive_toggle.button_pressed != passives_enabled:
			passive_toggle.set_pressed_no_signal(passives_enabled)
	_update_passive_icons()


func _set_hearts_visible(v: bool) -> void:
	for h in heart_icons:
		if h:
			h.visible = v


func _set_hp_visible(v: bool) -> void:
	if hp_bar:
		hp_bar.visible = v


func _set_mana_visible(v: bool) -> void:
	if mana_bar:
		mana_bar.visible = v


func set_boss_target(target: Node) -> void:
	if boss_target == target:
		return

	if boss_target:
		_disconnect_boss_signals(boss_target)

	boss_target = target

	if boss_target == null:
		_set_boss_hp_visible(false)
		return

	_connect_boss_signals(boss_target)
	_refresh_boss_bar()

	if boss_target.has_method("is_hud_visible"):
		_set_boss_hp_visible(boss_target.is_hud_visible())


func _connect_boss_signals(target: Node) -> void:
	var health_changed := Callable(self, "_on_boss_health_changed")
	var hud_visibility_changed := Callable(self, "_on_boss_hud_visibility_changed")
	var boss_defeated := Callable(self, "_on_boss_defeated")

	if target.has_signal("health_changed") and not target.is_connected("health_changed", health_changed):
		target.connect("health_changed", health_changed)
	if target.has_signal("hud_visibility_changed") and not target.is_connected("hud_visibility_changed", hud_visibility_changed):
		target.connect("hud_visibility_changed", hud_visibility_changed)
	if target.has_signal("boss_defeated") and not target.is_connected("boss_defeated", boss_defeated):
		target.connect("boss_defeated", boss_defeated)


func _disconnect_boss_signals(target: Node) -> void:
	var health_changed := Callable(self, "_on_boss_health_changed")
	var hud_visibility_changed := Callable(self, "_on_boss_hud_visibility_changed")
	var boss_defeated := Callable(self, "_on_boss_defeated")

	if target.has_signal("health_changed") and target.is_connected("health_changed", health_changed):
		target.disconnect("health_changed", health_changed)
	if target.has_signal("hud_visibility_changed") and target.is_connected("hud_visibility_changed", hud_visibility_changed):
		target.disconnect("hud_visibility_changed", hud_visibility_changed)
	if target.has_signal("boss_defeated") and target.is_connected("boss_defeated", boss_defeated):
		target.disconnect("boss_defeated", boss_defeated)


func _refresh_boss_bar() -> void:
	if not boss_hp_bar or boss_target == null:
		return

	var current := float(boss_target.get("health"))
	var max_hp := float(boss_target.get("max_health"))
	boss_hp_bar.max_value = max_hp
	boss_hp_bar.value = current


func _on_boss_health_changed(current_health: int, max_health: int) -> void:
	if not boss_hp_bar:
		return
	boss_hp_bar.max_value = float(max_health)
	boss_hp_bar.value = float(current_health)


func _on_boss_hud_visibility_changed(visible: bool) -> void:
	_set_boss_hp_visible(visible)
	if visible:
		_refresh_boss_bar()


func _on_boss_defeated() -> void:
	_set_boss_hp_visible(false)


func _set_boss_hp_visible(v: bool) -> void:
	if boss_hp_bar:
		boss_hp_bar.visible = v


func show_menu() -> void:
	if menu_panel:
		menu_panel.visible = true
		if menu_panel.has_method("set_menu_active"):
			menu_panel.set_menu_active(true)

		if menu_panel.has_method("set_action_selection"):
			menu_panel.set_action_selection("none")


func hide_menu() -> void:
	if menu_panel:
		menu_panel.visible = true
		if menu_panel.has_method("set_menu_active"):
			menu_panel.set_menu_active(false)

		if menu_panel.has_method("set_action_selection"):
			menu_panel.set_action_selection("none")


func update_action_selection(action_name: String) -> void:
	if menu_panel and menu_panel.has_method("set_action_selection"):
		menu_panel.set_action_selection(action_name)


func toggle_pause_menu() -> void:
	if pause_menu_open:
		close_pause_menu()
	else:
		open_pause_menu()


func open_pause_menu() -> void:
	pause_menu_open = true
	if player and player.has_method("close_hud_menu"):
		player.close_hud_menu()
	get_tree().paused = true

	if pause_menu_panel:
		pause_menu_panel.visible = true
		_grab_focus_deferred(resume_button)

	if passive_toggle and player:
		passive_toggle.set_pressed_no_signal(_are_player_passives_enabled())
	_update_passive_icons()


func close_pause_menu() -> void:
	pause_menu_open = false

	if pause_menu_panel:
		pause_menu_panel.visible = false

	get_tree().paused = false


func _grab_focus_deferred(control: Control) -> void:
	if not control:
		return
	control.call_deferred("grab_focus")


func _ensure_controller_ui_actions() -> void:
	for action_name in UI_NAV_ACTIONS:
		_ensure_action(action_name)

	_add_joy_button_once("ui_accept", 0)
	_add_joy_button_once("ui_select", 0)
	_add_joy_button_once("ui_cancel", 1)
	_add_joy_button_once("ui_start", 6)
	_add_joy_button_once("pause_menu", 6)
	_add_joy_button_once("ui_up", 11)
	_add_joy_button_once("ui_down", 12)
	_add_joy_button_once("ui_left", 13)
	_add_joy_button_once("ui_right", 14)

	_add_joy_axis_once("ui_left", 0, -1.0)
	_add_joy_axis_once("ui_right", 0, 1.0)
	_add_joy_axis_once("ui_up", 1, -1.0)
	_add_joy_axis_once("ui_down", 1, 1.0)
	_add_key_once("ui_cancel", KEY_ESCAPE)


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, UI_JOYPAD_DEADZONE)


func _add_joy_button_once(action_name: StringName, button_index: int) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and event.device == -1 and event.button_index == button_index:
			return

	var joy_event := InputEventJoypadButton.new()
	joy_event.device = -1
	joy_event.button_index = button_index
	InputMap.action_add_event(action_name, joy_event)


func _add_joy_axis_once(action_name: StringName, axis: int, axis_value: float) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion and event.device == -1 and event.axis == axis and sign(event.axis_value) == sign(axis_value):
			return

	var joy_event := InputEventJoypadMotion.new()
	joy_event.device = -1
	joy_event.axis = axis
	joy_event.axis_value = axis_value
	InputMap.action_add_event(action_name, joy_event)


func _add_key_once(action_name: StringName, physical_keycode: int) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == physical_keycode:
			return

	var key_event := InputEventKey.new()
	key_event.device = -1
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, key_event)


func _on_passive_toggle_toggled(enabled: bool) -> void:
	if player and player.has_method("set_passive_powers_enabled"):
		player.set_passive_powers_enabled(enabled)


func _are_player_passives_enabled() -> bool:
	if player and player.has_method("are_passive_powers_enabled"):
		return player.are_passive_powers_enabled()
	return true


func _update_passive_icons() -> void:
	var selected := 0
	if player and player.has_method("get_selected_passive_power"):
		selected = player.get_selected_passive_power()

	_update_icon_list(passive_icons, selected)
	_update_icon_list(pause_passive_icons, selected)


func _update_icon_list(icons: Array, selected_index: int) -> void:
	for i in icons.size():
		var icon = icons[i] as CanvasItem
		if not icon:
			continue
		var power_index := i + 1
		var is_selected := power_index == selected_index
		icon.modulate = Color(1, 1, 1, 1.0) if is_selected else Color(0.35, 0.35, 0.35, 0.7)
		icon.visible = true


func _setup_pause_focus_order() -> void:
	var focus_nodes: Array[Control] = []
	for n in [resume_button, main_menu_button, quit_button, passive_toggle]:
		if n:
			n.focus_mode = Control.FOCUS_ALL
			focus_nodes.append(n)

	var passive_buttons: Array[Control] = []
	for icon in pause_passive_icons:
		if icon and icon is Button:
			icon.focus_mode = Control.FOCUS_ALL
			focus_nodes.append(icon)
			passive_buttons.append(icon)

	for i in focus_nodes.size():
		var current := focus_nodes[i]
		var next := focus_nodes[(i + 1) % focus_nodes.size()]
		var prev := focus_nodes[(i - 1 + focus_nodes.size()) % focus_nodes.size()]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(prev)
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_neighbor_top = current.get_path_to(prev)

	for i in passive_buttons.size():
		var current := passive_buttons[i]
		var next := passive_buttons[(i + 1) % passive_buttons.size()]
		var prev := passive_buttons[(i - 1 + passive_buttons.size()) % passive_buttons.size()]
		current.focus_neighbor_right = current.get_path_to(next)
		current.focus_neighbor_left = current.get_path_to(prev)


func _on_pause_passive_icon_pressed(index: int) -> void:
	if index < 0 or index >= pause_passive_icons.size():
		return

	var power_index := index + 1
	var current := 0
	if player and player.has_method("get_selected_passive_power"):
		current = player.get_selected_passive_power()

	if power_index == current:
		power_index = 0

	if player and player.has_method("set_selected_passive_power"):
		player.set_selected_passive_power(power_index)
	_update_passive_icons()


func apply_pause_menu_aero_style() -> void:
	for button in [resume_button, main_menu_button, quit_button, passive_toggle]:
		if button:
			var normal_style := StyleBoxFlat.new()
			normal_style.bg_color = Color(0.05, 0.35, 0.40, 0.35)
			normal_style.border_color = Color(0.70, 1.0, 1.0, 0.55)
			normal_style.set_border_width_all(1)
			normal_style.set_corner_radius_all(2)
			button.add_theme_stylebox_override("normal", normal_style)

			var hover_style := normal_style.duplicate() as StyleBoxFlat
			hover_style.bg_color = Color(0.70, 1.0, 1.0, 0.28)
			button.add_theme_stylebox_override("hover", hover_style)

			var pressed_style := normal_style.duplicate() as StyleBoxFlat
			pressed_style.bg_color = Color(0.95, 1.0, 1.0, 0.40)
			button.add_theme_stylebox_override("pressed", pressed_style)
			button.add_theme_stylebox_override("focus", hover_style)

			button.add_theme_color_override("font_color", Color(0.94, 1.0, 1.0, 1.0))
			button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
			button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))


func _on_main_menu_pressed() -> void:
	close_pause_menu()
	if GameManager:
		GameManager.goto_title()


func _update_soap_counter() -> void:
	if not soap_label:
		return
	soap_label.text = str(GameManager.get_soap())


func _on_quit_pressed() -> void:
	close_pause_menu()
	get_tree().quit()
