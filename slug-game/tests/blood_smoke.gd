extends SceneTree
## Tests both burst sizes and automatic cleanup without opening a socket.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena = load("res://Game/Arena/arena.tscn").instantiate()
	root.add_child(arena)
	var player := CharacterBody2D.new()
	root.add_child(player)
	player.global_position = Vector2(100, 100)
	arena.spawn_blood(player, -1.0, false)
	arena.spawn_blood(player, 1.0, true)
	var small: CPUParticles2D = arena.get_node("BloodBursts/Blood_1")
	var large: CPUParticles2D = arena.get_node("BloodBursts/Blood_2")
	if small.amount != 8 or large.amount != 18:
		_fail("Death burst should contain more droplets than the first hit")
		return
	if not small.emitting or not large.emitting or small.direction.x >= 0 or large.direction.x <= 0:
		_fail("Bursts did not emit in their shot directions")
		return
	if small.texture == null or small.color_ramp == null:
		_fail("Blood particles are missing their texture or red fade")
		return
	await create_timer(1.0).timeout
	if arena.get_node("BloodBursts").get_child_count() != 0:
		_fail("Finished blood bursts were not removed")
		return
	print("BLOOD_SMOKE_PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
