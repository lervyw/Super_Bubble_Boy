extends Node

@export var background_path: NodePath = NodePath("../Background")
@export var background_dark_color: Color = Color(0.12, 0.10, 0.14, 1.0)
@export var background_purple_color: Color = Color(0.18, 0.08, 0.30, 1.0)
@export var background_color_cycle_time: float = 2.6

var background: CanvasItem
var background_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	background = get_node_or_null(background_path) as CanvasItem
	if not background:
		return

	background.modulate = background_dark_color
	background_tween = create_tween()
	background_tween.set_loops()
	background_tween.tween_property(background, "modulate", background_purple_color, background_color_cycle_time)
	background_tween.tween_property(background, "modulate", background_dark_color, background_color_cycle_time)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
