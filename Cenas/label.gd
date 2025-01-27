extends Node

@export var label: Label
@export var status: Node

func _process(delta: float) -> void:
	label.text = "X: %s" % status.current_health
	
