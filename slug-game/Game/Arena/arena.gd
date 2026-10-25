extends Node2D

const SLUG_SCENE: PackedScene = preload("res://Game/Slug/slug.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://Game/Projectile/projectile.tscn")
const HEAD_SCENE: PackedScene = preload("res://Game/SeveredHead/severed_head.tscn")
const BLOOD_SCENE: PackedScene = preload("res://Game/BloodParticles/blood_burst.tscn")
const SHOT_OFF_SHELL_SCENE: PackedScene = preload("res://Game/ShotOffShell/shot_off_shell.tscn")

@export_range(1, 4095) var max_players: int = 3
@export_range(1024, 65535) var port: int = 7000

var next_projectile_id: int = 0
var next_head_id: int = 0
var next_blood_id: int = 0
var next_shell_id: int = 0
var peer_slots: Dictionary = {}
var room_capacity: int = 3
var local_player_number: int = 1
var session_joined: bool = false
var rejection_message: String = ""

@onready var players: Node2D = $Players
@onready var projectiles: Node2D = $Projectiles
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner
@onready var head_spawner: MultiplayerSpawner = $HeadSpawner
@onready var blood_spawner: MultiplayerSpawner = $BloodSpawner
@onready var shell_spawner: MultiplayerSpawner = $ShellSpawner
@onready var status: Label = %Status


