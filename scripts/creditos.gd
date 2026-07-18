extends Control

@export var fade_duration: float = 1.5
@export var display_duration: float = 5.0
@export var return_to_title: bool = true

@onready var texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	if texture_rect:
		texture_rect.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(texture_rect, "modulate:a", 1.0, fade_duration)
		tween.tween_interval(display_duration)
		tween.tween_property(texture_rect, "modulate:a", 0.0, fade_duration)
		tween.tween_callback(_on_credits_finished)


func _on_credits_finished() -> void:
	if return_to_title:
		get_tree().change_scene_to_file("res://Cenas/Title.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("attack"):
		get_tree().change_scene_to_file("res://Cenas/Title.tscn")
