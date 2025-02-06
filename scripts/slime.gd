extends CharacterBody2D

@onready var animation_sprite = $AnimatedSprite2D
#@export var animate = AnimationPlayer
@export var hit: Node
const SPEED = 160.0
const JUMP_VELOCITY = -400.0
const gravity = 50

func _physics_process(delta):
	if is_on_wall() and is_on_floor():
		velocity.y = JUMP_VELOCITY
	else:
		velocity.y += gravity
	move_and_slide()

func move(dir, speed):
	velocity.x = dir * speed
	#handle_animation()
	update_flip(dir)

func update_flip(dir):
	if abs(dir) == dir:
		animation_sprite.flip_h = true
	else:
		animation_sprite.flip_h = false
		
func handle_animation():
	if !is_on_floor():
		animation_sprite.play("fall")
		
	if velocity.x != 0:
		animation_sprite.play("walk")
	else:
		animation_sprite.play("idle")

func check_for_self(node):
	if node == self:
		return true
	else:
		return false

func play_attack(body):
#	if body.group == "player":
#		$CPUParticles2D.emitting = true
#		await animation_sprite.animation_finished
#		animation_sprite.visible = false
#		await get_tree().create_timer(0.3).timeout
#		self.queue_free()
	pass

#func _on_area_2d_body_entered(area: Area2D) -> void:
	#if body.name == "player":
#	if area.is_in_group("player"):
#		hit.set_deferred("monitoring", false)
#		$CPUParticles2D.emitting = true
#		animation_sprite.visible = false
#		await get_tree().create_timer(0.3).timeout
#		self.queue_free()


func _on_hit_area_entered(area: Area2D) -> void:
	pass
	#if area.is_in_group("player"):
	#	$CPUParticles2D.emitting = true
	#	animation_sprite.visible = false
	#	await get_tree().create_timer(0.3).timeout
	#	self.queue_free()


func _on_area_2d_area_entered(area: Area2D) -> void:
	#if body.name == "player":
	if area.is_in_group("player"):
		hit.set_deferred("monitoring", false)
		$CPUParticles2D.emitting = true
		animation_sprite.visible = false
		await get_tree().create_timer(0.3).timeout
		self.queue_free()
