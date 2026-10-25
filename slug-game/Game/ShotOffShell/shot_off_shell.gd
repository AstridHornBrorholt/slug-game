extends CharacterBody2D

@export var lifetime: float = 4.0

var launch_velocity: Vector2 = Vector2.ZERO
var spin_speed: float = 0.0


func _ready() -> void:
	velocity = launch_velocity


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	velocity += get_gravity() * delta
	var collision := move_and_collide(velocity * delta)
	if collision:
		velocity = velocity.bounce(collision.get_normal()) * 0.35
		spin_speed *= 0.6
	rotation += spin_speed * delta
