extends Node

# Sinais para comunicação com outros sistemas
signal health_changed(current: int, max: int)
signal player_died
signal player_damaged(damage: int)

# Variáveis de vida
@export var base_health: int = 3
@export var bonus_health: int = 0
var current_health: int
var max_health: int

# Sistema de piscar ao levar dano
var blink_count := 0
const MAX_BLINKS := 6

# Referências exportadas
@export var piscar_timer: Timer
@export var player: CharacterBody2D
@export var collision_area: Area2D
@export var invencibilidade_timer: Timer
@export var textura: Sprite2D

# Vida extra por forma
@export var bubble_health_bonus := 0  # Bolha mantém vida base
@export var super_health_bonus := 2   # Super ganha +2 de vida máxima

# Estado de invencibilidade
var is_invincible: bool = false

func _ready() -> void:
	# Inicializa vida
	max_health = base_health + bonus_health
	current_health = max_health
	print("💚 Vida inicial: %d/%d" % [current_health, max_health])
	
	# Conecta sinais dos timers
	if piscar_timer and not piscar_timer.timeout.is_connected(_on_piscar_timer_timeout):
		piscar_timer.timeout.connect(_on_piscar_timer_timeout)
	
	if invencibilidade_timer and not invencibilidade_timer.timeout.is_connected(_on_invencibilidade_timeout):
		invencibilidade_timer.timeout.connect(_on_invencibilidade_timeout)
	
	# ✅ NOVO: Conecta a área Stomper
	if player and player.has_node("Stomper"):
		var stomper = player.get_node("Stomper")
		if not stomper.area_entered.is_connected(_on_stomper_area_entered):
			stomper.area_entered.connect(_on_stomper_area_entered)
			print("✅ Stomper conectado!")
	else:
		push_warning("⚠️ Stomper não encontrado no player!")

func update_max_health_by_form() -> void:
	"""Atualiza vida máxima baseado na forma atual"""
	if not player:
		return
	
	var old_max := max_health
	var old_health := current_health
	
	# Calcula nova vida máxima
	match player.form:
		player.Form.NORMAL:
			max_health = base_health + bonus_health
		player.Form.BUBBLE:
			max_health = base_health + bonus_health + bubble_health_bonus
		player.Form.SUPER:
			max_health = base_health + bonus_health + super_health_bonus
	
	# Ajusta vida atual proporcionalmente
	if old_max != max_health and old_max > 0:
		var health_ratio := float(current_health) / float(old_max)
		current_health = ceili(health_ratio * max_health)  # Arredonda para cima
	
	# Garante que não ultrapasse o máximo
	current_health = mini(current_health, max_health)
	
	print("📊 Vida atualizada: %d/%d → %d/%d" % [old_health, old_max, current_health, max_health])
	emit_signal("health_changed", current_health, max_health)

func update_health(type: String, value: int) -> void:
	"""Atualiza a vida do player"""
	match type:
		"Increase", "increase":
			heal(value)
		"Decrease", "decrease":
			take_damage(value)

func heal(amount: int) -> void:
	"""Cura o player"""
	var old_health := current_health
	current_health = mini(current_health + amount, max_health)
	
	var healed := current_health - old_health
	if healed > 0:
		print("💚 Curado +%d | Vida: %d/%d" % [healed, current_health, max_health])
	
	emit_signal("health_changed", current_health, max_health)

func take_damage(amount: int) -> void:
	"""Aplica dano ao player"""
	# Ignora dano se invencível
	if is_invincible:
		print("🛡️ Dano bloqueado (invencível)")
		return
	
	current_health -= amount
	print("💔 Dano -%d | Vida: %d/%d" % [amount, current_health, max_health])
	
	emit_signal("player_damaged", amount)
	emit_signal("health_changed", current_health, max_health)
	
	# Verifica se morreu
	if current_health <= 0:
		current_health = 0
		die()
	else:
		# Inicia invencibilidade e efeito visual
		start_invincibility()
		start_blink_effect()

