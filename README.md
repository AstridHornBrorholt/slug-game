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
Slugs respawn if they fall out of the arena.

The game accepts one host and two clients on **UDP port 7000** by default. Change
**Max Players** on the Arena node in the Inspector to configure a different total,
including the host (1–4095). Player slots, labels, colors, and spawn points adapt
to the configured capacity. The host reserves seats during the join handshake,
so simultaneous join attempts cannot overfill the room.

If connecting
across the Internet, the host needs a reachable address and UDP port forwarding;
there is no matchmaking or relay service. See [Godot's ENet documentation](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html).

**Disconnect** returns to the connection panel. If a client leaves, its slot opens
for a replacement player. If the host leaves, clients can host or join a new game.

## Networking

The host simulates all slugs and projectile collisions. Clients send control
changes to the host, which checks the sending peer against the slug's assigned
player. `MultiplayerSpawner` replicates players and projectiles, including late
joins and removals. `MultiplayerSynchronizer` replicates position, velocity, and
facing. Projectiles disappear on impact or after two seconds; no damage or health
system is implemented yet.

Client movement currently waits for the host's response, so this setup is best
suited to local testing and LAN play. There is no client prediction yet.

## Verify multiplayer

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
Port 7000 must be available.
