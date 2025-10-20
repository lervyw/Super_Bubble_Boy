extends CanvasLayer
var time_left: int = 18000
@export var player: Node
#int = 18000
@export var tempo : Node
func _ready() -> void:
	update_timer_text()
	set_process(true)
func _process(delta: float) -> void:
	if time_left >0:
		time_left -= delta
		update_timer_text()
	else:
		time_left = 0
		set_process(false)
		on_timer_end()
func update_timer_text():
	var minutes = int(time_left)/60
	var seconds = int(time_left)%60
	tempo.text = "%02d:%02d" % [minutes, seconds]
func on_timer_end():
	player.dead = true
