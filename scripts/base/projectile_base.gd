class_name ProjectileBase
extends SimEntity
## A flying object with a constant vertical acceleration and no tile collision: the hero's thrown weapons
## (PHYSICS.md 8.4) and boss projectiles (GAMEPLAY.md 6.3).
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.14). Owner: enemies (bodies may be replaced; public signatures frozen).
## Hero projectiles (`scenes/projectiles/hero_*.tscn`, owned by the player module) only move here; they are
## hit-tested by the hero's weapon pass and by bosses. Enemy projectiles test the hero themselves.

## True for the hero's thrown weapons, false for enemy / boss projectiles (level parameter `from_hero`).
var from_hero: bool = false
## Weapon power stored at spawn (already x4 when the throw was charged).
var power: int = 0
## Added to yvel every tick after moving (axe +32, boomerang -16).
var yacc: int = 0
## Ticks left before it disappears by itself (0 = no limit).
var life: int = 0
## How it damages the hero (Defs.HurtKind), enemy projectiles only.
var hurt_kind: int = Defs.HurtKind.BOSS_PROJECTILE
## True once it hit something or left the screen; it is freed at the end of the tick.
var spent: bool = false

var _age: int = 0


func get_kind() -> int:
	return Defs.Kind.HERO_PROJECTILE if from_hero else Defs.Kind.ENEMY_PROJECTILE


func _init() -> void:
	z_index = Defs.Z_PROJECTILES


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.PROJECTILES, Defs.Phase.CONTACT_ITEMS])


func _apply_params(params: Dictionary) -> void:
	from_hero = bool(params.get("from_hero", from_hero))
	power = int(params.get("power", power))
	xvel = int(params.get("xvel", xvel))
	yvel = int(params.get("yvel", yvel))
	yacc = int(params.get("yacc", yacc))
	life = int(params.get("life", life))


func _sim_tick(phase: int) -> void:
	if spent:
		return
	if phase == Defs.Phase.PROJECTILES:
		_move_tick()
	elif phase == Defs.Phase.CONTACT_ITEMS and not from_hero:
		_test_hero()


## Remove the projectile (it hit something). Safe to call during a tick.
func consume() -> void:
	if spent:
		return
	spent = true
	sim_active = false
	queue_free()


## One tick of flight: integrate, accelerate, expire. Removed when it was not drawn in the previous frame.
func _move_tick() -> void:
	sim_pos.x += Tuning.floor16(xvel)
	sim_pos.y += Tuning.floor16(yvel)
	yvel += yacc
	_age += 1
	if (life > 0 and _age >= life) or (_age > 1 and not on_screen):
		consume()


## Enemy projectile versus hero: a touch hurts him with `hurt_kind` and uses the projectile up. When the hurt is
## ignored (feast, death sequence, immunity against that kind) the projectile flies on.
func _test_hero() -> void:
	var level: LevelBase = Game.level
	if level == null or level.player == null or level.player.dead:
		return
	if Overlap.body(self, level.player, level.player) and level.player.hurt(self, hurt_kind):
		_on_hit_hero()
		consume()


## The projectile just hurt the hero (before it is consumed). Override for impact effects.
func _on_hit_hero() -> void:
	pass
