class_name WeaponCatalog
extends RefCounted

const WEAPONS: Dictionary = {
	"gun": {"name": "Pistol", "ammo": 12, "cooldown": 0.26, "speed": 650.0, "damage": 1, "pellets": 1, "spread": 0.0, "radius": 3.0, "blast": 0.0, "height": -7.0},
	"cowboy": {"name": "Revolver", "ammo": 6, "cooldown": 0.42, "speed": 800.0, "damage": 1, "pellets": 1, "spread": 0.0, "radius": 3.0, "blast": 0.0, "height": -7.0},
	"shotgun": {"name": "Shotgun", "ammo": 6, "cooldown": 0.8, "speed": 550.0, "damage": 1, "pellets": 5, "spread": 105.0, "radius": 2.0, "blast": 0.0, "height": -6.0},
	"sniper": {"name": "Sniper", "ammo": 4, "cooldown": 1.1, "speed": 1300.0, "damage": 2, "pellets": 1, "spread": 0.0, "radius": 2.0, "blast": 0.0, "height": -9.0},
	"minigun": {"name": "Minigun", "ammo": 36, "cooldown": 0.09, "speed": 750.0, "damage": 1, "pellets": 1, "spread": 0.0, "radius": 2.0, "blast": 0.0, "height": -7.0},
	"rpg": {"name": "RPG", "ammo": 3, "cooldown": 1.2, "speed": 360.0, "damage": 2, "pellets": 1, "spread": 0.0, "radius": 6.0, "blast": 58.0, "height": -10.0},
	"paper_weight": {"name": "Paperweight", "ammo": 8, "cooldown": 0.55, "speed": 470.0, "damage": 1, "pellets": 1, "spread": 0.0, "radius": 5.0, "blast": 0.0, "height": -6.0},
}

const TEXTURES: Dictionary = {
	"gun": preload("res://Game/Weapons/gun.png"),
	"cowboy": preload("res://Game/Weapons/cowboy.png"),
	"shotgun": preload("res://Game/Weapons/shotgun.png"),
	"sniper": preload("res://Game/Weapons/sniper.png"),
	"minigun": preload("res://Game/Weapons/minigun1.png"),
	"rpg": preload("res://Game/Weapons/rpg.png"),
	"paper_weight": preload("res://Game/Weapons/paper_weight.png"),
}

const MINIGUN_FRAME_2: Texture2D = preload("res://Game/Weapons/minigun2.png")
const SHOTGUN_RELOAD_1: Texture2D = preload("res://Game/Weapons/shotgun_reload1.png")
const SHOTGUN_RELOAD_2: Texture2D = preload("res://Game/Weapons/shotgun_reload2.png")


static func ids() -> Array:
	return WEAPONS.keys()


static func data(kind: String) -> Dictionary:
	return WEAPONS.get(kind, {})


static func texture(kind: String, frame: int = 0) -> Texture2D:
	if kind == "minigun" and frame % 2 == 1:
		return MINIGUN_FRAME_2
	if kind == "shotgun" and frame == 1:
		return SHOTGUN_RELOAD_1
	if kind == "shotgun" and frame == 2:
		return SHOTGUN_RELOAD_2
	return TEXTURES.get(kind)


static func muzzle_offset(kind: String) -> Vector2:
	var stats := data(kind)
	var image := texture(kind)
	return Vector2(10.0 + image.get_width() * 0.5, stats.height)
