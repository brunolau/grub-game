class_name PlayerBase
extends SimEntity
## The hero as seen by the rest of the game: readable state plus the calls other modules may make on him.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.12). Owner: player (bodies may be replaced; public signatures and the
## meaning of every field are frozen). `res://scenes/player/player.tscn` has a root script `Player` that extends
## this class and reproduces docs/spec/PHYSICS.md tick for tick.
##
## The bodies below are minimal but working, so that enemies, objects, world and UI can be developed and
## tested against a bare PlayerBase before the real controller exists.

# --- State other modules may READ (names follow PHYSICS.md 0) ---------------------------------------------------------
## Current state number of PHYSICS.md 4.3 (Defs.HeroState), after the overrides.
var state: int = Defs.HeroState.IDLE
## Input flags used on this tick (Defs.IN_*), after swing_lock / control suppression.
var input_flags: int = 0
## Slipperiness 0..3 set by the floor tile; keeps its last value while airborne.
var ice: int = 0
## True while riding a platform (set by ride_platform, cleared by jumping).
var on_platform: bool = false
## True when the last tile collision found ground (or a platform) under the feet.
var grounded: bool = true
## Ticks spent in the jump handler since the last soft landing.
var jump_ticks: int = 0
## Ticks with yvel > 0 since the last landing.
var fall_ticks: int = 0
## Jump lock-out counter (6 after any fall; counts down on grounded ticks).
var no_jump: int = 0
## y of the last soft landing (drop detection).
var last_ground_y: int = 0
## > 0 while crouching / crawling (hatches are open, gates may be entered).
var drop_timer: int = 0
## Club charge (x4 damage while > 0).
var charge: int = 0
## Inputs are ignored for the state table while > 0.
var swing_lock: int = 0
## True while a strike script is running.
var attack_gate: bool = false
## 44 after a hit; hurt state while >= 22; immune to enemy contact while > 0.
var hit_timer: int = 0
## Feast (invincibility) ticks left.
var feast: int = 0
## Bit 0 set while gliding.
var glide: int = 0
## Counts walking / striking ticks (out-of-breath animation).
var idle_timer: int = 0
## True while the look-around pose is active (the camera pans in the facing direction, PHYSICS.md 12.3).
var looking: bool = false
## True from the death trigger until the respawn.
var dead: bool = false
## False during cutscenes / level end: every input reads as released.
var control_enabled: bool = true

# --- Club box created on THIS tick; it is hit-tested in the WEAPONS phase of the next tick (PHYSICS.md 8.2) -----------
## True when a melee box exists.
var club_box_active: bool = false
## The box in logical px.
var club_box: Rect2i = Rect2i()
## Its x_offset for the overlap test (origin.x - left).
var club_box_xo: int = 0
## Its origin (bottom anchor) in logical px, used by the hidden-tile test.
var club_origin: Vector2i = Vector2i.ZERO
## Power stored with the box (already x4 when charged).
var club_power: int = 0


func get_kind() -> int:
	return Defs.Kind.PLAYER


func _init() -> void:
	set_box(Tuning.HERO_BOX_STAND)
	z_index = Defs.Z_PLAYER


# --- Queries ----------------------------------------------------------------------------------------------------------

## True when he stands on a floor or a platform (yvel == 0 or on_platform).
func is_grounded() -> bool:
	return grounded or on_platform


## True in the crouch state (5) - the state that resists the screen-shake nudge.
func is_crouching() -> bool:
	return state == Defs.HeroState.CROUCH


## True in the crouch or crawl state.
func is_low() -> bool:
	return state == Defs.HeroState.CROUCH or state == Defs.HeroState.CRAWL


## True while gliding with the hang-glider.
func is_gliding() -> bool:
	return (glide & 1) != 0


## True while a strike is in progress (flyers rise 5 px, the Brute gets angry; GAMEPLAY.md 5.2 / 6.1).
func is_striking() -> bool:
	return attack_gate


## True while enemy contact is ignored (hit_timer > 0) or he is dead.
func is_immune() -> bool:
	return hit_timer > 0 or dead


## True during feast mode: enemies die on touch.
func is_feasting() -> bool:
	return feast > 0


# --- Calls other modules make -----------------------------------------------------------------------------------------

