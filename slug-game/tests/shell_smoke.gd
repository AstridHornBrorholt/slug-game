extends SceneTree
## Checks the first-hit shell effect and its cleanup without opening a socket.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena = load("res://Game/Arena/arena.tscn").instantiate()
	root.add_child(arena)
	var slug = load("res://Game/Slug/slug.tscn").instantiate()
	slug.name = "2"
	slug.player_peer_id = 2
	slug.position = Vector2(550, 380)
	arena.players.add_child(slug)
	slug.take_hit(-1.0, 1)
	if slug.life_state != slug.NAKED or arena.get_node("ShotOffShells").get_child_count() != 1:
		_fail("First hit did not strip and launch the shell")
		return
	var shell = arena.get_node("ShotOffShells/Shell_1")
	var sprite: Sprite2D = shell.get_node("Sprite2D")
	if sprite.texture == null or sprite.texture.resource_path != "res://Game/Slug/Sprite-Shell2.png":
		_fail("Shot-off shell should show one steady image")
		return
	if shell.launch_velocity.x >= 0.0 or shell.collision_layer != 0:
		_fail("Shell does not launch in the shot direction or blocks players")
		return
	var starting_position: Vector2 = shell.position
	await create_timer(0.3).timeout
	if shell.position == starting_position or is_zero_approx(shell.rotation):
		_fail("Shot-off shell did not fly and spin")
		return
	slug.take_hit(-1.0, 1)
	if slug.life_state != slug.DEAD or arena.next_shell_id != 1:
		_fail("Lethal hit launched another shell")
		return
	await create_timer(4.2).timeout
	if arena.get_node("ShotOffShells").get_child_count() != 0:
		_fail("Shot-off shell did not despawn")
		return
	print("SHELL_SMOKE_PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
