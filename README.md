# Slug Game

A Godot 4.6 2D platformer with ENet multiplayer, supporting three players by default.

## Play together

1. Open `slug-game/project.godot` and run the main scene.
2. In the first instance, click **Host** to spawn P1.
3. Run a second instance, enter `127.0.0.1`, and click **Join** to spawn P2.
   On another computer on the same network, enter the host's LAN IP instead.
4. A third instance can join the same host to spawn P3. Further attempts display
   **Room full** until someone leaves.

Each instance controls its own slug with **Left/Right** to move, **Up** to jump,
and **Space** to shoot. These use the existing `p1 left`, `p1 right`, `p1 jump`,
and `p1 act` Input Map actions. Each player has a distinct tint and number, and
your slug is labeled `(you)`.
The first projectile hit shoots the shell off as a spinning, bouncing piece.
The slug then uses its naked animations. A second hit kills it, plays
the death animation for the shot's direction, and throws its severed head.
Each hit produces a short red blood burst; the lethal hit makes a larger burst.
Dead slugs cannot be controlled or shoot and respawn with their shell after three seconds.
Slugs also respawn if they fall out of the arena.

The shared camera follows every player on each instance, with room for sprites,
labels, and the connection panel. It zooms out immediately when players spread
apart and eases back in as they regroup. Padding, maximum zoom, follow speed,
and HUD clearance are configurable on the Arena's `PlayerCamera` node.

The game accepts one host and two clients on **UDP port 7000** by default. Change
**Max Players** or **Port** on the Arena node in the Inspector to configure the room,
including the host (1–4095). Player slots, labels, colors, and spawn points adapt
to the configured capacity. The host reserves seats during the join handshake,
so simultaneous join attempts cannot overfill the room.

If connecting across the Internet, the host needs a reachable address and UDP port forwarding;
there is no matchmaking or relay service. See [Godot's ENet documentation](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html).

**Disconnect** returns to the connection panel. If a client leaves, its slot opens
for a replacement player. If the host leaves, clients can host or join a new game.

## Networking

The host simulates all slugs and projectile collisions. Clients send control
changes to the host, which checks the sending peer against the slug's assigned
player. `MultiplayerSpawner` replicates players, projectiles, severed heads,
shot-off shells, and blood bursts,
including late joins and removals. `MultiplayerSynchronizer` replicates position,
velocity, facing, and hit state. The host decides hits and respawns. Projectiles
disappear on impact or after two seconds; severed heads disappear after four.

Client movement currently waits for the host's response, so this setup is best
suited to local testing and LAN play. There is no client prediction yet.

## Verify multiplayer

The camera's headless framing check covers joins, departures, teleports, and
different viewport shapes:

```sh
/path/to/godot --headless --path slug-game --script res://tests/camera_smoke.gd
```

With Python 3 and a Godot 4.6 executable available, run from this repository:

```sh
python3 slug-game/tests/run_multiplayer_smoke.py --godot /path/to/godot
```

The test first launches two real headless instances and checks player spawning,
replicated movement and jumping, shooting in both directions across the network,
rejection of another player's controls, projectile cleanup, disconnect/rejoin,
host loss, switching from client to host, and standalone prefab shooting.
It then launches four instances to check a three-player room, distinct player
numbers/colors/spawn points, explicit rejection of the fourth player, occupancy
updates, and successful retry using a vacated slot.
The final two-instance check covers both directional deaths, blood and head
replication, shot-off shells, and respawning. Separate local checks cover blood
bursts and shell flight, animation, and cleanup. Network tests use a free UDP port, so they can run while
the game is open.
