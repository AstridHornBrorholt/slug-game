# Slug Game

A Godot 4.6 2D platformer with ENet multiplayer, supporting three players by default.

## Play together

1. Open `slug-game/project.godot` and run the main scene.
2. In the title menu, choose **Brickworks** or **Cement Yard**, then click **Host** to spawn P1.
3. Run a second instance, enter `127.0.0.1`, and click **Join** to spawn P2.
   On another computer on the same network, enter the host's LAN IP instead.
4. A third instance can join the same host to spawn P3. Further attempts display
   **Room full** until someone leaves.

The host's arena choice is sent to joining players. Arena scenes live in
`slug-game/Game/Levels`; the title menu lists every TileMapLayer scene there
using its filename as the display name. To add a level, duplicate a scene in
that folder, rename the file, and paint its tiles in Godot. Press **Esc** or click
**Menu** during a match to see the controls, resume, or leave. This menu stops
your local slug's controls while the multiplayer match continues.

Each instance controls its own slug with **Left/Right** to move, **Up** to jump,
and **Space** to fire a held gun. Walk over a weapon on the arena to pick it up.
These use the existing `p1 left`, `p1 right`, `p1 jump`,
and `p1 act` Input Map actions. Each player has a distinct tint and number, and
your slug is labeled `(you)`.
Guns show their remaining ammo above the slug. When the magazine is empty, the
gun is thrown aside and cannot be picked up again. The three `WeaponSpawnPoints`
markers in the Arena set where pickups appear. A new random gun appears at the
same marker seven seconds after one is claimed; **Weapon Respawn Delay** is
editable in the Arena inspector. Death also drops the held gun.

Pistol, revolver, paperweight, shotgun, sniper, minigun, and RPG use the images
in `Game/Weapons`. Shotgun shells scatter five pellets, the minigun fires quickly,
sniper rounds hit harder, and RPG shots explode with splash damage. The numbered
minigun and shotgun sprites animate while firing or reloading.
Their ammo, rate of fire, and projectile settings are in
`Game/Weapons/weapon_catalog.gd`.

The first ordinary projectile hit shoots the shell off as a spinning, bouncing piece.
The slug then uses its naked animations. Another hit kills it, plays
the death animation for the shot's direction, and throws its severed head.
Heavy shots can kill immediately; a quarter second of protection after each hit
keeps a shotgun blast from dealing more than one hit.
Each hit produces a short red blood burst; the lethal hit makes a larger burst.
Each slug starts with three lives. Death or falling out costs one life; slugs
respawn with their shell after three seconds while lives remain. The last slug
standing wins, and the host can choose **Play again** to restore all lives.

The shared camera follows every player on each instance, with room for sprites,
labels, and the connection panel. It zooms out immediately when players spread
apart and eases back in as they regroup. Padding, maximum zoom, follow speed,
and HUD clearance are configurable on the Arena's `PlayerCamera` node.

The levels use the TileSet in `Game/Environment/Environment`. It contains all 23
terrain sheets in that folder as 16×16 atlas tiles. Solid terrain tiles have
collision shapes, so painting or erasing them changes both the visible map and
the playable ground.
The fence tiles remain decorative.

The game accepts one host and two clients on **UDP port 7000** by default. Change
**Max Players** or **Port** on the Arena node in the Inspector to configure the room,
including the host (1–4095). Player slots, labels, colors, and spawn points adapt
to the configured capacity. The host reserves seats during the join handshake,
so simultaneous join attempts cannot overfill the room.

If connecting across the Internet, the host needs a reachable address and UDP port forwarding;
there is no matchmaking or relay service. See [Godot's ENet documentation](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html).

**Leave match** returns to the title menu. If a client leaves, its slot opens
for a replacement player. If the host leaves, clients can host or join a new game.

## Networking

The host simulates all slugs and projectile collisions. Clients send control
changes to the host, which checks the sending peer against the slug's assigned
player. `MultiplayerSpawner` replicates players, weapon pickups, dropped guns,
projectiles, explosions, severed heads, shot-off shells, and blood bursts,
including late joins and removals. `MultiplayerSynchronizer` replicates position,
velocity, facing, held weapon, ammo, and hit state. The host decides pickups,
shots, hits, and respawns. Projectiles
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
bursts, shell flight, pickup timing, ammo, empty gun discards, firing patterns,
and RPG splash. Network tests use a free UDP port, so they can run while
the game is open.
