extends CharacterBody2D

@export var move_speed: float = 240.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var jump_velocity: float = -400.0

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
		sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
