extends CanvasLayer

@export var player: CharacterBody2D
@export var stats: Node
@export var heart_icons: Array[TextureRect] = []
@export var hp_bar: TextureProgressBar
@export var mana_bar: TextureProgressBar
@export var menu_panel: Panel


func _ready() -> void:
	if menu_panel:
		menu_panel.visible = false


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
