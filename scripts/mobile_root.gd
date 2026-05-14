extends Control

const BASE_GAME_SIZE := Vector2i(420, 280)
const RENDER_SCALE := 2
const RENDER_GAME_SIZE := BASE_GAME_SIZE * RENDER_SCALE
const INITIAL_SCENE_PATH := "res://Cenas/Title.tscn"
const MOBILE_CONTROLS_SCRIPT := preload("res://scripts/mobile_controls.gd")
const GAMEPLAY_SCENE_PATHS := ["res://Cenas/level1.tscn", "res://Cenas/level2.tscn"]

@onready var game_container: SubViewportContainer = $GameContainer
@onready var game_viewport: SubViewport = $GameContainer/GameViewport
@onready var border_background: ColorRect = $BorderBackground

var current_game_scene: Node
var mobile_controls: CanvasLayer


func _ready() -> void:
	add_to_group("game_scene_host")
	_setup_viewport()
	_setup_mobile_controls()
	_update_layout()
	if not get_viewport().size_changed.is_connected(_update_layout):
		get_viewport().size_changed.connect(_update_layout)
	call_deferred("change_game_scene", INITIAL_SCENE_PATH)


func change_game_scene(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("MobileRoot: cena não encontrada: %s" % scene_path)
		return

	if current_game_scene:
		current_game_scene.queue_free()
		current_game_scene = null

	var packed_scene := load(scene_path) as PackedScene
	if not packed_scene:
		push_error("MobileRoot: falha ao carregar cena: %s" % scene_path)
		return

	current_game_scene = packed_scene.instantiate()
	game_viewport.add_child(current_game_scene)
	get_tree().current_scene = self
	_set_mobile_controls_visible(scene_path in GAMEPLAY_SCENE_PATHS)


func _setup_viewport() -> void:
	game_viewport.size = RENDER_GAME_SIZE
	game_viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE * float(RENDER_SCALE))
	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_viewport.handle_input_locally = true
	game_container.stretch = true


func _setup_mobile_controls() -> void:
	if not _should_create_mobile_controls():
		return

	mobile_controls = MOBILE_CONTROLS_SCRIPT.new() as CanvasLayer
	mobile_controls.name = "MobileControls"
	mobile_controls.visible = false
	add_child(mobile_controls)


func _should_create_mobile_controls() -> bool:
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS" or DisplayServer.is_touchscreen_available()


func _set_mobile_controls_visible(controls_visible: bool) -> void:
	if mobile_controls:
		mobile_controls.visible = controls_visible


func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var base_aspect := float(BASE_GAME_SIZE.x) / float(BASE_GAME_SIZE.y)
	var available_aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var target_size := viewport_size

	if available_aspect > base_aspect:
		target_size.x = viewport_size.y * base_aspect
	else:
		target_size.y = viewport_size.x / base_aspect

	if border_background:
		border_background.anchor_left = 0.0
		border_background.anchor_top = 0.0
		border_background.anchor_right = 1.0
		border_background.anchor_bottom = 1.0
		border_background.offset_left = 0.0
		border_background.offset_top = 0.0
		border_background.offset_right = 0.0
		border_background.offset_bottom = 0.0

	game_container.anchor_left = 0.5
	game_container.anchor_top = 0.5
	game_container.anchor_right = 0.5
	game_container.anchor_bottom = 0.5
	game_container.offset_left = -target_size.x * 0.5
	game_container.offset_top = -target_size.y * 0.5
	game_container.offset_right = target_size.x * 0.5
	game_container.offset_bottom = target_size.y * 0.5
