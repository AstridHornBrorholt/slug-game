extends CharacterBody2D

@export var speed: float = 600.0
@export var lifetime: float = 2.0

var direction: float = 1.0
var shooter_peer_id: int = 0
var launch_offset: Vector2 = Vector2.ZERO
var vertical_speed: float = 0.0
var damage: int = 1
var projectile_radius: float = 4.0
var blast_radius: float = 0.0
var weapon_type: String = "gun"


func _ready() -> void:
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	$CollisionShape2D.shape.radius = projectile_radius
	var shooter := get_node_or_null("../../Players/%d" % shooter_peer_id)
	if shooter is PhysicsBody2D:
		add_collision_exception_with(shooter)


func _draw() -> void:
	var color := Color("ed813a") if blast_radius > 0.0 else Color("242633")
	draw_circle(Vector2.ZERO, projectile_radius, color)
	draw_circle(Vector2(-1.0, -1.0), projectile_radius * 0.4, Color("f9e6aa"))

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	# Sweep the muzzle offset too, so a shot cannot start beyond a thin wall.
	var motion := launch_offset + Vector2(direction * speed * delta, vertical_speed * delta)
	launch_offset = Vector2.ZERO
	var collision := move_and_collide(motion)
	if collision:
		var target := collision.get_collider()
		if blast_radius > 0.0:
			_explode(collision.get_position())
		elif target != null and target.has_method("take_hit"):
			for hit in range(damage):
				target.take_hit(direction, shooter_peer_id)
		queue_free()


func _explode(impact_position: Vector2) -> void:
	var arena := get_parent().get_parent()
	if arena == null or not arena.has_method("spawn_explosion"):
		return
	arena.spawn_explosion(impact_position)
	for player in arena.players.get_children():
		if player.player_peer_id == shooter_peer_id:
			continue
		if player.global_position.distance_to(impact_position) <= blast_radius:
			for hit in range(damage):
				player.take_hit(direction, shooter_peer_id)
