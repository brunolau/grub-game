class_name HazardBase
extends SimEntity
## A sprite hazard that hurts or kills on touch (falling ember, boulder, spring-loaded trap). Tile hazards
## (spikes, liquids) are NOT entities: they are deadly tiles handled by the hero's tile collision.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.15). Owner: objects (bodies may be replaced; public signatures frozen).

## True = instant death (PHYSICS.md 10.3); false = damage of `hurt_kind`.
var deadly: bool = false
## Defs.HurtKind used when not deadly.
var hurt_kind: int = Defs.HurtKind.ENEMY
## Cause reported with an instant death.
var death_cause: StringName = &"hazard"
## False = currently harmless (retracted, cooling down).
var armed: bool = true


func get_kind() -> int:
	return Defs.Kind.HAZARD


func _init() -> void:
	z_index = Defs.Z_OBJECTS


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.ITEMS, Defs.Phase.CONTACT_ITEMS])


func _sim_tick(phase: int) -> void:
	if phase == Defs.Phase.ITEMS:
		_move_tick()
	elif phase == Defs.Phase.CONTACT_ITEMS and armed:
		var level: LevelBase = Game.level
		if level != null and level.player != null and not level.player.dead \
				and Overlap.body(self, level.player, level.player):
			touch(level.player)


## Movement / animation logic for one tick. Override.
func _move_tick() -> void:
	pass


## The hero touched the armed hazard.
func touch(hero: PlayerBase) -> void:
	if deadly:
		hero.kill(death_cause)
	else:
		hero.hurt(self, hurt_kind)
