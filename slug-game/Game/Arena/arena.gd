extends Node2D

const PORT: int = 7000
const SLUG_SCENE: PackedScene = preload("res://Game/Slug/slug.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://Game/Projectile/projectile.tscn")
const SPAWN_POINTS: Array[Vector2] = [Vector2(490, 330), Vector2(660, 330)]

var next_projectile_id: int = 0

@onready var players: Node2D = $Players
@onready var projectiles: Node2D = $Projectiles
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner
@onready var status: Label = %Status


func _ready() -> void:
	player_spawner.spawn_function = _create_player
	projectile_spawner.spawn_function = _create_projectile
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	%HostButton.pressed.connect(host_game)
	%JoinButton.pressed.connect(func(): join_game(%Address.text))
	%LeaveButton.pressed.connect(func(): leave_game())
	_set_session_active(false)


func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, 1)
	if error != OK:
		status.text = "Could not host on port %d: %s" % [PORT, error_string(error)]
		return
	multiplayer.multiplayer_peer = peer
	_set_session_active(true)
	player_spawner.spawn({"peer_id": 1, "slot": 0})
	status.text = "Hosting on port %d. Waiting for player 2..." % PORT


func join_game(address: String) -> void:
	address = address.strip_edges()
	if address.is_empty():
		status.text = "Enter the host's IP address first."
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		status.text = "Could not join: %s" % error_string(error)
		return
	multiplayer.multiplayer_peer = peer
	_set_session_active(true)
	status.text = "Connecting to %s..." % address


func leave_game(message: String = "Disconnected. Host or join another game.") -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for player in players.get_children():
		player.free()
	for projectile in projectiles.get_children():
		projectile.free()
	_set_session_active(false)
	status.text = message


func _set_session_active(active: bool) -> void:
	%HostButton.disabled = active
	%JoinButton.disabled = active
	%Address.editable = not active
	%Address.release_focus()
	%LeaveButton.disabled = not active


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		player_spawner.spawn({"peer_id": peer_id, "slot": 1})
		status.text = "Two players connected. You are P1."


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
	for projectile in projectiles.get_children():
		if projectile.shooter_peer_id == peer_id:
			projectile.queue_free()
	status.text = "Player 2 left. Waiting for another player..."


func _on_connected_to_server() -> void:
	status.text = "Connected. You are P2."


func _on_connection_failed() -> void:
	leave_game("Connection failed. Check the IP, host, and UDP port %d." % PORT)


func _on_server_disconnected() -> void:
	leave_game("The host disconnected. You can host or join again.")


func _create_player(data: Dictionary) -> Node:
	var player = SLUG_SCENE.instantiate()
	player.name = str(data.peer_id)
	player.player_peer_id = data.peer_id
	player.player_number = int(data.slot) + 1
	player.spawn_point = SPAWN_POINTS[int(data.slot)]
	player.position = player.spawn_point
	return player


func spawn_projectile(player: CharacterBody2D) -> void:
	if not multiplayer.is_server():
		return
	next_projectile_id += 1
	projectile_spawner.spawn({
		"id": next_projectile_id,
		"position": player.global_position,
		"direction": player.facing_direction,
		"shooter_peer_id": player.player_peer_id,
		"muzzle_offset": player.muzzle_offset,
	})


func _create_projectile(data: Dictionary) -> Node:
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.name = "Shot_%d" % int(data.id)
	projectile.position = data.position
	projectile.direction = data.direction
	projectile.shooter_peer_id = data.shooter_peer_id
	projectile.launch_offset = Vector2(
		data.muzzle_offset.x * data.direction, data.muzzle_offset.y
	)
	return projectile
