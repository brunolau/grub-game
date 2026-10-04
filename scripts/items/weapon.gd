class_name WeaponPickup
extends CollectibleBase
## `items/weapon`: switches the hero's weapon. `kind=club|hammer|axe|boomerang` [club]. The weapon is kept through
## deaths and levels; the pick-up reappears when the hero respawns (GAMEPLAY.md 8.1).
##
## The class is not called `Weapon`: that is the name of the weapon enum in Defs.

## Level-file names in the order of Defs.Weapon.
const KINDS: Array[String] = ["club", "hammer", "axe", "boomerang"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/items/weapon_club.png"),
	preload("res://assets/sprites/items/weapon_hammer.png"),
	preload("res://assets/sprites/items/weapon_axe.png"),
	preload("res://assets/sprites/items/weapon_boomerang.png"),
]

## The weapon this pick-up gives (Defs.Weapon).
var weapon: int = Defs.Weapon.CLUB


func _init() -> void:
	super()
	item_id = &"items/weapon"
	expires = false
	reappears_on_respawn = true
	set_box(Vector3i(16, 20, 8))


func _apply_params(params: Dictionary) -> void:
	var kind: String = str(params.get("kind", KINDS[Defs.Weapon.CLUB]))
	weapon = KINDS.find(kind)
	if weapon < 0:
		push_warning("items/weapon: unknown kind '%s', using the club" % kind)
		weapon = Defs.Weapon.CLUB
	super._apply_params(params)
	index = weapon


func _apply(_hero: PlayerBase) -> bool:
	Game.set_weapon(weapon)
	return true


func _update_look() -> void:
	var sprite: Sprite2D = get_sprite()
	if sprite != null:
		sprite.texture = TEXTURES[weapon]
