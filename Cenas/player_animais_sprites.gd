extends Sprite2D

signal attack_finished
signal transform_finished

@export var player: PlayerAnimais
@export var animation_player: AnimationPlayer

func _ready() -> void:
	if not player:
		push_error("Player reference não configurada!")
	if not animation_player:
		push_error("AnimationPlayer não configurado!")

func _process(_delta: float) -> void:
	if not player:
		return
	
	update_animation()

func update_animation() -> void:
	"""Atualiza animação baseada no estado e forma"""
	var anim_name := get_animation_name()
	play_if_different(anim_name)

func get_animation_name() -> String:
	"""Retorna o nome da animação baseado em estado e forma"""
	var forma_prefix := get_forma_prefix()
	
	match player.state:
		player.State.IDLE:
			return forma_prefix + "idle"
		
		player.State.WALK:
			return forma_prefix + "walk"
		
		player.State.JUMP:
			return forma_prefix + "jump"
		
		player.State.FALL:
			return forma_prefix + "fall"
		
		player.State.ATTACK:
			return forma_prefix + "attack"
		
		player.State.SWIM:
			return forma_prefix + "swim"
		
		player.State.TRANSFORM:
			return get_transform_animation()
		
		player.State.DEAD:
			return forma_prefix + "dead"
		
		_:
			return forma_prefix + "idle"

func get_forma_prefix() -> String:
	"""Retorna prefixo da animação baseado na forma"""
	match player.forma:
		player.Forma.JACARE:
			return "jacare_"
		player.Forma.COBRA:
			return "cobra_"
		player.Forma.ONCA:
			return "onca_"
		player.Forma.CAVALO:
			return "cavalo_"
		_:
			return "jacare_"

func get_transform_animation() -> String:
	"""Retorna animação de transformação"""
	var from_forma = player.forma
	var to_forma = player.target_forma
	
	var from_name = player.Forma.keys()[from_forma].to_lower()
	var to_name = player.Forma.keys()[to_forma].to_lower()
	
	return "transform_%s_to_%s" % [from_name, to_name]

func play_if_different(anim_name: String) -> void:
	"""Toca animação apenas se for diferente da atual"""
	if not animation_player:
		return
	
	# Verifica se a animação existe
	if not animation_player.has_animation(anim_name):
		push_warning("Animação '%s' não existe! Usando fallback." % anim_name)
		anim_name = "jacare_idle"  # Fallback
	
	# Toca apenas se for diferente
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

func _on_animation_finished(anim_name: StringName) -> void:
	"""Callback quando animação termina"""
	# Animações de ataque
	if "attack" in anim_name:
		emit_signal("attack_finished")
		player.change_state(player.State.IDLE)
	
	# Animações de transformação
	elif "transform" in anim_name:
		emit_signal("transform_finished")
		player.complete_transform()
	
	# Animações de morte
	elif "dead" in anim_name:
		# Stats cuida do reload
		pass
