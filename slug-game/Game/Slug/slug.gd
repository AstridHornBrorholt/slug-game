extends CharacterBody2D

const PROJECTILE_SCENE: PackedScene = preload("res://Game/Projectile/projectile.tscn")

@export var move_speed: float = 240.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var jump_velocity: float = -400.0
@export var shoot_interval: float = 0.2
@export var muzzle_offset: Vector2 = Vector2(24.0, -2.0)

var player_peer_id: int = 1
var player_number: int = 1
var spawn_point: Vector2 = Vector2.ZERO
var facing_direction: float = 1.0
var shoot_cooldown: float = 0.0
var move_input: float = 0.0
var jump_held: bool = false
var shoot_held: bool = false
var jump_requested: bool = false
var jump_cut_requested: bool = false
var last_sent_direction: float = 2.0
var last_sent_jump: bool = false
var last_sent_shoot: bool = false

@onready var sprite: AnimatedSprite2D = $SpriteSheet


func _ready() -> void:
	sprite.modulate = Color.WHITE if player_number == 1 else Color("97d9ff")
	$PlayerLabel.text = "P%d%s" % [
		player_number, " (you)" if player_peer_id == multiplayer.get_unique_id() else ""
	]
	if spawn_point == Vector2.ZERO:
		spawn_point = position


func _physics_process(delta: float) -> void:
	if player_peer_id == multiplayer.get_unique_id():
		_read_local_controls()
	# Only the host simulates bodies; clients receive their state from the synchronizer.
	if not multiplayer.is_server():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if jump_requested and is_on_floor():
		velocity.y = jump_velocity

	# Releasing jump early gives the player a shorter hop.
	if jump_cut_requested and velocity.y < 0.0:
		velocity.y *= 0.5
	jump_requested = false
	jump_cut_requested = false

	var direction := move_input
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
		facing_direction = direction
		sprite.flip_h = direction > 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	if position.y > 1000.0:
		position = spawn_point
		velocity = Vector2.ZERO

	shoot_cooldown = maxf(shoot_cooldown - delta, 0.0)
	if shoot_held and shoot_cooldown <= 0.0:
		shoot()
		shoot_cooldown = shoot_interval


func _process(_delta: float) -> void:
	sprite.flip_h = facing_direction > 0.0


func _read_local_controls() -> void:
	var direction := Input.get_axis("p1 left", "p1 right")
	var jumping := Input.is_action_pressed("p1 jump")
	var shooting := Input.is_action_pressed("p1 act")
	if multiplayer.is_server():
		_apply_controls(direction, jumping, shooting)
	elif direction != last_sent_direction or jumping != last_sent_jump or shooting != last_sent_shoot:
		_submit_controls.rpc_id(1, direction, jumping, shooting)
		last_sent_direction = direction
		last_sent_jump = jumping
		last_sent_shoot = shooting


@rpc("any_peer", "call_remote", "reliable")
func _submit_controls(direction: float, jumping: bool, shooting: bool) -> void:
	# A peer may only control its own slug, never the other player's.
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player_peer_id:
		return
	if not is_finite(direction):
		return
	_apply_controls(clampf(direction, -1.0, 1.0), jumping, shooting)


func _apply_controls(direction: float, jumping: bool, shooting: bool) -> void:
	move_input = direction
	if jumping and not jump_held:
		jump_requested = true
	if not jumping and jump_held:
		jump_cut_requested = true
	jump_held = jumping
	shoot_held = shooting


func shoot() -> void:
	var arena := get_parent().get_parent()
	if arena != null and arena.has_method("spawn_projectile"):
		arena.spawn_projectile(self)
		return
	# Keep the prefab usable when running a scene without the multiplayer arena.
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.direction = facing_direction
	projectile.add_collision_exception_with(self)
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(
		muzzle_offset.x * facing_direction, muzzle_offset.y
	)
