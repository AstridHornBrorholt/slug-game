# Slug Game

A Godot 4.6 2D platformer with two-player ENet multiplayer.

## Play together

1. Open `slug-game/project.godot` and run the main scene.
2. In the first instance, click **Host** to spawn P1.
3. Run a second instance, enter `127.0.0.1`, and click **Join** to spawn P2.
   On another computer on the same network, enter the host's LAN IP instead.

Each instance controls its own slug with **Left/Right** to move, **Up** to jump,
and **Space** to shoot. These use the existing `p1 left`, `p1 right`, `p1 jump`,
and `p1 act` Input Map actions. P2 is tinted blue, and your slug is labeled `(you)`.
Slugs respawn if they fall out of the arena.

The game accepts one host and one client on **UDP port 7000**. If connecting
across the Internet, the host needs a reachable address and UDP port forwarding;
there is no matchmaking or relay service. See [Godot's ENet documentation](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html).

**Disconnect** returns to the connection panel. If P2 leaves, the host stays open
for a replacement player. If the host leaves, P2 can host or join a new game.

## Networking

The host simulates both slugs and all projectile collisions. Clients send control
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

The test launches two real headless instances and checks player spawning,
replicated movement and jumping, shooting in both directions across the network,
rejection of another player's controls, projectile cleanup, disconnect/rejoin,
host loss, switching from client to host, and standalone prefab shooting.
Port 7000 must be available.
