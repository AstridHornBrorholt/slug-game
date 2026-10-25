extends CharacterBody2D

const PROJECTILE_SCENE: PackedScene = preload("res://Game/Projectile/projectile.tscn")
const SHELL: int = 0
const NAKED: int = 1
const DEAD: int = 2
const STARTING_LIVES: int = 3

@export var move_speed: float = 240.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var jump_velocity: float = -400.0
@export var shoot_interval: float = 0.2
@export var muzzle_offset: Vector2 = Vector2(24.0, -2.0)
@export var respawn_delay: float = 3.0
@export var hit_invulnerability_duration: float = 0.25

var life_state: int = SHELL
var lives_remaining: int = STARTING_LIVES
var hit_invulnerability_remaining: float = 0.0
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
var weapon_type: String = ""
var ammo: int = 0
var weapon_animation_time: float = 0.0
var last_visible_weapon: String = ""
var last_visible_ammo: int = 0

@onready var sprite: AnimatedSprite2D = $SpriteSheet
@onready var weapon_sprite: Sprite2D = $WeaponSprite


func _ready() -> void:
	sprite.modulate = Color.WHITE if player_number == 1 else Color.from_hsv(
		fposmod(0.55 + (player_number - 2) * 0.618034, 1.0), 0.4, 1.0
	)
	_update_player_label()
	if spawn_point == Vector2.ZERO:
		spawn_point = position
	_update_appearance()


func _physics_process(delta: float) -> void:
	if player_peer_id == multiplayer.get_unique_id():
		_read_local_controls()
	# Only the host simulates bodies; clients receive their state from the synchronizer.
	if not multiplayer.is_server():
		return
	hit_invulnerability_remaining = maxf(hit_invulnerability_remaining - delta, 0.0)
	if life_state == DEAD:
		velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		move_and_slide()
		respawn_timer -= delta
		if respawn_timer <= 0.0 and lives_remaining > 0:
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
		_fall_out()

	shoot_cooldown = maxf(shoot_cooldown - delta, 0.0)
	if shoot_held and shoot_cooldown <= 0.0 and not weapon_type.is_empty():
		shoot()


func _process(delta: float) -> void:
	weapon_animation_time = maxf(weapon_animation_time - delta, 0.0)
	_update_appearance()


func _update_appearance() -> void:
	_update_player_label()
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
	_update_weapon_visual()


func _update_player_label() -> void:
	$PlayerLabel.text = "P%d%s  Lives %d" % [
		player_number, " (you)" if player_peer_id == multiplayer.get_unique_id() else "",
		lives_remaining,
	]


func _update_weapon_visual() -> void:
	var holding := life_state != DEAD and not weapon_type.is_empty()
	weapon_sprite.visible = holding
	$WeaponLabel.visible = holding
	if not holding:
		last_visible_weapon = weapon_type
		last_visible_ammo = ammo
		return
	if weapon_type == last_visible_weapon and ammo < last_visible_ammo:
		weapon_animation_time = 0.35 if weapon_type == "shotgun" else 0.17
	last_visible_weapon = weapon_type
	last_visible_ammo = ammo
	var frame := 0
	if weapon_type == "shotgun" and weapon_animation_time > 0.0:
		frame = 1 if weapon_animation_time > 0.18 else 2
	elif weapon_type == "minigun" and weapon_animation_time > 0.0:
		frame = int(Time.get_ticks_msec() / 55) % 2
	weapon_sprite.texture = WeaponCatalog.texture(weapon_type, frame)
	weapon_sprite.position = Vector2(9.0 * facing_direction, -7.0)
	weapon_sprite.flip_h = facing_direction < 0.0
	var stats := WeaponCatalog.data(weapon_type)
	$WeaponLabel.text = "%s  %d" % [stats.name, ammo]


func can_pick_up_weapon() -> bool:
	return multiplayer.is_server() and life_state != DEAD and weapon_type.is_empty()


func equip_weapon(kind: String) -> void:
	if not can_pick_up_weapon():
		return
	var stats := WeaponCatalog.data(kind)
	if stats.is_empty():
		return
	weapon_type = kind
	ammo = int(stats.ammo)
	shoot_cooldown = 0.0
	_update_weapon_visual()


