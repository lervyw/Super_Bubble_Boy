# DialogBox.gd
extends RichTextLabel

const CHARACTER_SPEED: float = 0.035

var is_displaying: bool = false
var can_advance: bool = false

func set_dialog(string: String):
	visible_characters = 0
	text = string
	is_displaying = true
	can_advance = false
	
	for i in range(string.length()):
		visible_characters += 1
		await get_tree().create_timer(CHARACTER_SPEED).timeout
	
	is_displaying = false
	can_advance = true

func is_ready_to_advance() -> bool:
	return can_advance

func skip_dialog():
	if is_displaying:
		visible_characters = text.length()
		is_displaying = false
		can_advance = true
