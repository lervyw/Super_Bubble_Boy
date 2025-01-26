extends Node

@export var label: Label
const MAX_HEALTH = 3
var health := MAX_HEALTH


func _ready() -> void:
	set_health_label()


func set_health_label() -> void:
	label.text = "LIFE IS: %s" % health

func damage() -> void:
	health -= 1
	if health < 0:
		health = MAX_HEALTH
	set_health_label()
	
func restore() -> void:
	health = 3
	set_health_label()
