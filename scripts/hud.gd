extends CanvasLayer

@export var player: CharacterBody2D
@export var stats: Node
@export var heart_icons: Array[TextureRect] = []
@export var hp_bar: TextureProgressBar
@export var mana_bar: TextureProgressBar
@export var boss_hp_bar: TextureProgressBar
@export var menu_panel: Panel
@export var pause_menu_panel: Control
@export var passive_toggle: CheckButton

var boss_target: Node = null
var pause_menu_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if menu_panel:
		menu_panel.visible = false
	if pause_menu_panel:
		pause_menu_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_menu_panel.visible = false
	if passive_toggle:
		passive_toggle.process_mode = Node.PROCESS_MODE_ALWAYS
		if not passive_toggle.toggled.is_connected(_on_passive_toggle_toggled):
			passive_toggle.toggled.connect(_on_passive_toggle_toggled)
	if boss_hp_bar:
		boss_hp_bar.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		toggle_pause_menu()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not player:
		return

	if player.mode == player.GameMode.PLATAFORMA:
		_update_hearts()
		_set_hp_visible(false)
	else:
		_update_hp_bar()
		_set_hearts_visible(false)
		_set_hp_visible(true)

	_update_mana_bar()
	_set_mana_visible(_is_mana_visible())
	_update_menu_panel_state()
	_update_pause_menu_state()


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


func _update_pause_menu_state() -> void:
	if not pause_menu_open:
		return
	if passive_toggle and player and "passive_attack_enabled" in player:
		if passive_toggle.button_pressed != player.passive_attack_enabled:
			passive_toggle.set_pressed_no_signal(player.passive_attack_enabled)


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

		if menu_panel.has_method("set_action_selection"):
			menu_panel.set_action_selection("none")


func hide_menu() -> void:
	if menu_panel:
		menu_panel.visible = false

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

	if passive_toggle and player and "passive_attack_enabled" in player:
		passive_toggle.set_pressed_no_signal(player.passive_attack_enabled)


func close_pause_menu() -> void:
	pause_menu_open = false

	if pause_menu_panel:
		pause_menu_panel.visible = false

	get_tree().paused = false


func _on_passive_toggle_toggled(enabled: bool) -> void:
	if player and player.has_method("set_passive_attack_enabled"):
		player.set_passive_attack_enabled(enabled)