## Damage the hero (PHYSICS.md 10.1). `kind` is a Defs.HurtKind; `source` is the enemy / boss / projectile / item
## (may be null). Returns true when the hit was applied, false when it was ignored (immune, dead, feast).
## ENEMY: -1 heart or lose the glider, yvel -128, xvel = -(xvel * 4), hit_timer 44.
## BOSS_BODY: one bone, yvel -128, xvel +/-128 away from the source with ice = 3, hit_timer 44.
## BOSS_PROJECTILE: -1 heart and 6 bones scattered. TRAP: all energy scattered as bones, hurt pose, no death.
func hurt(source: SimEntity, kind: int = Defs.HurtKind.ENEMY) -> bool:
	if dead or (hit_timer > 0 and kind != Defs.HurtKind.TRAP and kind != Defs.HurtKind.BOSS_PROJECTILE):
		return false
	var killed: bool = false
	match kind:
		Defs.HurtKind.BOSS_BODY:
			killed = Game.lose_bone()
			var away: int = 1
			if source != null and source.sim_pos.x > sim_pos.x:
				away = -1
			xvel = Tuning.BOSS_KNOCK_XVEL * away
			ice = Tuning.ICE_MAX
		Defs.HurtKind.TRAP:
			Game.scatter_energy()
		Defs.HurtKind.BOSS_PROJECTILE:
			killed = Game.lose_heart()
		_:
			if Game.has_glider:
				Game.set_glider(false)
			else:
				killed = Game.lose_heart()
			xvel = xvel * Tuning.HURT_XVEL_FACTOR
	hit_timer = Tuning.HIT_TIMER
	attack_gate = false
	glide = 0
	yvel = Tuning.HURT_YVEL
	grounded = false
	Events.player_hurt.emit(kind, source)
	if killed:
		kill(&"enemy")
	return true


## Instant death (PHYSICS.md 10.3): costs a life regardless of energy and of hit_timer.
## `cause`: &"enemy", &"spikes", &"liquid", &"pit", &"crush", &"off_screen", &"give_up", &"time" (the
## level's time limit ran out).
func kill(cause: StringName) -> void:
	if dead:
		return
	dead = true
	control_enabled = false
	club_box_active = false
	Events.player_died.emit(cause)


## Bounce off an enemy or boss head (PHYSICS.md 9): yvel is set, fall_ticks cleared, the hero is lifted by
## `depth` px (the penetration reported by Overlap.depth).
func bounce(yvel_v16: int, depth: int = 0) -> void:
	yvel = yvel_v16
	fall_ticks = 0
	grounded = false
	sim_pos.y -= depth


## Called by a platform that passed its ride test this tick (PHYSICS.md 11.4): carries the hero by `dx`, sets
## on_platform and the grounded bookkeeping, and puts his feet on the platform top.
func ride_platform(platform: SimEntity, dx: int, dy: int) -> void:
	on_platform = true
	ice = 0
	sim_pos.x += dx
	if no_jump > 0:
		no_jump -= 1
	jump_ticks = 0
	last_ground_y = sim_pos.y
	var top: int = platform.sim_pos.y - platform.box_h
	if sim_pos.y > top:
		sim_pos.y = top + 1
		yvel = 1
	else:
		yvel = dy * 16


## Screen-shake nudge (PHYSICS.md 13.3): lifted `px` unless he is in the crouch state. Called by the level.
func apply_shake_nudge(px: int) -> void:
	if dead or is_crouching():
		return
	sim_pos.y -= px


## Start feast mode (GAMEPLAY.md 8.3).
func start_feast(ticks: int = Tuning.FEAST_TICKS) -> void:
	feast = ticks
	Events.feast_changed.emit(feast)


## Give (true) or take away (false) the hang-glider.
func set_glider(carrying: bool) -> void:
	if not carrying:
		glide = 0
	Game.set_glider(carrying)
	Events.glider_state_changed.emit(carrying, is_gliding())


## Put the hero at `pos` with zero velocity and all timers cleared (level start, respawn, gate travel keeps
## timers: use teleport() for gates).
func respawn_at(pos: Vector2i) -> void:
	dead = false
	control_enabled = true
	xvel = 0
	yvel = 0
	state = Defs.HeroState.IDLE
	ice = 0
	on_platform = false
	grounded = true
	jump_ticks = 0
	fall_ticks = 0
	no_jump = 0
	drop_timer = 0
	charge = 0
	swing_lock = 0
	attack_gate = false
	hit_timer = 0
	glide = 0
	idle_timer = 0
	looking = false
	club_box_active = false
	last_ground_y = pos.y
	if feast > 0:
		feast = 0
		Events.feast_changed.emit(0)
	teleport(pos)
	Events.player_spawned.emit(self)


## Enable / disable player control (tally walk-off, boss intro). Disabled = all inputs released.
func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled


## A weapon box of this hero hit something while he was airborne: pogo (PHYSICS.md 9). Called by whoever
## resolves a hit outside the hero's own weapon pass (bosses).
func notify_weapon_hit() -> void:
	if yvel != 0:
		yvel = Tuning.POGO_YVEL
