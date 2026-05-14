# game_manager.gd
extends Node

# =======================
# ====== CONSTANTES =====
# =======================
const LEVEL1_PATH   = "res://Cenas/level1.tscn"
const TITLE_PATH    = "res://Cenas/Title.tscn"
const CONTINUE_PATH = "res://Cenas/cutscene_continue.tscn"
const CUTSCENE_PATH = "res://Cenas/cutscene_test.tscn"

# =======================
# ====== VARIÁVEIS ======
# =======================
var current_level_path: String = ""
var player_lives: int = 3
var player_score: int = 0

# =======================
# ====== NAVEGAÇÃO ======
# =======================

func goto_continue() -> void:
	print("🎬 Mudando para Continue...")
	_change_scene(CONTINUE_PATH, true)

func goto_level(level_path: String) -> void:
	if not ResourceLoader.exists(level_path):
		push_error("❌ Nível não encontrado: " + level_path)
		return
	
	current_level_path = level_path
	print("🎬 Carregando nível: " + level_path)
	_change_scene(level_path)

func goto_title() -> void:
	current_level_path = ""
	print("🎬 Voltando ao menu principal...")
	_change_scene(TITLE_PATH)

func restart_current_level() -> void:
	if current_level_path.is_empty():
		push_warning("⚠️ Nenhum nível atual definido! Voltando ao menu...")
		goto_title()
	else:
		print("🔄 Reiniciando nível atual: " + current_level_path)
		goto_level(current_level_path)

# =======================
# ===== ATALHOS NÍVEIS ==
# =======================

func goto_level1() -> void:
	goto_level(LEVEL1_PATH)

func goto_cutscene() -> void:
	goto_level(CUTSCENE_PATH)


func _change_scene(scene_path: String, deferred: bool = false) -> void:
	var host := get_tree().get_first_node_in_group("game_scene_host")
	if host and host.has_method("change_game_scene"):
		if deferred:
			host.call_deferred("change_game_scene", scene_path)
		else:
			host.change_game_scene(scene_path)
		return

	if deferred:
		get_tree().call_deferred("change_scene_to_file", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

# =======================
# ===== GAME STATE ======
# =======================

func reset_game() -> void:
	player_lives = 3
	player_score = 0
	print("🔄 Estado do jogo resetado")

func add_score(points: int) -> void:
	player_score += points
	print("⭐ Score: %d (+%d)" % [player_score, points])

func lose_life() -> void:
	player_lives -= 1
	print("💔 Vidas restantes: %d" % player_lives)
	
	if player_lives <= 0:
		print("💀 Sem vidas! Indo para tela de Continue...")
		goto_continue()


func consume_life() -> int:
	player_lives = max(player_lives - 1, 0)
	print("💔 Vidas restantes: %d" % player_lives)
	return player_lives

func restore_full_lives() -> void:
	player_lives = 3
	print("💚 Vidas restauradas para: %d" % player_lives)

func get_lives() -> int:
	return player_lives

func get_score() -> int:
	return player_score

func get_current_level() -> String:
	return current_level_path

# =======================
# ===== HP GLOBAL (opcional)
# =======================

func restore_full_health() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and "stats" in player and player.stats and player.stats.has_method("restore_full_health"):
		player.stats.restore_full_health()
		print("💚 HP completamente restaurado!")

func restore_full_mana() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and "stats" in player and player.stats and player.stats.has_method("restore_full_mana"):
		player.stats.restore_full_mana()
		print("🔷 Mana completamente restaurada!")

# =======================
# ===== DEBUG ===========
# =======================

func _ready() -> void:
	print("✅ GameManager carregado!")
	print("   Níveis disponíveis:")
	print("   - Level 1: " + LEVEL1_PATH)
	print("   - Title: " + TITLE_PATH)
	print("   - Continue: " + CONTINUE_PATH)
