class_name HeroBelt
extends RefCounted
## The hero's weapon belt and the Swap input (docs/spec/PHYSICS.md C.1, C.2; DESIGN.md C.1): hand and belt, the
## edge-triggered Swap, the 8-tick lock-out, the fresh-club rule at a stage start.
##
## Owner: player-B (docs/expansion/PLAN.md 4.1). A component of [Player], created with him; the calls below are the
## hooks of PLAN.md P0.8 and are made only while [member active] is true. The bodies are minimal on purpose: phase 1
## (PLAN.md P1.5) fills them in. Book I solo never switches it on (meta `belt = carry`: Swap is ignored, the 1.0
## single weapon), so a single-player hero never runs any of it.
##
## Hook order inside Player._hero_update (PLAYER phase, step 8): after the input is read (8b) and after the party and
## mount components had their turn, [method update] runs once (it never takes the update over); the timers of 8i run
## [method tick_timers]. The run state lives in `hero.run` (PlayerRun: weapon = the hand, belt, swap_belt(),
## take_fresh_club()); nothing in the simulation but Swap reads the belt (PHYSICS.md C.2 rule 5: belt invariance).

## The hero this component belongs to.
var hero: Player = null
## True while the hooks run. Default false: the 1.0 hero (`belt = carry`) never swaps.
var active: bool = false


func _init(p_hero: Player) -> void:
	hero = p_hero


## The hero entered a level (Player._ready): decide [member active] from the level (`Levels.get_belt_rule`, its
## `belt` meta) and the mode. Minimal body: stays off.
func setup(_level: LevelBase) -> void:
	pass


## PLAYER phase, after 8b: read this tick's Swap edge from the hero's own flags (PHYSICS.md C.1) and swap hand and
## belt (C.2 rule 2). Never takes the hero's update over: returns false.
func update(_level: LevelBase) -> bool:
	return false


## Step 8i: count the swap lock-out down.
func tick_timers() -> void:
	pass


## The hero was hurt; true = the belt took the hit instead of the 1.0 hurt (never: hand and belt survive a hurt).
func on_hurt(_source: SimEntity, _kind: int) -> bool:
	return false


## The hero respawned (Player.respawn_at): hand and belt are kept (C.2 rule 4); clear per-tick state.
func on_respawn() -> void:
	pass
