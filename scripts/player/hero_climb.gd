class_name HeroClimb
extends RefCounted
## Vines and the CLIMB state (docs/spec/PHYSICS.md C.4; DESIGN.md C.3): grab, climb, top step, leap and drop.
##
## Owner: player-B (docs/expansion/PLAN.md 4.1). A component of [Player], created with him; the calls below are the
## hooks of PLAN.md P0.8 and are made only while [member active] is true (a level with `objects/vine`). The bodies
## are minimal on purpose: phase 1 (PLAN.md P1.5) fills them in. No Book I level has a vine, so a single-player hero
## of Book I never runs any of it.
##
## Hook order inside Player._hero_update: [method update] runs after the state table and its overrides (8c, the grab
## test of C.4) and before the handler (8d). Returning true means it ran the rest of the PLAYER phase itself (the
## CLIMB handler replaces handler, integration and the airborne step; it still calls `hero._tick_timers(level)` and
## `hero._update_box()`).

## The hero this component belongs to.
var hero: Player = null
## True while the hooks run. Default false.
var active: bool = false


func _init(p_hero: Player) -> void:
	hero = p_hero


## The hero entered a level (Player._ready): switch on when it holds vines. Minimal body: stays off.
func setup(_level: LevelBase) -> void:
	pass


## PLAYER phase, after 8c: the grab test and, while climbing, the CLIMB handler (C.4). True = it ran the rest of the
## hero's PLAYER phase this tick.
func update(_level: LevelBase) -> bool:
	return false


## Step 8i (run by the hero's timer step): the re-grab locks.
func tick_timers() -> void:
	pass


## The hero was hurt; a hurt ends CLIMB (the normal knock-back follows). True = the hit was taken here instead of the
## 1.0 hurt (never for a vine).
func on_hurt(_source: SimEntity, _kind: int) -> bool:
	return false


## The hero respawned: off every vine.
func on_respawn() -> void:
	pass
