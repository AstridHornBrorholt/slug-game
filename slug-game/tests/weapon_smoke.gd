extends SceneTree
## Exercises automatic pickup, ammo, discard, spawn delay, and every weapon type.

var arena: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	arena = load("res://Game/Arena/arena.tscn").instantiate()
	root.add_child(arena)
	arena.session_joined = true
	arena.weapon_respawn_delay = 0.6
	if WeaponCatalog.ids().size() != 7:
		_fail("Seven weapon types should be available")
		return
	for kind in WeaponCatalog.ids():
		if WeaponCatalog.texture(kind) == null or int(WeaponCatalog.data(kind).ammo) <= 0:
			_fail("Missing weapon art or ammo for %s" % kind)
			return
	for slot in range(arena.get_node("WeaponSpawnPoints").get_child_count()):
		arena._spawn_weapon_pickup(slot)
	if arena.get_node("WeaponPickups").get_child_count() != 3:
		_fail("Weapon spawn markers did not create three pickups")
		return
	var pickup = arena.active_pickups[0]
	var picked_type: String = pickup.weapon_type
	var slug = load("res://Game/Slug/slug.tscn").instantiate()
	slug.name = "2"
	slug.player_peer_id = 2
	slug.position = pickup.position
	arena.players.add_child(slug)
	if not await _wait_until(func(): return slug.weapon_type == picked_type):
		_fail("Walking over the gun did not pick it up")
		return
	if slug.ammo != int(WeaponCatalog.data(picked_type).ammo):
		_fail("Pickup did not load its limited ammo")
		return
	slug.position = Vector2(520, 390)
	if arena.get_node("WeaponPickups").get_child_count() != 2:
		_fail("Claimed weapon remained on the map")
		return
	if not await _wait_until(func(): return arena.get_node("WeaponPickups").get_child_count() == 3):
		_fail("Picked-up gun did not respawn after the delay")
		return
	if arena.active_pickups[0] == pickup:
		_fail("Respawn reused the collected pickup")
		return
	var initial_ammo: int = slug.ammo
	slug.shoot()
	if slug.ammo != initial_ammo - 1:
		_fail("Firing did not consume ammo")
		return
	while not slug.weapon_type.is_empty():
		for projectile in arena.projectiles.get_children():
			projectile.free()
		slug.shoot()
	if arena.get_node("DroppedGuns").get_child_count() != 1:
		_fail("Empty gun was not thrown away")
		return
	if slug.ammo != 0 or slug.weapon_sprite.visible:
		_fail("Empty gun still appears held")
		return
	for projectile in arena.projectiles.get_children():
		projectile.free()
	var dropped_count: int = arena.get_node("DroppedGuns").get_child_count()
	slug.shoot()
	if arena.projectiles.get_child_count() != 0 or arena.get_node("DroppedGuns").get_child_count() != dropped_count:
		_fail("Unarmed slug continued shooting")
		return
	for kind in WeaponCatalog.ids():
		slug.equip_weapon(kind)
		if slug.weapon_type != kind or slug.weapon_sprite.texture != WeaponCatalog.texture(kind):
			_fail("Weapon art was not held for %s" % kind)
			return
		var before: int = arena.projectiles.get_child_count()
		slug.shoot()
		if arena.projectiles.get_child_count() - before != int(WeaponCatalog.data(kind).pellets):
			_fail("Wrong projectile count for %s" % kind)
			return
		if kind == "shotgun":
			if slug.weapon_sprite.texture != WeaponCatalog.texture(kind, 1):
				_fail("Shotgun did not show its reload frame")
				return
			var trajectories: Dictionary = {}
			for projectile in arena.projectiles.get_children():
				trajectories[projectile.vertical_speed] = true
			if trajectories.size() != int(WeaponCatalog.data(kind).pellets):
				_fail("Shotgun pellets did not spread")
				return
		for projectile in arena.projectiles.get_children():
			projectile.free()
		slug._discard_weapon()
	var victim = load("res://Game/Slug/slug.tscn").instantiate()
	victim.name = "3"
	victim.player_peer_id = 3
	victim.position = Vector2(575, 405)
	arena.players.add_child(victim)
	slug.position = Vector2(520, 405)
	slug.equip_weapon("rpg")
	slug.shoot()
	if not await _wait_until(func(): return victim.life_state == victim.DEAD):
		_fail("RPG blast did not hit and kill a nearby slug")
		return
	if slug.life_state != slug.SHELL or arena.get_node("Explosions").get_child_count() == 0:
		_fail("RPG failed to show an explosion or protected its shooter incorrectly")
		return
	for projectile in arena.projectiles.get_children():
		projectile.free()
	victim._respawn()
	victim.position = Vector2(575, 405)
	slug._discard_weapon()
	slug.equip_weapon("shotgun")
	slug.shoot()
	if not await _wait_until(func(): return victim.life_state == victim.NAKED):
		_fail("Shotgun pellets did not strip the shell")
		return
	await create_timer(0.1).timeout
	if victim.life_state != victim.NAKED:
		_fail("One shotgun blast dealt more than one hit")
		return
	if victim.hit_invulnerability_remaining <= 0.0:
		_fail("Shotgun hit did not grant temporary protection")
		return
	if not await _wait_until(func(): return victim.hit_invulnerability_remaining <= 0.0):
		_fail("Hit protection did not expire")
		return
	victim.take_hit(1.0, slug.player_peer_id)
	if victim.life_state != victim.DEAD:
		_fail("Slug remained protected after the quarter second")
		return
	print("WEAPON_SMOKE_PASS")
	quit(0)


func _wait_until(condition: Callable, timeout: float = 3.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
