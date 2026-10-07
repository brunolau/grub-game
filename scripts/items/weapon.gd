class_name WeaponPickup
extends CollectibleBase
## `items/weapon`: switches the hero's weapon. `kind=club|hammer|axe|boomerang|spear` [club]. The weapon is kept
## through deaths and levels; the pick-up reappears when the hero respawns (GAMEPLAY.md 8.1).
##
## 2.0 (DESIGN.md C.1, PHYSICS.md C.2 rule 1): the hero's belt decides the rule (HeroBelt.give_weapon, player-B): with
## the belt off (Book I solo, `belt = carry`) the 1.0 rule - one weapon, replaced on pick-up; with the belt on (Book II,
## co-op, arenas) a special goes into the hand and the club onto the belt (a special owned before is gone), the club
## picked up while a special is in the hand exchanges hand and belt, and with the club in the hand it is taken and
## nothing changes. The spear (`kind=spear`, Defs.Weapon.SPEAR) is weapon 4. `temp` (versus crates and spears lying
## on the ground, PHYSICS.md C.14): a temporary special that goes onto the belt (rule 6); how long it lasts is the
## referee's and the belt's.
##
## The class is not called `Weapon`: that is the name of the weapon enum in Defs.

## Level-file names in the order of Defs.Weapon.
const KINDS: Array[String] = ["club", "hammer", "axe", "boomerang", "spear"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/items/weapon_club.png"),
	preload("res://assets/sprites/items/weapon_hammer.png"),
	preload("res://assets/sprites/items/weapon_axe.png"),
	preload("res://assets/sprites/items/weapon_boomerang.png"),
	preload("res://assets/sprites/items/weapon_spear.png"),
]
## The planted spear is taller than the other pick-ups (32 x 72 art px, pivot (16, 72); ASSET_MANIFEST).
const SPEAR_OFFSET: Vector2 = Vector2(-16, -72)

## The weapon this pick-up gives (Defs.Weapon).
var weapon: int = Defs.Weapon.CLUB
## 2.0 versus: a temporary special for the belt (`temp`).
var temp: bool = false


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
	temp = param_bool("temp")
	super._apply_params(params)
	index = weapon


func _apply(hero: PlayerBase) -> bool:
	# The collector's own weapon (2.0: his PlayerRun; P1's run is Game's, so Game.set_weapon() in 1.0 - which
	# HeroBelt.give_weapon does while his belt is off).
	HeroBelt.give_weapon(hero, weapon, temp)
	return true


func _update_look() -> void:
	var sprite: Sprite2D = get_sprite()
	if sprite != null:
		sprite.texture = TEXTURES[weapon]
		if weapon == Defs.Weapon.SPEAR:
			sprite.offset = SPEAR_OFFSET
