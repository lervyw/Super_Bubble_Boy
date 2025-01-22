# Script do Sprite2D para animações
extends Sprite2D
@export var player: Node
@export var animation: AnimationPlayer

func animate(direction: Vector2) -> void:
	verify_position(direction)
	if direction.y != 0:
		vertical_behavior(direction)
	else:
		horizontal_behavior(direction)

func verify_position(direction: Vector2) -> void:
	if direction.x > 0:
		flip_h = false
	elif direction.x < 0:
		flip_h = true

func horizontal_behavior(direction: Vector2) -> void:
	if direction.x != 0:
		animation.play("Walk")
	else:
		animation.play("Idle")

func vertical_behavior(direction: Vector2) -> void:
	if direction.y > 0:
		animation.play("Fall")
	elif direction.y < 0:
		animation.play("Jump")

func mudarforma():
	
	animation.play("Transform")
	
	#await animation.animation_finished 
	print(player.form)
	
func _on_animacao_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Transform":
			player.transformando == false # Replace with function body.
