extends CharacterBody2D

@onready var animation_sprite = $AnimatedSprite2D
@export var hit: Node
@export var detection_range: float = 300.0 # Distancia de deteccao do inimigo
@export var chase_speed: float = 160.0 # Velocidade ao perseguir player

const SPEED = 160.0
const JUMP_VELOCITY = -400.0
const gravity = 50

var player: Node2D = null
var is_chasing: bool = false
var move_direction: float = 1.0  # Direção de patrulha (1 = direita, -1 = esquerda)


func _ready():
	# Encontra o player na cena
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta):
	#Sistema de perseguicao
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Verifica se está no alcance de detecção
		if distance_to_player <= detection_range:
			is_chasing = true
			chase_player()
		else:
			is_chasing = false
	
	if is_on_wall() and not is_chasing:
		move_direction *= -1
		update_flip(move_direction)

	
	if is_on_wall() and is_on_floor():
		velocity.y = JUMP_VELOCITY
	else:
		velocity.y += gravity
		
	move_and_slide()

func chase_player():
	var distance = global_position.distance_to(player.global_position)
	
	#Para de perseguir se muito proximo ao player
	if distance < 30:
		velocity.x = 5
		return
	
	# Calcula direção para o player
	var direction = sign(player.global_position.x - global_position.x)
		# Vira em direção ao player
	update_flip(direction)
	
	# Move em direção ao player
	if direction != 0:
		move(direction, chase_speed)
		
func move(dir, speed):
	velocity.x = dir * speed
	if not is_chasing:
	#	move_direction *= -1
	#	update_flip(move_direction)
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
	if area.is_in_group("player"):
		hit.set_deferred("monitoring", false)
		$CPUParticles2D.emitting = true
		animation_sprite.visible = false
		await get_tree().create_timer(0.3).timeout
		self.queue_free()
