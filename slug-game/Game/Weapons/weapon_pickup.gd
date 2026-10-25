extends Area2D

var weapon_type: String = "gun"
var spawn_slot: int = -1


func _ready() -> void:
	$Sprite2D.texture = WeaponCatalog.texture(weapon_type)
	$Label.text = WeaponCatalog.data(weapon_type).name
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	$Sprite2D.position.y = -3.0 + sin(Time.get_ticks_msec() * 0.006) * 2.0


func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	var arena := get_parent().get_parent()
	if arena.has_method("claim_weapon"):
		arena.claim_weapon(self, body)
