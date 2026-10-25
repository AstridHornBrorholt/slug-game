extends SceneTree
## Two peers verify real projectile collisions, hit states, and synced deaths.

var arena: Node2D
var failures: Array[String] = []
var role: String
var sync_directory: String
var next_test_shot: int = 0


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0].trim_prefix("--")
	sync_directory = OS.get_environment("SLUG_TEST_SYNC_DIR")
	_run.call_deferred()


func _run() -> void:
	arena = load("res://Game/Arena/arena.tscn").instantiate()
	root.add_child(arena)
	arena.port = int(OS.get_environment("SLUG_TEST_PORT"))
	if role == "host":
		await _test_host()
	else:
		await _test_client()
	if failures.is_empty():
		print("MULTIPLAYER_SMOKE_PASS combat ", role)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _test_host() -> void:
	arena.host_game()
	if not await _wait_until(func(): return arena.players.get_child_count() == 2):
		_check(false, "Client never connected for combat")
		return
	var victim: Node = arena.players.get_node("1")
	var shooter: Node = _other_player()
	victim.equip_weapon("gun")
	victim.take_hit(-1.0, 1)
	_check(victim.life_state == victim.SHELL, "Own shot should not damage its slug")
	_fire_test_shot(victim, -1.0, shooter.player_peer_id)
	_check(await _wait_until(func(): return victim.life_state == victim.NAKED), "First projectile did not strip the shell")
	_check(victim.sprite.animation == &"Naked Stop", "First hit did not show naked animation")
	_check(arena.get_node("ShotOffShells").has_node("Shell_1"), "First hit did not launch the shell")
	_check(arena.get_node("BloodBursts").has_node("Blood_1"), "First hit did not produce blood")
	_check(not arena.get_node("BloodBursts/Blood_1").fatal, "First hit used the fatal burst")
	_check(arena.get_node("SeveredHeads").get_child_count() == 0, "First hit produced a head")
	_check(await _wait_until(func(): return _marked("naked")), "Client did not see the naked slug")
	_fire_test_shot(victim, -1.0, shooter.player_peer_id)
	_check(await _wait_until(func(): return victim.life_state == victim.DEAD), "Second projectile did not kill the slug")
	_check(victim.death_from_front and victim.sprite.animation == &"Dead from Front", "Wrong front death animation")
	_check(victim.weapon_type.is_empty(), "Dead slug kept its gun")
	_check(arena.get_node("DroppedGuns").get_child_count() >= 1, "Death did not throw the gun")
	_check(arena.next_shell_id == 1, "Lethal hit launched another shell")
	_check(arena.get_node("BloodBursts").has_node("Blood_2"), "Death did not produce blood")
	_check(arena.get_node("BloodBursts/Blood_2").fatal, "Death should use the larger burst")
	_check(arena.get_node("SeveredHeads").get_node_or_null("Head_1") != null, "Death did not spawn a head")
	_check(victim.collision_layer == 0, "Dead slug still blocks projectiles")
	var projectile_count: int = arena.projectiles.get_child_count()
	victim.shoot()
	_check(arena.projectiles.get_child_count() == projectile_count, "Dead slug can still shoot")
	victim.take_hit(1.0, shooter.player_peer_id)
	_check(arena.next_head_id == 1, "Dead slug spawned another head")
	_check(await _wait_until(func(): return _marked("front")), "Client did not see front death and head")
	_check(await _wait_until(func(): return victim.life_state == victim.SHELL), "Slug did not respawn")
	_check(arena.get_node("BloodBursts").get_child_count() == 0, "Blood bursts outlived the death")
	_check(victim.position.distance_to(victim.spawn_point) < 30.0, "Slug respawned at wrong position")
	_check(await _wait_until(func(): return _marked("respawn")), "Client did not see shell restored")
	_fire_test_shot(victim, 1.0, shooter.player_peer_id)
	_check(await _wait_until(func(): return victim.life_state == victim.NAKED), "Behind shot did not strip shell")
	_check(arena.get_node("ShotOffShells").has_node("Shell_2"), "Second first hit did not launch shell")
	_check(await _wait_until(func(): return _marked("second-naked")), "Client did not see second naked state")
	_fire_test_shot(victim, 1.0, shooter.player_peer_id)
	_check(await _wait_until(func(): return victim.life_state == victim.DEAD), "Behind shot did not kill slug")
	_check(not victim.death_from_front and victim.sprite.animation == &"Dead from Behind", "Wrong behind death animation")
	_check(arena.next_shell_id == 2, "Each first hit should launch one shell")
	_check(arena.next_blood_id == 4, "Each accepted hit should produce one blood burst")
	_check(arena.get_node("SeveredHeads").get_node_or_null("Head_2") != null, "Second death did not spawn a head")
	_check(await _wait_until(func(): return _marked("behind")), "Client did not see behind death")
	arena.leave_game()
	_check(arena.get_node("SeveredHeads").get_child_count() == 0, "Disconnect left severed heads behind")
	_check(arena.get_node("BloodBursts").get_child_count() == 0, "Disconnect left blood bursts behind")
	_check(arena.get_node("ShotOffShells").get_child_count() == 0, "Disconnect left shot-off shells behind")
	await create_timer(0.3).timeout


