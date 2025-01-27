extends Control



func _input(event: InputEvent) -> void:
	if event.is_pressed():
		get_tree().quit()
