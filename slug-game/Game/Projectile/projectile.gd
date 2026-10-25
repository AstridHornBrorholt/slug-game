extends CharacterBody2D

@export var speed: float = 600.0
@export var lifetime: float = 2.0

var direction: float = 1.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color("0a0a0a"))
	draw_circle(Vector2(-1.0, -1.0), 1.5, Color("aaaaaa"))

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	var collision := move_and_collide(Vector2(direction * speed * delta, 0.0))
	if collision:
		queue_free()
