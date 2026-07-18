extends Node

# ===== SINAIS =====

signal health_changed(current: int, max: int)
signal player_died
signal player_damaged(damage: int)
signal player_healed(amount: int)

# ===== CONFIGURAÇÕES DE VIDA =====

@export_group("Health Settings")
@export var base_health: int = 3
@export var bonus_health: int = 0

var current_health: int
var max_health: int

# Vida extra por forma
var forma_health_bonus := {
	0: 0,  # Jacaré: vida base (3 HP)
	1: 0,  # Cobra: vida base (3 HP)
	2: 1,  # Onça: +1 vida (4 HP)
	3: 2   # Cavalo: +2 vida (5 HP)
}

# ===== SISTEMA DE INVENCIBILIDADE =====

@export_group("Invincibility Settings")
@export var invincibility_time: float = 1.5
@export var blink_interval: float = 0.1
@export var max_blinks: int = 8

var is_invincible: bool = false
var blink_count: int = 0
var blink_timer: float = 0.0
var invincibility_timer: float = 0.0

# ===== KNOCKBACK =====

@export_group("Knockback Settings")
@export var knockback_strength: float = 200.0
@export var knockback_vertical: float = -100.0

# ===== REFERÊNCIAS (busca automaticamente) =====

@export var player: CharacterBody2D
@export var sprite: AnimatedSprite2D
@export var collision_area: Area2D

# ===== INICIALIZAÇÃO =====

func _ready() -> void:
	# Inicializa vida
	max_health = base_health + bonus_health
	current_health = max_health
	
	# Validação das referências
	validate_references()
	
	# Conecta signals
	connect_signals()
	
	print("💚 Stats inicializado!")
	print("  Vida inicial: %d/%d" % [current_health, max_health])

func validate_references() -> void:
	"""Valida se todas as referências foram encontradas"""
	if not player:
		push_error("❌ Stats: Player (CharacterBody2D) não encontrado")
	else:
		print("✅ Stats: Player encontrado")
	
	if not sprite:
		push_error("❌ Stats: AnimatedSprite2D não encontrado")
	else:
		print("✅ Stats: Sprite encontrado")
	
	if not collision_area:
		push_warning("⚠️ Stats: CollisionArea não encontrada (opcional)")
	else:
		print("✅ Stats: CollisionArea encontrada")

func connect_signals() -> void:
	"""Conecta todos os signals necessários"""
	# Signal da collision area (se existir)
	if collision_area:
		if not collision_area.area_entered.is_connected(_on_collision_area_entered):
			collision_area.area_entered.connect(_on_collision_area_entered)
			print("✅ Stats: Signal collision_area.area_entered conectado")

# ===== PROCESS =====

func _process(delta: float) -> void:
	# Sistema de piscar durante invencibilidade
	if is_invincible:
		handle_invincibility(delta)

func handle_invincibility(delta: float) -> void:
	"""Gerencia invencibilidade e efeito de piscar"""
	invincibility_timer -= delta
	blink_timer -= delta
	
	# Piscar
	if blink_timer <= 0 and blink_count < max_blinks:
		toggle_blink()
		blink_timer = blink_interval
		blink_count += 1
	
	# Termina invencibilidade
	if invincibility_timer <= 0:
		end_invincibility()

# ===== SISTEMA DE VIDA =====

func update_max_health_by_forma(forma: int) -> void:
	"""Atualiza vida máxima baseado na forma atual"""
	var old_max = max_health
	var old_health = current_health
	
	# Calcula nova vida máxima
	max_health = base_health + bonus_health + forma_health_bonus.get(forma, 0)
	
	# Ajusta vida atual proporcionalmente
	if old_max > 0:
		var ratio = float(current_health) / float(old_max)
		current_health = ceili(ratio * max_health)
	
	# Garante que não ultrapasse o máximo
	current_health = mini(current_health, max_health)
	
	# Log
	var forma_names = ["Jacaré", "Cobra", "Onça", "Cavalo"]
	var forma_name = forma_names[forma] if forma < 4 else "Desconhecido"
	
	print("📊 Vida atualizada por forma:")
	print("  Forma: %s" % forma_name)
	print("  Vida: %d/%d → %d/%d" % [old_health, old_max, current_health, max_health])
	
	emit_signal("health_changed", current_health, max_health)