func _discard_weapon() -> void:
	if weapon_type.is_empty():
		return
	var arena := get_parent().get_parent()
	if arena != null and arena.has_method("discard_weapon"):
		arena.discard_weapon(self, weapon_type)
	weapon_type = ""
	ammo = 0
	weapon_animation_time = 0.0
	_update_weapon_visual()


func take_hit(shot_direction: float, shooter_peer_id: int, damage: int = 1) -> void:
	if not multiplayer.is_server() or life_state == DEAD or shooter_peer_id == player_peer_id:
		return
	if hit_invulnerability_remaining > 0.0 or damage <= 0:
		return
	var fatal := life_state == NAKED or damage >= 2
	var arena := get_parent().get_parent()
	if arena != null and arena.has_method("spawn_blood"):
		arena.spawn_blood(self, shot_direction, fatal)
	if life_state == SHELL:
		if arena != null and arena.has_method("spawn_shot_off_shell"):
			arena.spawn_shot_off_shell(self, shot_direction)
	if fatal:
		lives_remaining = maxi(lives_remaining - 1, 0)
		_discard_weapon()
		life_state = DEAD
		death_from_front = shot_direction * facing_direction < 0.0
		respawn_timer = respawn_delay
		velocity.x = 0.0
		shoot_held = false
		jump_requested = false
		jump_cut_requested = false
		if arena != null and arena.has_method("spawn_severed_head"):
			arena.spawn_severed_head(self, shot_direction)
	else:
		life_state = NAKED
	hit_invulnerability_remaining = hit_invulnerability_duration
	_update_appearance()
	if fatal and lives_remaining == 0 and arena != null and arena.has_method("on_slug_eliminated"):
		arena.on_slug_eliminated()


func _respawn() -> void:
	_discard_weapon()
	life_state = SHELL
	hit_invulnerability_remaining = 0.0
	death_from_front = false
	position = spawn_point
	velocity = Vector2.ZERO
	jump_requested = false
	jump_cut_requested = false
	shoot_cooldown = shoot_interval
	_update_appearance()


func _fall_out() -> void:
	lives_remaining = maxi(lives_remaining - 1, 0)
	if lives_remaining > 0:
		_respawn()
		return
	_discard_weapon()
	life_state = DEAD
	respawn_timer = 0.0
	velocity = Vector2.ZERO
	_update_appearance()
	var arena := get_parent().get_parent()
	if arena != null and arena.has_method("on_slug_eliminated"):
		arena.on_slug_eliminated()


func _read_local_controls() -> void:
	var direction := Input.get_axis("p1 left", "p1 right")
	var jumping := Input.is_action_pressed("p1 jump")
	var shooting := Input.is_action_pressed("p1 act")
	var arena := get_parent().get_parent()
	if arena != null and arena.has_method("is_local_menu_open") and arena.is_local_menu_open():
		direction = 0.0
		jumping = false
		shooting = false
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
	if not multiplayer.is_server() or life_state == DEAD or weapon_type.is_empty() or ammo <= 0:
		return
	var stats := WeaponCatalog.data(weapon_type)
	var arena := get_parent().get_parent()
	if arena != null and arena.has_method("fire_weapon"):
		arena.fire_weapon(self, weapon_type)
	else:
		# The prefab remains shootable in a scene without the arena.
		var projectile = PROJECTILE_SCENE.instantiate()
		projectile.direction = facing_direction
		projectile.speed = stats.speed
		projectile.damage = stats.damage
		projectile.projectile_radius = stats.radius
		projectile.blast_radius = stats.blast
		projectile.weapon_type = weapon_type
		projectile.add_collision_exception_with(self)
		get_parent().add_child(projectile)
		projectile.global_position = global_position + Vector2(
			WeaponCatalog.muzzle_offset(weapon_type).x * facing_direction,
			WeaponCatalog.muzzle_offset(weapon_type).y
		)
	ammo -= 1
	shoot_cooldown = float(stats.cooldown)
	if ammo <= 0:
		_discard_weapon()
	else:
		_update_weapon_visual()