func die() -> void:
	"""Lida com a morte do player"""
	print("💀 Player morreu!")
	
	# Para todos os efeitos visuais
	if piscar_timer:
		piscar_timer.stop()
	if invencibilidade_timer:
		invencibilidade_timer.stop()
	
	# Reseta aparência
	if textura:
		textura.visible = true
		textura.modulate = Color(1, 1, 1, 1)
	
	# Desativa colisão
	if collision_area:
		collision_area.set_deferred("monitoring", false)
	
	emit_signal("player_died")
	
	# APENAS seta o estado - não chama die() recursivamente
	if player:
		player.state = player.State.DEAD
		# O player.gd cuida do resto (animação + reload)

func start_invincibility() -> void:
	"""Ativa invencibilidade temporária"""
	is_invincible = true
	
	# Desativa colisão
	if collision_area:
		collision_area.set_deferred("monitoring", false)
	
	# Inicia timer
	if invencibilidade_timer:
		invencibilidade_timer.start()
	
	# Knockback melhorado
	if player:
		# Usa direção atual ou direção padrão
		var knockback_dir := -1 if player.velocity.x >= 0 else 1
		player.velocity.x = knockback_dir * 200
		player.velocity.y = -100  # Pula um pouco

func start_blink_effect() -> void:
	"""Inicia efeito visual de piscar"""
	blink_count = 0
	if piscar_timer:
		piscar_timer.start()

# ===== DETECÇÃO DE DANO =====

func _on_colisao_area_entered(area: Area2D) -> void:
	"""Detecta colisão com inimigos (tomar dano de lado/frente)"""
	if area.is_in_group("ebody"):
		# Agora só toma dano - Stomper cuida de matar quando pisa
		take_damage(1)
	
	# Matadores instantâneos (espinhos, lava, etc)
	elif area.is_in_group("instakill"):
		current_health = 0
		die()

# ===== STOMPER (PISAR EM INIMIGOS) =====

func _on_stomper_area_entered(area: Area2D) -> void:
	"""Player pisou em um inimigo (área Stomper nos pés)"""
	if area.is_in_group("slime") or area.is_in_group("enemy"):
		kill_enemy_stomp(area)

func kill_enemy_stomp(enemy_area: Area2D) -> void:
	"""Mata inimigo quando player pisa nele"""
	var enemy = enemy_area.get_parent()
	
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage()
		print("💥 Stomp! Inimigo morto!")
		
		# Bounce após matar (igual Mario!)
		if player:
			player.velocity.y = -250  # Pula após pisar
	
	# Desativa collision_area temporariamente para evitar dano ao pisar
	if collision_area:
		collision_area.set_deferred("monitoring", false)
		
		# Aguarda tempo suficiente para inimigo morrer
		await get_tree().create_timer(0.4).timeout
		
		# Reativa apenas se não estiver em invencibilidade
		if collision_area and not is_invincible:
			collision_area.set_deferred("monitoring", true)

# ===== ATAQUE NORMAL (TECLA) =====

#func _on_matador_area_entered(area: Area2D) -> void:
#	"""Player mata inimigo com ATAQUE de tecla (não confundir com stomp)"""
#	if area.is_in_group("slime") or area.is_in_group("enemy"):
		# Desativa colisão temporariamente ao matar com ataque
#		if collision_area and not is_invincible:
#			collision_area.set_deferred("monitoring", false)
#			
#			await get_tree().create_timer(0.3).timeout
#			
#			# Reativa apenas se ainda não estiver em invencibilidade
#			if collision_area and not is_invincible:
#				collision_area.set_deferred("monitoring", true)

# ===== TIMERS =====

func _on_invencibilidade_timeout() -> void:
	"""Fim da invencibilidade"""
	is_invincible = false
	
	# Reativa colisão apenas se não estiver morto
	if collision_area and player and player.state != player.State.DEAD:
		collision_area.set_deferred("monitoring", true)
	
	print("🛡️ Invencibilidade terminou")

func _on_piscar_timer_timeout() -> void:
	"""Efeito visual de piscar ao tomar dano"""
	if blink_count < MAX_BLINKS:
		blink_count += 1
		
		if textura:
			textura.visible = not textura.visible
			
			# Alterna cor
			if textura.visible:
				textura.modulate = Color(1, 0.5, 0.5, 0.8)  # Vermelho
			else:
				textura.modulate = Color(1, 1, 1, 1)  # Normal
	else:
		# Finaliza efeito
		if piscar_timer:
			piscar_timer.stop()
		if textura:
			textura.visible = true
			textura.modulate = Color(1, 1, 1, 1)
