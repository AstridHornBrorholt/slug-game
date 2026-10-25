extends SceneTree
## Run one host and one client with --script res://tests/multiplayer_smoke.gd
## and pass -- --host or -- --client after Godot's arguments.

var arena: Node2D
var failures: Array[String] = []
var saw_host_shot: bool = false
var saw_client_shot: bool = false
var saw_client_move: bool = false
var saw_client_jump: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if not is_instance_valid(arena) or not arena.is_node_ready():
		return false
	for projectile in arena.projectiles.get_children():
		if projectile.shooter_peer_id == 1:
			saw_host_shot = true
		else:
			saw_client_shot = true
	for player in arena.players.get_children():
		if player.player_peer_id != 1:
			saw_client_move = saw_client_move or player.position.x < 630.0
			saw_client_jump = saw_client_jump or player.velocity.y < -50.0
	return false


func _run() -> void:
	arena = load("res://Game/Arena/arena.tscn").instantiate()
	root.add_child(arena)
	arena.port = int(OS.get_environment("SLUG_TEST_PORT"))
	if "--host" in OS.get_cmdline_user_args():
		await _test_host()
	else:
		await _test_client()
	for action in ["p1 left", "p1 right", "p1 jump", "p1 act"]:
		Input.action_release(action)
	if failures.is_empty():
		print("MULTIPLAYER_SMOKE_PASS ", OS.get_cmdline_user_args())
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _test_host() -> void:
	arena.max_players = 2
	arena.host_game()
	_check(arena.players.get_child_count() == 1, "Host should spawn P1 immediately")
	if not await _wait_until(func(): return arena.players.get_child_count() == 2):
		_check(false, "Client did not join the host")
		return
	if not await _wait_until(func(): return saw_client_move and saw_client_jump and saw_client_shot):
		_check(false, "Host did not simulate the client's movement, jump, and shooting")
		return
	_check(absf(arena.players.get_node("1").position.x - 490.0) < 1.0,
		"Client was able to control the host's slug")
	Input.action_press("p1 act")
	await create_timer(0.3).timeout
	Input.action_release("p1 act")
	_check(saw_host_shot, "Host did not fire a projectile")
	_check(await _wait_until(func(): return arena.players.get_child_count() == 1),
		"Disconnected client's slug was not removed")
	_check(await _wait_until(func(): return arena.players.get_child_count() == 2),
		"Client could not reconnect")
	await create_timer(2.3).timeout
	_check(arena.projectiles.get_child_count() == 0, "Projectiles did not expire")
	arena.leave_game()
	_check(arena.players.get_child_count() == 0, "Host disconnect did not clear players")
	await create_timer(0.5).timeout


func _test_client() -> void:
	arena.join_game("127.0.0.1")
	if not await _wait_until(func(): return arena.players.get_child_count() == 2):
		_check(false, "Client did not receive two replicated slugs")
		return
	var local_player: Node = arena.players.get_node(str(arena.multiplayer.get_unique_id()))
	_check(local_player.player_number == 2, "Client did not get P2")
	_check("you" in local_player.get_node("PlayerLabel").text, "Local player label is wrong")
	await create_timer(0.4).timeout
	# Try to spoof the other player's controls; the host must reject this RPC.
	arena.players.get_node("1")._submit_controls.rpc_id(1, 1.0, true, true)
	Input.action_press("p1 left")
	await create_timer(0.25).timeout
	Input.action_release("p1 left")
	Input.action_press("p1 jump")
	await create_timer(0.15).timeout
	Input.action_release("p1 jump")
	Input.action_press("p1 act")
	await create_timer(0.4).timeout
	Input.action_release("p1 act")
	_check(saw_client_move, "Client did not receive its replicated movement")
	_check(saw_client_jump, "Client did not receive its replicated jump")
	_check(saw_client_shot, "Client did not receive its own projectile")
	_check(await _wait_until(func(): return saw_host_shot), "Client did not receive host projectiles")
	arena.leave_game()
	_check(arena.players.get_child_count() == 0, "Client disconnect did not clear players")
	await create_timer(0.5).timeout
	arena.join_game("127.0.0.1")
	_check(await _wait_until(func(): return arena.players.get_child_count() == 2),
		"Client did not receive the players after reconnecting")
	_check(await _wait_until(func(): return arena.players.get_child_count() == 0),
		"Client did not clean up after the host disconnected")
	_check(not arena.get_node("%HostButton").disabled, "Host button did not recover after disconnect")
	arena.host_game()
	_check(arena.players.get_child_count() == 1, "Client could not become a host after disconnect")
	arena.leave_game()
	# Running the slug prefab alone must still allow shooting without an arena parent.
	var slug: Node2D = load("res://Game/Slug/slug.tscn").instantiate()
	root.add_child(slug)
	var child_count := root.get_child_count()
	slug.shoot()
	_check(root.get_child_count() == child_count + 1, "Standalone slug could not shoot")
	for node in root.get_children():
		if node != arena:
			node.queue_free()
	await process_frame


func _wait_until(condition: Callable, timeout: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