func _test_client() -> void:
	arena.join_game("127.0.0.1")
	if not await _wait_until(func(): return arena.players.get_child_count() == 2):
		_check(false, "Client did not receive players")
		return
	var victim: Node = arena.players.get_node("1")
	_check(await _wait_until(func(): return victim.life_state == victim.NAKED), "Client missed first hit")
	_check(await _wait_until(func(): return victim.sprite.animation == &"Naked Stop"), "Client missed naked animation")
	_check(await _wait_until(func(): return arena.get_node("ShotOffShells").has_node("Shell_1")), "Client missed first shell")
	_check(await _wait_until(func(): return arena.get_node("BloodBursts").has_node("Blood_1")), "Client missed first blood burst")
	_mark("naked")
	_check(await _wait_until(func(): return victim.life_state == victim.DEAD), "Client missed first death")
	_check(await _wait_until(func():
		return victim.death_from_front and victim.sprite.animation == &"Dead from Front"
	), "Client missed front animation")
	_check(await _wait_until(func(): return arena.get_node("SeveredHeads").has_node("Head_1")), "Client missed first head")
	_check(await _wait_until(func(): return arena.get_node("DroppedGuns").get_child_count() >= 1), "Client missed dropped gun")
	_check(await _wait_until(func(): return arena.get_node("BloodBursts").has_node("Blood_2")), "Client missed death blood burst")
	_mark("front")
	_check(await _wait_until(func(): return victim.life_state == victim.SHELL), "Client missed respawn")
	_check(await _wait_until(func(): return victim.sprite.animation == &"Shell Stop"), "Client missed restored shell")
	_mark("respawn")
	_check(await _wait_until(func(): return victim.life_state == victim.NAKED), "Client missed second naked state")
	_check(await _wait_until(func(): return arena.get_node("ShotOffShells").has_node("Shell_2")), "Client missed second shell")
	_mark("second-naked")
	_check(await _wait_until(func(): return victim.life_state == victim.DEAD), "Client missed behind death")
	_check(await _wait_until(func():
		return not victim.death_from_front and victim.sprite.animation == &"Dead from Behind"
	), "Client missed behind animation")
	_check(await _wait_until(func(): return arena.get_node("SeveredHeads").has_node("Head_2")), "Client missed second head")
	_mark("behind")
	_check(await _wait_until(func(): return arena.players.get_child_count() == 0), "Host loss did not remove players")
	_check(arena.get_node("SeveredHeads").get_child_count() == 0, "Host loss did not remove heads")
	_check(arena.get_node("BloodBursts").get_child_count() == 0, "Host loss did not remove blood bursts")
	_check(arena.get_node("ShotOffShells").get_child_count() == 0, "Host loss did not remove shot-off shells")


func _other_player() -> Node:
	for player in arena.players.get_children():
		if player.player_peer_id != 1:
			return player
	return null


func _fire_test_shot(victim: Node, direction: float, shooter_id: int) -> void:
	next_test_shot += 1
	arena.projectile_spawner.spawn({
		"id": 100000 + next_test_shot,
		"position": victim.position + Vector2(-direction * 35.0, -1.0),
		"direction": direction,
		"shooter_peer_id": shooter_id,
		"muzzle_offset": Vector2.ZERO,
	})


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
