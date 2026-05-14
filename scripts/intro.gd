extends Control


func _ready() -> void:
	_apply_responsive_layout()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)

 
func _input(event: InputEvent) -> void:
	if event.is_pressed():
		get_tree().change_scene_to_file("res://Cenas/level1.tscn")


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	_fill_screen(self)

	var background := get_node_or_null("TextureRect") as TextureRect
	if background:
		_fill_screen(background)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var text_1 := get_node_or_null("texto1") as Label
	if text_1:
		text_1.anchor_left = 0.5
		text_1.anchor_top = 0.0
		text_1.anchor_right = 0.5
		text_1.anchor_bottom = 0.0
		text_1.offset_left = -minf(300.0, viewport_size.x * 0.44)
		text_1.offset_top = 14.0
		text_1.offset_right = minf(300.0, viewport_size.x * 0.44)
		text_1.offset_bottom = 142.0
		text_1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var text_2 := get_node_or_null("texto2") as Label
	if text_2:
		text_2.anchor_left = 0.5
		text_2.anchor_top = 1.0
		text_2.anchor_right = 0.5
		text_2.anchor_bottom = 1.0
		text_2.offset_left = -96.0
		text_2.offset_top = -108.0
		text_2.offset_right = 96.0
		text_2.offset_bottom = -24.0


func _fill_screen(node: Control) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
		
