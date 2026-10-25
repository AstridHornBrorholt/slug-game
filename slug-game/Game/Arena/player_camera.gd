extends Camera2D
## Frames every replicated player independently on each peer.

@export var players_path: NodePath = ^"../Players"
## World-space breathing room, including sprites and player labels.
@export var padding: Vector2 = Vector2(80.0, 80.0)
@export_range(0.1, 4.0) var maximum_zoom: float = 1.5
@export_range(0.1, 20.0) var follow_speed: float = 5.0
## Screen-space area reserved for the connection panel.
@export var hud_height: float = 200.0

var had_players: bool = false


func _ready() -> void:
	# Read positions after the slugs have updated on this peer.
	process_priority = 100
	position_smoothing_enabled = false


func _process(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var players := get_node_or_null(players_path)
	var targets: Array[Node2D] = []
	if players != null:
		for child in players.get_children():
			if child is Node2D and not child.is_queued_for_deletion():
				targets.append(child)
	if targets.is_empty():
		global_position = viewport_size * 0.5
		zoom = Vector2.ONE
		had_players = false
		return

	var bounds := Rect2(targets[0].global_position, Vector2.ZERO)
	for target in targets:
		bounds = bounds.expand(target.global_position)
	bounds = bounds.grow_individual(padding.x, padding.y, padding.x, padding.y)
	var top := clampf(hud_height, 0.0, viewport_size.y * 0.45)
	var usable_size := viewport_size - Vector2(0.0, top)
	var fit_zoom := minf(maximum_zoom, minf(
		usable_size.x / maxf(bounds.size.x, 1.0),
		usable_size.y / maxf(bounds.size.y, 1.0)
	))
	var weight := 1.0 - exp(-follow_speed * delta)
	# Never delay zooming out: a join, teleport, or respawn must fit immediately.
	var next_zoom := minf(fit_zoom, lerpf(zoom.x, fit_zoom, weight)) if had_players else fit_zoom
	zoom = Vector2.ONE * next_zoom
	var desired_center := bounds.get_center() - Vector2(0.0, top * 0.5 / next_zoom)
	var center := global_position.lerp(desired_center, weight) if had_players else desired_center
	# Constrain smoothing to centers that still contain the entire padded roster.
	var half_view := viewport_size * 0.5 / next_zoom
	center.x = clampf(center.x, bounds.end.x - half_view.x, bounds.position.x + half_view.x)
	center.y = clampf(center.y, bounds.end.y - half_view.y,
		bounds.position.y + half_view.y - top / next_zoom)
	global_position = center
	had_players = true
