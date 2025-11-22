extends Node

# =======================
# ====== CONSTANTES =====
# =======================
const LEVEL1_PATH      = "res://Cenas/level1.tscn"
const TITLE_PATH       = "res://Cenas/Title.tscn"
const CONTINUE_PATH    = "res://Cenas/cutscene_continue.tscn"
const CUTSCENE_PATH    = "res://Cenas/cutscene_test.tscn"

# =======================
# ====== VARIÁVEIS ======
# =======================
var current_level_path: String = ""
var player_lives: int = 3
var player_score: int = 0

# Se quiser resetar HP global ao continuar
var GlobalStats: Node = null


# =======================
# ====== READY ==========
# =======================
func _ready() -> void:
	print("✅ GameManager carregado!")
	print("   Níveis disponíveis:")
	print("   - Level 1:", LEVEL1_PATH)
	print("   - Title:", TITLE_PATH)
	print("   - Continue:", CONTINUE_PATH)

	# Procura stats globais (opcional)
	GlobalStats = get_node_or_null("/root/GlobalStats")

# =======================
# ====== NAVEGAÇÃO ======
# =======================

func goto_continue() -> void:
	print("🎬 Mudando para Continue...")

	# Evita erro de remover CollisionObject durante physics callback
	get_tree().call_deferred("change_scene_to_file", CONTINUE_PATH)


func goto_level(level_path: String) -> void:
	if not ResourceLoader.exists(level_path):
		push_error("❌ Nível não encontrado: " + level_path)
		return

	current_level_path = level_path
	print("🎬 Carregando nível: " + level_path)
	get_tree().change_scene_to_file(level_path)


func goto_title() -> void:
	print("🎬 Voltando ao menu principal...")

	# reset usado apenas ao sair para o menu
	current_level_path = ""
	get_tree().change_scene_to_file(TITLE_PATH)


func restart_current_level() -> void:
	if current_level_path.is_empty():
		push_warning("⚠️ Nenhum nível definido! Indo para o menu...")
		goto_title()
		return

	print("🔄 Reiniciando nível:", current_level_path)
	goto_level(current_level_path)

func goto_level1() -> void:
	goto_level(LEVEL1_PATH)

func goto_cutscene() -> void:
	goto_level(CUTSCENE_PATH)

# =======================
# ===== GAME STATE ======
# =======================

# Reset total — apenas ao voltar para o menu
func reset_game() -> void:
	player_lives = 3
	player_score = 0
	current_level_path = ""
	print("🔄 Estado do jogo completamente resetado")


# Usado para CONTINUE (não reseta level salvo)
func restore_full_lives() -> void:
	player_lives = 3
	print("💚 Vidas restauradas ao máximo:", player_lives)


func restore_full_health() -> void:
	if GlobalStats and GlobalStats.has_method("reset_health_full"):
		GlobalStats.reset_health_full()
		print("💙 HP restaurado ao máximo")


func lose_life() -> void:
	player_lives -= 1
	print("💔 Vidas restantes:", player_lives)

	if player_lives <= 0:
		print("💀 Sem vidas → indo para tela de Continue...")
		goto_continue()


func add_score(points: int) -> void:
	player_score += points
	print("⭐ Score:", player_score, "( +", points, ")")


func get_lives() -> int:
	return player_lives

func get_score() -> int:
	return player_score

func get_current_level() -> String:
	return current_level_path
