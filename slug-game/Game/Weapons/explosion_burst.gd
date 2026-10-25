extends CPUParticles2D


func _ready() -> void:
	restart()
	emitting = true
	if multiplayer.is_server():
		get_tree().create_timer(lifetime + 0.15).timeout.connect(queue_free)