func take_damage(amount: int) -> void:
	"""Aplica dano ao player"""
	# Ignora dano se invencível
	if is_invincible:
		print("🛡️ Dano bloqueado (invencível)")
		return
	
	# Aplica dano
	current_health -= amount
	print("💔 Dano -%d | Vida: %d/%d" % [amount, current_health, max_health])
	
	# Emite signals
	emit_signal("player_damaged", amount)
	emit_signal("health_changed", current_health, max_health)
	
	# Verifica se morreu
	if current_health <= 0:
		current_health = 0
		die()
	else:
		# Inicia invencibilidade
		start_invincibility()

func heal(amount: int) -> void:
	"""Cura o player"""
	var old_health = current_health
	current_health = mini(current_health + amount, max_health)
	
	var healed = current_health - old_health
	
	if healed > 0:
		print("💚 Curado +%d | Vida: %d/%d" % [healed, current_health, max_health])
		emit_signal("player_healed", healed)
		emit_signal("health_changed", current_health, max_health)

func set_health(value: int) -> void:
	"""Define vida diretamente (use com cuidado)"""
	current_health = clampi(value, 0, max_health)
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		die()

func add_max_health(amount: int) -> void:
	"""Aumenta vida máxima permanentemente"""
	bonus_health += amount
	var old_max = max_health
	max_health += amount
	current_health += amount  # Adiciona também à vida atual
	
	print("💖 Vida máxima aumentada: %d → %d" % [old_max, max_health])
	emit_signal("health_changed", current_health, max_health)

# ===== MORTE =====

func die() -> void:
	"""Lida com a morte do player"""
	print("💀 Player morreu!")
	
	# Para invencibilidade
	is_invincible = false
	
	# Restaura aparência normal
	if sprite:
		sprite.visible = true
		sprite.modulate = Color(1, 1, 1, 1)
	
	# Desativa colisão
	if collision_area:
		collision_area.set_deferred("monitoring", false)
	
	# Emite signal
	emit_signal("player_died")
	
	# ✅ CORRIGIDO: Muda estado do player para morto
	if player and "state" in player and "State" in player:
		player.state = player.State.DEAD
	
	# Recarrega a cena após delay
	reload_scene_after_delay()

func reload_scene_after_delay(delay: float = 2.0) -> void:
	"""Recarrega a cena após um delay"""
	await get_tree().create_timer(delay).timeout
	
	if is_inside_tree():
		get_tree().reload_current_scene()

# ===== INVENCIBILIDADE =====

func start_invincibility() -> void:
	"""Inicia invencibilidade temporária"""
	is_invincible = true
	invincibility_timer = invincibility_time
	blink_count = 0
	blink_timer = 0
	
	print("🛡️ Invencibilidade iniciada (%.1fs)" % invincibility_time)
	
	# Desativa colisão
	if collision_area:
		collision_area.set_deferred("monitoring", false)
	
	# Aplica knockback
	apply_knockback()

func end_invincibility() -> void:
	"""Termina invencibilidade"""
	is_invincible = false
	
	# ✅ CORRIGIDO: Reativa colisão apenas se não estiver morto
	if collision_area and player:
		if "state" in player and "State" in player:
			if player.state != player.State.DEAD:
				collision_area.set_deferred("monitoring", true)
		else:
			# Se player não tem State, reativa normalmente
			collision_area.set_deferred("monitoring", true)
	
	# Restaura aparência normal
	if sprite:
		sprite.visible = true
		sprite.modulate = Color(1, 1, 1, 1)
	
	print("🛡️ Invencibilidade terminou")

func force_end_invincibility() -> void:
	"""Força o fim da invencibilidade (use com cuidado)"""
	invincibility_timer = 0
	end_invincibility()

# ===== EFEITO VISUAL =====

func toggle_blink() -> void:
	"""Alterna visibilidade para criar efeito de piscar"""
	if not sprite:
		return
	
	sprite.visible = not sprite.visible
	
	# Cor vermelha quando visível, normal quando invisível
	if sprite.visible:
		sprite.modulate = Color(1, 0.5, 0.5, 0.8)  # Vermelho translúcido
	else:
		sprite.modulate = Color(1, 1, 1, 1)  # Normal

