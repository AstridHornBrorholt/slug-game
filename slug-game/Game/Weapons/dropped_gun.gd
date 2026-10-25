extends CharacterBody2D

@export var lifetime: float = 3.0

var weapon_type: String = "gun"
var launch_velocity: Vector2 = Vector2.ZERO
var spin_speed: float = 0.0


func _ready() -> void:
	$Sprite2D.texture = WeaponCatalog.texture(weapon_type)
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
		velocity = velocity.bounce(collision.get_normal()) * 0.3
		spin_speed *= 0.55
	rotation += spin_speed * delta
