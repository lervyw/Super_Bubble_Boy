extends CanvasLayer

@export var player: CharacterBody2D
@export var stats: Node  # seu node Stats atual
@export var lives_label: Label
@export var hp_label: Label
@export var hp_bar: TextureProgressBar
@export var life_icons: Array[TextureRect] = []

func update_lives():
	var lives = GameManager.get_lives()

	for i in range(life_icons.size()):
		life_icons[i].visible = i < lives


func _ready() -> void:
	update_display()

func _process(delta: float) -> void:
	update_display()
	update_lives()

func update_display() -> void:
	if not player:
		return

	# Mostrar vidas SEMPRE
	lives_label.text = "❤ x %d" % GameManager.get_lives()

	# Modo Plataforma → esconder HP
	if player.mode == player.GameMode.PLATAFORMA:
		hp_bar.visible = false
		hp_label.visible = false
		return

	# Modo Metroidvania → mostrar HP
	if stats:
		hp_bar.visible = true
		hp_label.visible = true

		hp_bar.max_value = stats.max_health
		hp_bar.value = stats.current_health
		hp_label.text = "%d/%d" % [stats.current_health, stats.max_health]
