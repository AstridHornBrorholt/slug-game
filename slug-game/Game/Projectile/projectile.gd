extends CharacterBody2D

@export var speed: float = 600.0
@export var lifetime: float = 2.0

var direction: float = 1.0
var shooter_peer_id: int = 0
var launch_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	var shooter := get_node_or_null("../../Players/%d" % shooter_peer_id)
	if shooter is PhysicsBody2D:
		add_collision_exception_with(shooter)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color("0a0a0a"))
	draw_circle(Vector2(-1.0, -1.0), 1.5, Color("aaaaaa"))

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	# Sweep the muzzle offset too, so a shot cannot start beyond a thin wall.
	var motion := launch_offset + Vector2(direction * speed * delta, 0.0)
	launch_offset = Vector2.ZERO
	var collision := move_and_collide(motion)
	if collision:
		queue_free()
