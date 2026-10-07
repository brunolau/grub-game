class_name HeroMount
extends RefCounted
## Riding Chomper, the rex (docs/spec/PHYSICS.md C.9; DESIGN.md C.8): the driver's and the gunner's side of the
## mount - the driver's flags drive the mount, the gunner strikes from his seat, a hit on the ridden mount throws
## the riders off without costing a heart, dismount and the remount lock.
##
## Owner: player-B (docs/expansion/PLAN.md 4.1); the mount entity itself is objects-B's `objects/mount`, which seats
## heroes with PlayerBase.sit_on_mount() and places them every tick. A component of [Player], created with him; the
## calls below are the hooks of PLAN.md P0.8 and are made only while [member active] is true (a level with a
## mount). The bodies are minimal on purpose: phase 1 (PLAN.md P1.5) fills them in. No Book I level has a mount.
##
## Hook order inside Player._hero_update: after the input is read (8b), after the party component and before the
## belt, [method update] may run the hero's whole PLAYER phase itself while he is seated (returns true).
## Player.hurt asks [method on_hurt] before the 1.0 hurt: a seated rider's hit is the mount's (C.9).

## The hero this component belongs to.
var hero: Player = null
## True while the hooks run. Default false.
var active: bool = false


func _init(p_hero: Player) -> void:
	hero = p_hero


## The hero entered a level (Player._ready): switch on when it holds a mount. Minimal body: stays off.
func setup(_level: LevelBase) -> void:
	pass


## PLAYER phase, after 8b: while seated (hero.is_mounted()) the driver's or gunner's update. True = it ran the rest
## of the hero's PLAYER phase this tick.
func update(_level: LevelBase) -> bool:
	return false


## Step 8i: the remount lock.
func tick_timers() -> void:
	pass


## The hero was hurt (after the immunity checks of Player.hurt). True = the mount took the hit (C.9: the riders are
## thrown off, stunned, no heart lost) and Player.hurt returns true without the 1.0 hurt.
func on_hurt(_source: SimEntity, _kind: int) -> bool:
	return false


## The hero respawned (PlayerBase.respawn_at already left the seat).
func on_respawn() -> void:
	pass
