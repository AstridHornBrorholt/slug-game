extends SceneTree
## Four real peers exercise three seats, full-room rejection, and seat reuse.

var arena: Node2D
var failures: Array[String] = []
var role: String
var sync_directory: String


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0].trim_prefix("--")
	sync_directory = OS.get_environment("SLUG_TEST_SYNC_DIR")
	_run.call_deferred()


func _run() -> void:
	arena = load("res://Game/Arena/arena.tscn").instantiate()
	root.add_child(arena)
	match role:
		"host": await _test_host()
		"first": await _test_first()
		"second": await _test_second()
		"overflow": await _test_overflow()
	if failures.is_empty():
		print("MULTIPLAYER_SMOKE_PASS capacity ", role)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _test_host() -> void:
	_check(arena.max_players == 3, "Default capacity should be three including the host")
	arena.host_game()
	if not await _wait_until(func(): return arena.players.get_child_count() == 3):
		_check(false, "Three players did not join")
		return
	await _check_roster()
	_mark("full")
	_check(await _wait_until(func(): return _marked("rejected")), "Fourth player was not explicitly rejected")
	_check(arena.players.get_child_count() == 3, "Overflow player entered a full room")
	_mark("release")
	_check(await _wait_until(func(): return arena.players.get_child_count() == 2), "Leaving did not free a seat")
	_check(await _wait_until(func(): return "2/3 players" in arena.status.text), "Occupancy did not decrease after leaving")
	_mark("free")
	_check(await _wait_until(func(): return arena.players.get_child_count() == 3), "Replacement could not join")
	await _check_roster()
	_mark("replacement")
	_check(await _wait_until(func(): return _marked("replacement-verified") and _marked("second-verified")),
		"Existing and replacement clients did not receive the updated roster")
	arena.leave_game()
	await create_timer(0.4).timeout


func _test_first() -> void:
	arena.join_game("127.0.0.1")
	if not await _wait_until(func(): return arena.players.get_child_count() == 2):
		_check(false, "First client did not join")
		return
	_check(_local_player().player_number == 2, "First client did not get P2")
	_mark("first")
	_check(await _wait_until(func(): return _marked("release")), "Host did not request a freed seat")
	arena.leave_game()


func _test_second() -> void:
	_check(await _wait_until(func(): return _marked("first")), "First client was not ready")
	arena.join_game("127.0.0.1")
	if not await _wait_until(func(): return arena.players.get_child_count() == 3):
		_check(false, "Second client did not receive three players")
		return
	_check(_local_player().player_number == 3, "Second client did not get P3")
	await _check_roster()
	var old_peer_id := 0
	for player in arena.players.get_children():
		if player.player_number == 2:
			old_peer_id = player.player_peer_id
	_check(await _wait_until(func(): return _marked("replacement")), "Host never received replacement")
	_check(await _wait_until(func():
		return arena.players.get_child_count() == 3 and not arena.players.has_node(str(old_peer_id))
	), "P3 did not receive the changed roster")
	await _check_roster()
	_mark("second-verified")
	_check(await _wait_until(func(): return arena.players.get_child_count() == 0), "Host loss did not clean up P3")


func _test_overflow() -> void:
	_check(await _wait_until(func(): return _marked("full")), "Room was never full")
	arena.join_game("127.0.0.1")
	_check(await _wait_until(func(): return "Room full" in arena.status.text), "No room-full message was shown")
	_check("3 players maximum" in arena.status.text, "Rejection did not show the host's capacity")
	_check(arena.players.get_child_count() == 0, "Rejected client received gameplay nodes")
	_check(not arena.get_node("%JoinButton").disabled, "Rejected client cannot retry")
	_mark("rejected")
	_check(await _wait_until(func(): return _marked("free")), "Host never freed a seat")
	arena.join_game("127.0.0.1")
	if not await _wait_until(func(): return arena.players.get_child_count() == 3):
		_check(false, "Previously rejected client could not retry")
		return
	_check(_local_player().player_number == 2, "Replacement did not reuse the free P2 slot")
	await _check_roster()
	_mark("replacement-verified")
	_check(await _wait_until(func(): return arena.players.get_child_count() == 0), "Host loss did not clean up replacement")


func _local_player() -> Node:
	return arena.players.get_node(str(arena.multiplayer.get_unique_id()))


func _check_roster() -> void:
	var numbers: Array[int] = []
	var spawn_points: Array[Vector2] = []
	var colors: Array[Color] = []
	for player in arena.players.get_children():
		numbers.append(player.player_number)
		_check(not spawn_points.has(player.spawn_point), "Two players share a spawn point")
		spawn_points.append(player.spawn_point)
		var color: Color = player.get_node("SpriteSheet").modulate
		_check(not colors.has(color), "Two players share a color")
		colors.append(color)
	numbers.sort()
	_check(numbers == [1, 2, 3], "Player numbers are not unique P1/P2/P3")
	_check(await _wait_until(func(): return "3/3 players" in arena.status.text),
		"Status does not show the correct occupancy: %s" % arena.status.text)


func _mark(marker: String) -> void:
	var file := FileAccess.open(sync_directory.path_join(marker), FileAccess.WRITE)
	file.store_string("ready")


func _marked(marker: String) -> bool:
	return FileAccess.file_exists(sync_directory.path_join(marker))


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