func _ready() -> void:
	player_spawner.spawn_function = _create_player
	projectile_spawner.spawn_function = _create_projectile
	head_spawner.spawn_function = _create_head
	blood_spawner.spawn_function = _create_blood
	shell_spawner.spawn_function = _create_shell
	# Admission happens before replication, so rejected peers never enter the game.
	multiplayer.auth_callback = _on_auth_data
	multiplayer.peer_authenticating.connect(_on_peer_authenticating)
	multiplayer.peer_authentication_failed.connect(_on_authentication_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	%HostButton.pressed.connect(host_game)
	%JoinButton.pressed.connect(func(): join_game(%Address.text))
	%LeaveButton.pressed.connect(func(): leave_game())
	players.child_order_changed.connect(_update_status)
	_set_session_active(false)
	status.text = "Host a game, or enter an IP and join. %d players maximum." % max_players


func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	# Keep transport space available to send a rejection even when the room is full.
	var error := peer.create_server(port, 4095)
	if error != OK:
		status.text = "Could not host on port %d: %s" % [port, error_string(error)]
		return
	multiplayer.multiplayer_peer = peer
	room_capacity = clampi(max_players, 1, 4095)
	local_player_number = 1
	peer_slots = {1: 0}
	session_joined = true
	rejection_message = ""
	_set_session_active(true)
	player_spawner.spawn({"peer_id": 1, "slot": 0, "capacity": room_capacity})
	_update_status()


func join_game(address: String) -> void:
	address = address.strip_edges()
	if address.is_empty():
		status.text = "Enter the host's IP address first."
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		status.text = "Could not join: %s" % error_string(error)
		return
	multiplayer.multiplayer_peer = peer
	rejection_message = ""
	_set_session_active(true)
	status.text = "Connecting to %s..." % address


func leave_game(message: String = "Disconnected. Host or join another game.") -> void:
	session_joined = false
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer_slots.clear()
	for player in players.get_children():
		player.free()
	for projectile in projectiles.get_children():
		projectile.free()
	for head in $SeveredHeads.get_children():
		head.free()
	for blood in $BloodBursts.get_children():
		blood.free()
	for shell in $ShotOffShells.get_children():
		shell.free()
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
		player_spawner.spawn({
			"peer_id": peer_id, "slot": peer_slots[peer_id], "capacity": room_capacity,
		})
		_update_status()


func _on_peer_authenticating(peer_id: int) -> void:
	if not multiplayer.is_server() and peer_id == 1:
		multiplayer.send_auth(1, "join".to_utf8_buffer())


func _on_auth_data(peer_id: int, data: PackedByteArray) -> void:
	var message := data.get_string_from_utf8()
	if multiplayer.is_server():
		if message != "join" or peer_slots.has(peer_id):
			return
		var slot := -1
		for candidate in range(room_capacity):
			if not peer_slots.values().has(candidate):
				slot = candidate
				break
		if slot == -1:
			multiplayer.send_auth(peer_id, ("full:%d" % room_capacity).to_utf8_buffer())
			return
		# Reserve immediately, including peers still completing the handshake.
		peer_slots[peer_id] = slot
		multiplayer.send_auth(peer_id, ("accepted:%d:%d" % [slot + 1, room_capacity]).to_utf8_buffer())
		multiplayer.complete_auth(peer_id)
	elif peer_id == 1:
		var parts := message.split(":")
		if parts.size() == 2 and parts[0] == "full":
			rejection_message = "Room full (%s players maximum). Try again when someone leaves." % parts[1]
			leave_game.call_deferred(rejection_message)
		elif parts.size() == 3 and parts[0] == "accepted":
			local_player_number = int(parts[1])
			room_capacity = int(parts[2])
			multiplayer.complete_auth(1)


func _on_authentication_failed(peer_id: int) -> void:
	if multiplayer.is_server():
		peer_slots.erase(peer_id)
	elif peer_id == 1:
		_on_connection_failed()


func _update_status() -> void:
	if session_joined:
		status.text = "%s | %d/%d players | You are P%d" % [
			"Hosting on port %d" % port if multiplayer.is_server() else "Connected",
			players.get_child_count(), room_capacity, local_player_number,
		]


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	peer_slots.erase(peer_id)
	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
	for projectile in projectiles.get_children():
		if projectile.shooter_peer_id == peer_id:
			projectile.queue_free()
	_update_status.call_deferred()


func _on_connected_to_server() -> void:
	session_joined = true
	_update_status()


func _on_connection_failed() -> void:
	leave_game(rejection_message if not rejection_message.is_empty() else
		"Connection failed. Check the IP, host, and UDP port %d." % port)


func _on_server_disconnected() -> void:
	leave_game(rejection_message if not rejection_message.is_empty() else
		"The host disconnected. You can host or join again.")


func _create_player(data: Dictionary) -> Node:
	var player = SLUG_SCENE.instantiate()
	player.name = str(data.peer_id)
	player.player_peer_id = data.peer_id
	player.player_number = int(data.slot) + 1
	var columns := mini(int(data.capacity), 8)
	var slot := int(data.slot)
	player.spawn_point = Vector2(
		490.0 + 170.0 * float(slot % columns) / maxi(columns - 1, 1),
		330.0 - 48.0 * floori(float(slot) / columns)
	)
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


func spawn_severed_head(player: CharacterBody2D, shot_direction: float) -> void:
	if not multiplayer.is_server():
		return
	next_head_id += 1
	head_spawner.spawn({
		"id": next_head_id,
		"position": player.global_position + Vector2(7.0 * player.facing_direction, -9.0),
		"velocity": Vector2(shot_direction * 170.0, -230.0),
		"spin_speed": shot_direction * 8.0,
		"color": player.sprite.modulate,
	})


func _create_head(data: Dictionary) -> Node:
	var head = HEAD_SCENE.instantiate()
	head.name = "Head_%d" % int(data.id)
	head.position = data.position
	head.launch_velocity = data.velocity
	head.spin_speed = data.spin_speed
	head.get_node("Sprite2D").modulate = data.color
	return head


func spawn_blood(player: CharacterBody2D, shot_direction: float, fatal: bool) -> void:
	if not multiplayer.is_server():
		return
	next_blood_id += 1
	blood_spawner.spawn({
		"id": next_blood_id,
		"position": player.global_position + Vector2(-shot_direction * 5.0, -4.0),
		"direction": shot_direction,
		"fatal": fatal,
	})


func _create_blood(data: Dictionary) -> Node:
	var blood = BLOOD_SCENE.instantiate()
	blood.name = "Blood_%d" % int(data.id)
	blood.position = data.position
	blood.shot_direction = data.direction
	blood.fatal = data.fatal
	return blood


func spawn_shot_off_shell(player: CharacterBody2D, shot_direction: float) -> void:
	if not multiplayer.is_server():
		return
	next_shell_id += 1
	shell_spawner.spawn({
		"id": next_shell_id,
		"position": player.global_position + Vector2(-3.0 * player.facing_direction, -8.0),
		"velocity": Vector2(shot_direction * 150.0, -200.0),
		"spin_speed": shot_direction * 11.0,
		"color": player.sprite.modulate,
	})


func _create_shell(data: Dictionary) -> Node:
	var shell = SHOT_OFF_SHELL_SCENE.instantiate()
	shell.name = "Shell_%d" % int(data.id)
	shell.position = data.position
	shell.launch_velocity = data.velocity
	shell.spin_speed = data.spin_speed
	shell.get_node("Sprite2D").modulate = data.color
	return shell
