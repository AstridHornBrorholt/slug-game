extends CharacterBody2D

const PROJECTILE_SCENE: PackedScene = preload("res://Game/Projectile/projectile.tscn")
const SHELL: int = 0
const NAKED: int = 1
const DEAD: int = 2

@export var move_speed: float = 240.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var jump_velocity: float = -400.0
@export var shoot_interval: float = 0.2
@export var muzzle_offset: Vector2 = Vector2(24.0, -2.0)
@export var respawn_delay: float = 3.0

var life_state: int = SHELL
var death_from_front: bool = false
var respawn_timer: float = 0.0
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
	sprite.modulate = Color.WHITE if player_number == 1 else Color.from_hsv(
		fposmod(0.55 + (player_number - 2) * 0.618034, 1.0), 0.4, 1.0
	)
	$PlayerLabel.text = "P%d%s" % [
		player_number, " (you)" if player_peer_id == multiplayer.get_unique_id() else ""
	]
	if spawn_point == Vector2.ZERO:
		spawn_point = position
	_update_appearance()


func _physics_process(delta: float) -> void:
	if player_peer_id == multiplayer.get_unique_id():
		_read_local_controls()
	# Only the host simulates bodies; clients receive their state from the synchronizer.
	if not multiplayer.is_server():
		return
	if life_state == DEAD:
		velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		move_and_slide()
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
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
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	if position.y > 1000.0:
		_respawn()

	shoot_cooldown = maxf(shoot_cooldown - delta, 0.0)
	if shoot_held and shoot_cooldown <= 0.0:
		shoot()
		shoot_cooldown = shoot_interval


func _process(_delta: float) -> void:
	_update_appearance()


func _update_appearance() -> void:
	sprite.flip_h = facing_direction > 0.0
	var animation: StringName
	if life_state == DEAD:
		animation = &"Dead from Front" if death_from_front else &"Dead from Behind"
	else:
		var state := "Naked" if life_state == NAKED else "Shell"
		var direction := Input.get_axis("p1 left", "p1 right") if player_peer_id == multiplayer.get_unique_id() else move_input
		animation = StringName("%s %s" % [state, "Move" if direction != 0.0 else "Stop"])
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)
	$PlayerLabel.visible = life_state != DEAD
	collision_layer = 0 if life_state == DEAD else 2
	collision_mask = 1 if life_state == DEAD else 3


func take_hit(shot_direction: float, shooter_peer_id: int) -> void:
	if not multiplayer.is_server() or life_state == DEAD or shooter_peer_id == player_peer_id:
		return
	var fatal := life_state == NAKED
	var arena := get_parent().get_parent()
	if arena != null and arena.has_method("spawn_blood"):
		arena.spawn_blood(self, shot_direction, fatal)
	if life_state == SHELL:
		if arena != null and arena.has_method("spawn_shot_off_shell"):
			arena.spawn_shot_off_shell(self, shot_direction)
		life_state = NAKED
	else:
		life_state = DEAD
		death_from_front = shot_direction * facing_direction < 0.0
		respawn_timer = respawn_delay
		velocity.x = 0.0
		shoot_held = false
		jump_requested = false
		jump_cut_requested = false
		if arena != null and arena.has_method("spawn_severed_head"):
			arena.spawn_severed_head(self, shot_direction)
	_update_appearance()


func _respawn() -> void:
	life_state = SHELL
	death_from_front = false
	position = spawn_point
	velocity = Vector2.ZERO
	jump_requested = false
	jump_cut_requested = false
	shoot_cooldown = shoot_interval
	_update_appearance()


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
	if life_state == DEAD:
		return
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