# ===== KNOCKBACK =====

func apply_knockback() -> void:
	"""Aplica knockback ao tomar dano"""
	if not player:
		return
	
	# Determina direção do knockback (oposto à direção que estava indo)
	var knockback_dir = -1 if player.velocity.x >= 0 else 1
	
	# Aplica knockback
	player.velocity.x = knockback_dir * knockback_strength
	player.velocity.y = knockback_vertical
	
	print("💨 Knockback aplicado: direção %d" % knockback_dir)

# ===== DETECÇÃO DE COLISÃO =====

func _on_collision_area_entered(area: Area2D) -> void:
	"""Detecta colisão com inimigos e hazards"""
	
	# Dano de inimigos
	if area.is_in_group("ebody") or area.is_in_group("enemy"):
		take_damage(1)
		print("⚔️ Colidiu com inimigo!")
	
	# Dano de hazards (espinhos, lava, etc)
	elif area.is_in_group("hazard"):
		take_damage(1)
		print("⚠️ Colidiu com hazard!")
	
	# Morte instantânea (abismo, lava mortal, etc)
	elif area.is_in_group("instakill"):
		current_health = 0
		die()
		print("☠️ Morte instantânea!")
	
	# Cura
	elif area.is_in_group("heal"):
		var heal_amount = 1
		if "heal_amount" in area:
			heal_amount = area.heal_amount
		heal(heal_amount)
		print("💚 Colidiu com item de cura!")

# ===== GETTERS =====

func get_health_percentage() -> float:
	"""Retorna porcentagem de vida (0.0 a 1.0)"""
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)

func is_at_full_health() -> bool:
	"""Verifica se está com vida cheia"""
	return current_health >= max_health

func is_low_health(threshold: float = 0.3) -> bool:
	"""Verifica se está com pouca vida"""
	return get_health_percentage() <= threshold

func is_alive() -> bool:
	"""Verifica se está vivo"""
	return current_health > 0

# ===== DEBUG =====

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	
	# Page Down = Tomar dano
	if event.is_action_pressed("ui_page_down"):
		take_damage(1)
		print("🔧 [DEBUG] Dano forçado")
	
	# Page Up = Curar
	elif event.is_action_pressed("ui_page_up"):
		heal(1)
		print("🔧 [DEBUG] Cura forçada")
	
	# End = Aumentar vida máxima
	elif event.is_action_pressed("ui_end"):
		add_max_health(1)
		print("🔧 [DEBUG] Vida máxima aumentada")
	
	# Delete = Morte instantânea
	elif event.is_action_pressed("ui_text_delete"):
		current_health = 0
		die()
		print("🔧 [DEBUG] Morte forçada")
	
	# Insert = Vida cheia
	elif event.is_action_pressed("ui_text_submit"):
		current_health = max_health
		emit_signal("health_changed", current_health, max_health)
		print("🔧 [DEBUG] Vida restaurada")

func print_stats_info() -> void:
	"""Imprime informações do Stats"""
	#print("=" * 50)
	print("💚 STATS INFO")
	print("  Vida: %d/%d (%.0f%%)" % [current_health, max_health, get_health_percentage() * 100])
	print("  Invencível: %s" % is_invincible)
	if is_invincible:
		print("  Tempo restante: %.1fs" % invincibility_timer)
	print("  Referências:")
	print("    Player: %s" % ("✅" if player else "❌"))
	print("    Sprite: %s" % ("✅" if sprite else "❌"))
	print("    CollisionArea: %s" % ("✅" if collision_area else "❌"))
	
	# ✅ CORRIGIDO: Verifica estado do player
	if player and "state" in player:
		if "State" in player:
			print("    Estado do Player: %s" % player.State.keys()[player.state])
		else:
			print("    Estado do Player: N/A")
	
	#print("=" * 50)

# ===== HELPERS PÚBLICOS =====

func reset_health() -> void:
	"""Reseta vida para o máximo (útil para checkpoints)"""
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	print("🔄 Vida resetada para %d/%d" % [current_health, max_health])

func can_take_damage() -> bool:
	"""Verifica se pode tomar dano"""
	return not is_invincible and is_alive()

func get_missing_health() -> int:
	"""Retorna quanto de vida está faltando"""
	return max_health - current_health
