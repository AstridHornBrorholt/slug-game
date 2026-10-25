extends SceneTree
## Checks arena selection, local menus, and three-life elimination.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena: Node2D = load("res://Game/Arena/arena.tscn").instantiate()
	root.add_child(arena)
	if not arena.get_node("HUD/Panel").visible or arena.get_node("HUD/GameBar").visible:
		_fail("Title menu was not shown first")
		return
	if arena.get_node("%LevelSelect").item_count != 2:
		_fail("Both arenas were not listed")
		return
	var map: TileMapLayer = arena.get_node("EnvironmentMap")
	var brick_cell := Vector2i(-1, -1)
	for cell in map.get_used_cells():
		if cell.y == 0 and map.get_cell_source_id(cell) == 2:
			brick_cell = cell
			break
	if brick_cell == Vector2i(-1, -1):
		_fail("Brickworks has no ground brick to compare")
		return
	arena._apply_level(1)
	if map.get_cell_source_id(brick_cell) != 3:
		_fail("Cement Yard did not load")
		return
	arena._apply_level(0)
	if map.get_cell_source_id(brick_cell) != 2:
		_fail("Brickworks did not restore")
		return
	arena.session_joined = true
	arena._set_session_active(true)
	if arena.get_node("HUD/Panel").visible or not arena.get_node("HUD/GameBar").visible:
		_fail("In-game HUD did not replace the title menu")
		return
	arena._open_pause_menu()
	if not arena.is_local_menu_open():
		_fail("Pause menu did not open")
		return
	arena._close_pause_menu()
	if arena.is_local_menu_open():
		_fail("Pause menu did not close")
		return
	var victim = load("res://Game/Slug/slug.tscn").instantiate()
	victim.name = "2"
	victim.player_peer_id = 2
	victim.position = Vector2(575, 350)
	victim.respawn_delay = 0.05
	arena.players.add_child(victim)
	for remaining in [2, 1, 0]:
		victim.take_hit(1.0, 1, 2)
		if victim.life_state != victim.DEAD or victim.lives_remaining != remaining:
			_fail("Lethal hit did not consume exactly one life")
			return
		if remaining > 0:
			if not await _wait_until(func(): return victim.life_state == victim.SHELL):
				_fail("Slug did not respawn while lives remained")
				return
	await create_timer(0.12).timeout
	if victim.life_state != victim.DEAD:
		_fail("Eliminated slug respawned")
		return
	print("MENU_LEVELS_SMOKE_PASS")
	quit(0)


func _wait_until(condition: Callable, timeout: float = 1.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
