# game_manager.gd
extends Node

# =======================
# ====== CONSTANTES =====
# =======================
const LEVEL1_PATH = "res://Cenas/level1.tscn"
const TITLE_PATH = "res://Cenas/Title.tscn"
const CONTINUE_PATH = "res://Cenas/cutscene_continue.tscn"
const CUTSCENE_PATH = "res://Cenas/cutscene_test.tscn"

# Adicione mais níveis conforme necessário
#const LEVEL2_PATH = "res://scenes/level2.tscn"
#const LEVEL3_PATH = "res://scenes/level3.tscn"

# =======================
# ====== VARIÁVEIS ======
# =======================
var current_level_path: String = ""
var player_lives: int = 3
var player_score: int = 0

# =======================
# ====== NAVEGAÇÃO ======
# =======================

## Vai para a tela de Continue
func goto_continue() -> void:
	print("🎬 Mudando para Continue...")
	get_tree().change_scene_to_file(CONTINUE_PATH)

## Carrega um nível específico e salva como "nível atual"
func goto_level(level_path: String) -> void:
	if not ResourceLoader.exists(level_path):
		push_error("❌ Nível não encontrado: " + level_path)
		return
	
	current_level_path = level_path
	print("🎬 Carregando nível: " + level_path)
	get_tree().change_scene_to_file(level_path)

## Vai para o menu principal
func goto_title() -> void:
	current_level_path = ""
	print("🎬 Voltando ao menu principal...")
	get_tree().change_scene_to_file(TITLE_PATH)

## Reinicia o nível atual (usado pelo Continue)
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

#func goto_level3() -> void:
#	goto_level(LEVEL3_PATH)

# =======================
# ===== GAME STATE ======
# =======================

func reset_game() -> void:
	"""Reseta todo o estado do jogo"""
	player_lives = 3
	player_score = 0
	current_level_path = ""
	print("🔄 Estado do jogo resetado")

func add_score(points: int) -> void:
	player_score += points
	print("⭐ Score: %d (+%d)" % [player_score, points])

func lose_life() -> void:
	player_lives -= 1
	print("💔 Vidas restantes: %d" % player_lives)
	
	if player_lives <= 0:
		print("💀 Game Over!")
		# Você pode adicionar uma tela de Game Over aqui
		goto_title()

func get_lives() -> int:
	return player_lives

func get_score() -> int:
	return player_score

func get_current_level() -> String:
	return current_level_path

# =======================
# ===== DEBUG ===========
# =======================

func _ready() -> void:
	print("✅ GameManager carregado!")
	print("   Níveis disponíveis:")
	print("   - Level 1: " + LEVEL1_PATH)
	print("   - Title: " + TITLE_PATH)
	print("   - Continue: " + CONTINUE_PATH)
