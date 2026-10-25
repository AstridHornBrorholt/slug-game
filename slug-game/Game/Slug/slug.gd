extends CharacterBody2D

const PROJECTILE_SCENE: PackedScene = preload("res://Game/Projectile/projectile.tscn")

@export var move_speed: float = 240.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var jump_velocity: float = -400.0
@export var shoot_interval: float = 0.2
@export var muzzle_offset: Vector2 = Vector2(24.0, -2.0)

var facing_direction: float = 1.0
var shoot_cooldown: float = 0.0

@onready var sprite: Sprite2D = $PastedImage


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("p1 jump") and is_on_floor():
		velocity.y = jump_velocity

	# Releasing jump early gives the player a shorter hop.
	if Input.is_action_just_released("p1 jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	var direction := Input.get_axis("p1 left", "p1 right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
		facing_direction = direction
		sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()

	shoot_cooldown = maxf(shoot_cooldown - delta, 0.0)
	if Input.is_action_pressed("p1 act") and shoot_cooldown <= 0.0:
		shoot()
		shoot_cooldown = shoot_interval


func shoot() -> void:
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.direction = facing_direction
	projectile.add_collision_exception_with(self)
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(
		muzzle_offset.x * facing_direction, muzzle_offset.y
	)
