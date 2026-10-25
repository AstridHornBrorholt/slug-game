extends SceneTree
## Run with --headless --path slug-game --script res://tests/camera_smoke.gd.

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := load("res://Game/Arena/arena.tscn").instantiate() as Node2D
	root.add_child(arena)
	var camera := arena.get_node("PlayerCamera") as Camera2D
	camera.set_process(false)
	camera.call("_process", 0.016)
	_check(camera.zoom == Vector2.ONE, "Empty lobby should use the default zoom")
	var players := arena.get_node("Players")
	for point in [Vector2(490, 330), Vector2(660, 330), Vector2(-1500, -600), Vector2(2600, 900)]:
		var player := Node2D.new()
		players.add_child(player)
		player.global_position = point
		camera.call("_process", 0.016)
		_check_framing(camera, players)
	var far_player := players.get_child(3) as Node2D
	far_player.position = Vector2(-5000, 3000)
	camera.call("_process", 0.016)
	_check_framing(camera, players)
	for viewport_size in [Vector2i(640, 960), Vector2i(1920, 600), Vector2i(1152, 648)]:
		root.size = viewport_size
		camera.call("_process", 0.016)
		_check_framing(camera, players)
	far_player.free()
	camera.call("_process", 0.016)
	_check_framing(camera, players)
	# Regrouping should ease in, while continuing to contain all targets.
	var old_zoom := camera.zoom.x
	for player in players.get_children():
		player.position = Vector2(550, 330)
	camera.call("_process", 0.016)
	_check(camera.zoom.x > old_zoom and camera.zoom.x < camera.maximum_zoom,
		"Zooming in should be gradual")
	_check_framing(camera, players)
	for player in players.get_children():
		player.free()
	camera.call("_process", 0.016)
	_check(camera.zoom == Vector2.ONE, "Last departure should reset the camera")
	arena.free()
	if failures.is_empty():
		print("CAMERA_SMOKE_PASS")
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_framing(camera: Camera2D, players: Node) -> void:
	camera.force_update_scroll()
	var size := root.get_visible_rect().size
	var top := minf(camera.hud_height, size.y * 0.45)
	for player in players.get_children():
		for corner in [player.global_position - camera.padding, player.global_position + camera.padding]:
			var screen: Vector2 = root.canvas_transform * corner
			_check(screen.x >= -0.01 and screen.x <= size.x + 0.01
				and screen.y >= top - 0.01 and screen.y <= size.y + 0.01,
				"Padded player bounds must remain inside the view below the HUD")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
