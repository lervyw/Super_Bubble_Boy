extends Control



func _input(event: InputEvent) -> void:
	if event.is_pressed():
		await get_tree().create_timer(5).timeout
		get_tree().quit()
