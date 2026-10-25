extends CPUParticles2D

var shot_direction: float = 1.0
var fatal: bool = false


func _ready() -> void:
	amount = 18 if fatal else 8
	lifetime = 0.65 if fatal else 0.45
	direction = Vector2(shot_direction, -0.45).normalized()
	initial_velocity_min = 95.0 if fatal else 65.0
	initial_velocity_max = 205.0 if fatal else 135.0
	spread = 48.0
	gravity = Vector2(0.0, 560.0)
	restart()
	emitting = true
	# Only the host removes replicated effects; clients receive that despawn.
	if multiplayer.is_server():
		get_tree().create_timer(lifetime + 0.15).timeout.connect(queue_free)
