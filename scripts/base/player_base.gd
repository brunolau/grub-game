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

# --- 2.0 party (docs/expansion/TECH_AUDIT.md 4.1, PLAN.md P0.6) -----------------------------------------------------
## Player slot 0..Defs.MAX_PLAYERS - 1 (spawn parameter `slot`, default 0). Slot 0 is P1 = LevelBase.player, the 1.0
## hero. Set it before the hero enters the tree (the level registers him in `LevelBase.heroes[slot]`); setting it
## also points [member run] at that slot's run.
var slot: int = 0:
	set(value):
		slot = clampi(value, 0, Defs.MAX_PLAYERS - 1)
		run = Game.runs[slot]
## This hero's run state: `Game.runs[slot]` (hearts, bones, hand + belt, glider, statistics). For P1 it is the run
## behind the frozen `Game.hearts` / `bones` / `weapon` / `has_glider`, so `run.lose_heart()` is `Game.lose_heart()`.
var run: PlayerRun = Game.runs[0]
## Sim.total_ticks of the tick on which a platform last carried this hero (-1 = never). At most one platform carries
## a hero per tick (PHYSICS.md 11.4): PlatformBase tests and sets it (it was one static guard for the one hero).
var carried_on_tick: int = -1

# --- 2.0 hooks for parallel work (PLAN.md P0.8): egg, shield, curl, mount seat, launch, x fence ------------------------
# Every member below keeps its default for a single-player hero (nothing in Book I solo calls a setter): the 1.0 code
# paths read them only where the default reproduces 1.0 exactly. The rules that drive them are the owners' work in
# phase 1: the egg and the curl player-A (scripts/player/hero_party.gd) with world-A's PartyDriver, the seat
# player-B (hero_mount.gd) with objects-B's objects/mount (PHYSICS.md C.9-C.13).

## Mount seats ([member mount_seat], PHYSICS.md C.9).
const SEAT_NONE: int = 0
const SEAT_DRIVER: int = 1
const SEAT_GUNNER: int = 2
## Curl states ([member curl], PHYSICS.md C.11).
const CURL_NONE: int = 0
## Curled up on the ground (Down + Swap in co-op and versus), waiting for a partner's bat.
const CURL_CURLED: int = 1
## Flying (or rolling) as a batted ball.
const CURL_BALL: int = 2
## Pass it to [method launch] for a velocity component that is to stay as it is (a geyser keeps xvel).
const LAUNCH_KEEP: int = 1 << 30

## True while this hero is an egg: "down" in co-op (DESIGN.md D.3, PHYSICS.md C.12) - out of play without being
## dead: no tile collision, no contact with enemies, items, zones or exits, no target, no doze rectangle. Set by
## [method go_down], cleared by [method hatch] and every respawn. Never true in single-player.
var down: bool = false
## Hatch shield (PHYSICS.md C.12 [R15]): ticks left of blinking with enemy contact skipped (as while hit_timer runs)
## and full control. Set by [method hatch] (PartyTuning.HATCH_BLINK_TICKS), counted down in POST by the party
## component, cleared by every respawn. Versus: the spawn shield (VersusTuning.SPAWN_SHIELD_TICKS, PHYSICS.md C.14:
## no PvP hit, stomp or arena hazard box touches him), which the party component ends at once when he starts a strike
## or a throw. Always 0 in single-player.
var shield: int = 0
## Co-op leash count (PHYSICS.md C.13): consecutive ticks his feet point has been outside the authentic view; the
## party component counts it in POST and makes him an egg at PartyTuning.leash_egg_ticks(); the HUD's edge arrow and
## stone countdown read it (0 = on the view). Cleared by every respawn. Always 0 in single-player.
var leash: int = 0
## Versus hit-stop (PHYSICS.md C.14): ticks left in which this hero skips his PLAYER phase (VersusTuning.HIT_STOP_TICKS
## / HIT_STOP_BIG_TICKS), set by the referee on attacker and victim; counted down by the party component. Always 0
## outside versus.
var hit_stop: int = 0
## Versus squash (PHYSICS.md C.14): ticks left in which a stomped hero ignores UP and FIRE (walking allowed;
## VersusTuning.STOMP_SQUASH_TICKS), set by the referee, counted down by the party component. Always 0 outside versus.
var squash: int = 0
## Curl and ball state (PHYSICS.md C.11): CURL_NONE, CURL_CURLED or CURL_BALL. Always CURL_NONE in single-player.
var curl: int = CURL_NONE
## The hero whose strike launched this ball ([method bat]; null when not a ball): what the ball hits is credited to
## him (Defs.hitter_slot).
var ball_batter: PlayerBase = null
## The mount (objects/mount, PHYSICS.md C.9) this hero sits on, null when none; [member mount_seat] says which seat.
## The mount places its riders every tick (driver at its feet - MountTuning saddle, gunner behind).
var mount: SimEntity = null
var mount_seat: int = SEAT_NONE
## x commit fence of the current tick ([method fence_x]): the rules that keep a hero inside an area (co-op edge walls
## C.13, raft rails C.7). Off (no fence) unless something fenced him this tick.
var _fenced: bool = false
var _fence_left: int = 0
var _fence_right: int = 0

# --- 2.0 duo moves of the hero's side (player-A, PLAN.md P1.4; PHYSICS.md C.10) ----------------------------------------
# The PartyDriver (world-A) runs the party-wide steps after every hero moved (PHYSICS.md C.0 table, PLAYER phase):
# (a) [method carry_totem] for every rider, (b) [method land_on_partner] for every pair in slot order. The rules of
# each step live here, on the hero; the driver only decides who meets whom. Never set in single-player.

## Result of [method land_on_partner].
const HEAD_NONE: int = 0
## Shoulder Hop: he bounced off the partner's head (-224, UP held).
const HEAD_HOP: int = 1
## Totem Ride: he now stands on the partner's head.
const HEAD_RIDE: int = 2
## He fell onto an egg and hatched it (C.12 b).
const HEAD_HATCH: int = 3
## Sfx.DUO_HOP variants (the audio owner's two files): the boost of a Shoulder Hop, a rider landing on his carrier.
const DUO_HOP_BOOST: int = 0
const DUO_HOP_CARRY: int = 1

## Totem Ride, the rider's side: the partner whose head this hero stands on (null = none). Set by
## [method start_totem_ride], cleared by [method end_totem_ride] (a jump, a drop, a hurt, too far from the head, a
## scrape, an egg, a death or a respawn of either). While set, his own update runs with `on_platform` (no gravity).
var totem_carrier: PlayerBase = null
## Totem Ride, the carrier's side: the partner standing on this hero's head (null = none); his jump impulses are halved
## (PartyTuning.TOTEM_CARRIER_JUMP_SHIFT) and a hurt throws the rider off.
var totem_rider: PlayerBase = null
## Ticks left after a drop through the carrier (Down + Up on his head) in which this hero makes no head contact
## (PartyTuning.TOTEM_DROP_LOCK_TICKS); counted down in step 8i by the party component.
var totem_drop_lock: int = 0
## The yvel the last Totem carry gave this rider (carrier dy * 16; 0 at the start of a ride): "he jumped" is measured
## against it ([method carry_totem]).
var totem_carry_yvel: int = 0

# --- 2.0 movement limits (hooks for the Book II terrain and the versus weights; defaults = 1.0) ----------------------
# Written by the components and rules that change them, every tick they apply (tar, PHYSICS.md C.5: player-B's
# components; Grub Stack weight / Hot Rock holder, C.14: world-B's referee); respawn_at restores the defaults. A
# single-player Book I hero never changes them, so his handlers use exactly the 1.0 numbers.

## ACCEL limit of the walk handler (v16; Tuning.WALK_CAP = 80). Tar 32 (C.5), a heavy stack 64 / 48, the Hot Rock
## holder 96 (C.14).
var walk_cap: int = Tuning.WALK_CAP
## ACCEL limit of the airborne step (v16; Tuning.WALK_CAP = 80). A tar hop 32 (C.5), a heavy stack 64 / 48 (C.14).
var air_cap: int = Tuning.WALK_CAP
## The jump handler adds Tuning.JUMP_IMPULSES[n] only while n < this, 0 after it (tar: 2, C.5 [R2]).
var jump_impulse_ticks: int = Tuning.JUMP_IMPULSE_TICKS
## Every jump impulse is (impulse * this) >> 2: 4 = the 1.0 table, 3 = a 20+ stack (C.14).
var jump_impulse_quarters: int = 4
## Versus weight / ember caps as world-B's referee writes them every tick (PHYSICS.md C.14): the ACCEL limit of the walk
## handler AND of the airborne step (0 = Tuning.WALK_CAP) - it sets [member walk_cap] and [member air_cap].
var walk_cap_override: int = 0:
	set(value):
		walk_cap_override = maxi(value, 0)
		walk_cap = walk_cap_override if walk_cap_override > 0 else Tuning.WALK_CAP
		air_cap = walk_cap
## Versus: every jump impulse at 3 / 4 (a 20+ stack, C.14) - it sets [member jump_impulse_quarters].
var jump_scale_3_4: bool = false:
	set(value):
		jump_scale_3_4 = value
		jump_impulse_quarters = 3 if value else 4

# --- 2.0 death toss bookkeeping (read by world-A's PartyDriver; never read in single-player) -------------------------
## Feet point where the last death toss started (PHYSICS.md C.12: the egg appears there, clamped into the view).
var death_origin: Vector2i = Vector2i.ZERO
## Cause of the last death (as for [method kill]); Events.hero_down carries it when the toss ends in an egg.
var death_cause: StringName = &""

# --- 2.0 IDLE rule (orchestrator decision of phase 3; counted only in a co-op party, [method note_own_input]) ---------
## Ticks without input of his own after which a co-op hero is IDLE (10 s at Tuning.TICK_HZ). Private constant until
## core-A adds PartyTuning.IDLE_TICKS (build/engine_requests/wf9_party_to_core-A.txt).
const IDLE_TICKS: int = 243
## Ticks since his own player slot last held an input flag (0 on a tick on which it held one), counted from his entry
## into the level and capped at IDLE_TICKS. Kept through hatches, respawns and team wipes. Always 0 in single-player.
var input_idle_ticks: int = 0
## True once his own slot held some input flag since he entered the level.
var gave_input: bool = false
## The IDLE rule's verdict for this tick ([method is_idle]): set by [method note_own_input]; false in single-player and
## versus. Read it through [method is_idle] / [method counts_for_coop].
var idle: bool = false


func get_kind() -> int:
	return Defs.Kind.PLAYER


func _init() -> void:
	set_box(Tuning.HERO_BOX_STAND)
	z_index = Defs.Z_PLAYER


## Spawn parameter `slot` (player slot, 0 = P1; Defs.MAX_PLAYERS - 1 at most).
func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	if params.has("slot"):
		slot = int(params["slot"])


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


## True while enemy contact is ignored (hit_timer > 0) or he is dead. 2.0: also while the hatch shield runs
## ([member shield] > 0) and while he is an egg ([member down]); both never happen in single-player.
func is_immune() -> bool:
	return hit_timer > 0 or dead or shield > 0 or down


## True during feast mode: enemies die on touch.
func is_feasting() -> bool:
	return feast > 0


## True while this hero is down (a co-op egg, DESIGN.md D.3): out of play without being dead ([member down]). A
## single-player hero is never down.
func is_down() -> bool:
	return down


## True while curled up or flying as a ball (PHYSICS.md C.11).
func is_curled() -> bool:
	return curl != CURL_NONE


## True while he sits on a mount (PHYSICS.md C.9).
func is_mounted() -> bool:
	return mount != null


## True while he stands on a partner's head (Totem Ride, the rider: [member totem_carrier]).
func is_riding_totem() -> bool:
	return totem_carrier != null


## True while a partner stands on his head (Totem Ride, the carrier: [member totem_rider]).
func is_carrying_totem() -> bool:
	return totem_rider != null


## True when UP (= Jump) is held on this tick in his own flags (the bounce height of a head contact). The hero
## answers with the flags he sampled this tick; a bare PlayerBase with [member input_flags].
func holds_up() -> bool:
	return (input_flags & Defs.IN_UP) != 0


## 2.0 Helper mode (DESIGN.md D.3, PHYSICS.md C.12): true for P2 (slot 1) of a co-op run whose players switched
## Options > Co-op "Helper mode" on (Game.helper_mode, copied by Flow at the run start; every recorded route has it
## off). Enemies never hurt him: [method hurt] ignores Defs.HurtKind.ENEMY, BOSS_BODY and BOSS_PROJECTILE (enemy and
## boss contacts, enemy projectiles, hazards that hurt as enemies); his stomps still bounce, and deadly tiles, pits,
## liquids, the band, the auto-scroll edge, the leash and a skull trap still act. Enemies that harm a hero outside
## [method hurt] (a grab that squeezes bones, a drain, a snatch that ends in an egg) skip a hero for whom this is
## true. Never true in single-player (slot 0) or versus.
func is_helper() -> bool:
	return slot == 1 and Game.helper_mode and Game.mode == Defs.GameMode.COOP


## True when a hit of `kind` is one Helper mode ignores on this hero ([method is_helper]).
func helper_ignores(kind: int) -> bool:
	return (kind == Defs.HurtKind.ENEMY or kind == Defs.HurtKind.BOSS_BODY or kind == Defs.HurtKind.BOSS_PROJECTILE) \
			and is_helper()


## True when enemies of a party may pick this hero as their target (LevelBase.target_hero): alive and not down. A
## party of one never asks (1.0 targets the hero unless he is dead). An IDLE hero ([method is_idle]) stays a target:
## enemies attack a dozing caveman as any other.
func is_party_targetable() -> bool:
	return not dead and not is_down()


## 2.0 IDLE rule (orchestrator decision of phase 3, DESIGN.md D.3): true when the co-op rules COUNT this hero - alive,
## hatched (no egg) and not IDLE ([method is_idle]). Every rule that needs "a hero" or "the partner" to be there asks
## this: plates and pulleys (weight), see-saws (the lander), heave boulders (pushers), drums (the count-in), the x2
## tablet, the Brace Wall, the Shoulder Hop, the lee; enemies-A's keeper / Shellback bait and twin windows and the
## bosses' position rules ("on its half", "the nearer hatched hero", "a hero other than the striker") are asked to
## use it too (build/engine_requests/wf9_party_to_*.txt). Physical contacts are not rules: an idle hero still stands,
## blocks a tile mover, is carried, ridden (Totem Ride), launched and hurt. Exactly is_party_targetable() in
## single-player and versus, where nobody is ever idle.
func counts_for_coop() -> bool:
	return not dead and not down and not idle


## 2.0 IDLE rule: true while this co-op hero is IDLE - his own player slot has held no input flag for
## [constant IDLE_TICKS] (10 s), or not once since he entered the level (a level start, a join, a restart at the
## checkpoint: an untouched partner never counts). Reset only by his own slot's input (GameInput.get_flags(slot) != 0,
## an egg's nudge too), never by a hatch, a carry, a bump, a respawn or a team wipe. Counted on every co-op tick by
## [method note_own_input] (the hero, first thing in his WEAPONS phase); never true in single-player or versus. An
## idle hatched hero is drawn dozing (Zzz, the party component) once [member input_idle_ticks] reaches IDLE_TICKS.
func is_idle() -> bool:
	return idle


## 2.0 IDLE rule, once per co-op tick for this hero (Player, before his WEAPONS pass; never in single-player or
## versus): `flags` = his own slot's input flags of this tick (GameInput.get_flags(slot)).
func note_own_input(flags: int) -> void:
	if flags != 0:
		input_idle_ticks = 0
		gave_input = true
	elif input_idle_ticks < IDLE_TICKS:
		input_idle_ticks += 1
	idle = not gave_input or input_idle_ticks >= IDLE_TICKS


## Brace Wall (PHYSICS.md C.10): true when this hero and `partner` (another hero) are both alive and hatched, both in
## the crouch state (5, not crawl), both on the ground, and stand within PartyTuning.BRACE_GAP_PX of each other. A
## `heavy` enemy (enemies) or a boss whose rule says so tests it before its contact with either hero; a lone croucher
## is trampled as usual. A pure query: never true without a partner, so never in single-player. 2.0 IDLE rule: never
## with an idle hero ([method counts_for_coop]).
func braces_with(partner: PlayerBase) -> bool:
	if partner == null or partner == self or dead or partner.dead or down or partner.down or idle or partner.idle:
		return false
	return is_crouching() and partner.is_crouching() and is_grounded() and partner.is_grounded() \
			and absi(sim_pos.x - partner.sim_pos.x) <= PartyTuning.BRACE_GAP_PX


## The Brace flag (PHYSICS.md C.10): the first hero of the level's contact order with whom this hero braces
## ([method braces_with]), or null - a lone croucher, and always in single-player. Heavy enemies and boss rules read it
## before their contact with this hero ([method is_braced]).
func brace_partner() -> PlayerBase:
	if down or dead or not is_crouching():
		return null
	var level: LevelBase = Game.level
	if level == null or level.hero_count() <= 1:
		return null
	for other: PlayerBase in level.contact_order():
		if other != self and braces_with(other):
			return other
	return null


## True while this hero is half of a Brace Wall ([method brace_partner] is not null).
func is_braced() -> bool:
	return brace_partner() != null


# --- Calls other modules make -----------------------------------------------------------------------------------------

## Damage the hero (PHYSICS.md 10.1). `kind` is a Defs.HurtKind; `source` is the enemy / boss / projectile / item
## (may be null). Returns true when the hit was applied, false when it was ignored (immune, dead, feast).
## ENEMY: -1 heart or lose the glider, yvel -128, xvel = -(xvel * 4), hit_timer 44.
## BOSS_BODY: one bone, yvel -128, xvel +/-128 away from the source with ice = 3, hit_timer 44.
## BOSS_PROJECTILE: -1 heart and 6 bones scattered. TRAP: all energy scattered as bones, hurt pose, no death.
## Once the level is completed (LevelBase.completed: the exit animation plays) every hit is ignored, and so is every
## hit on an egg ([member down], 2.0) and an enemy's hit on a Helper-mode P2 ([method helper_ignores], 2.0).
func hurt(source: SimEntity, kind: int = Defs.HurtKind.ENEMY) -> bool:
	if dead or down or (Game.level != null and Game.level.completed):
		return false
	if slot != 0 and helper_ignores(kind):
		return false
	if hit_timer > 0 and kind != Defs.HurtKind.TRAP and kind != Defs.HurtKind.BOSS_PROJECTILE:
		return false
	var killed: bool = false
	match kind:
		Defs.HurtKind.BOSS_BODY:
			killed = run.lose_bone()
			var away: int = 1
			if source != null and source.sim_pos.x > sim_pos.x:
				away = -1
			xvel = Tuning.BOSS_KNOCK_XVEL * away
			ice = Tuning.ICE_MAX
		Defs.HurtKind.TRAP:
			run.scatter_energy()
		Defs.HurtKind.BOSS_PROJECTILE:
			killed = run.lose_heart()
		_:
			if run.has_glider:
				run.set_glider(false)
			else:
				killed = run.lose_heart()
			xvel = xvel * Tuning.HURT_XVEL_FACTOR
	hit_timer = Tuning.HIT_TIMER
	attack_gate = false
	glide = 0
	yvel = Tuning.HURT_YVEL
	grounded = false
	Events.player_hurt.emit(kind, source)
	Events.hero_hurt.emit(self, kind, source)
	if killed:
		kill(&"enemy")
	return true


## Instant death (PHYSICS.md 10.3): costs a life regardless of energy and of hit_timer.
## `cause`: &"enemy", &"spikes", &"liquid", &"pit", &"crush", &"off_screen", &"give_up", &"time" (the
## level's time limit ran out). Ignored once the level is completed (the exit animation plays), and for an egg
## ([member down], 2.0: it touches nothing).
func kill(cause: StringName) -> void:
	if dead or down or (Game.level != null and Game.level.completed):
		return
	death_origin = sim_pos
	death_cause = cause
	dead = true
	control_enabled = false
	club_box_active = false
	Events.player_died.emit(cause)
	Events.hero_died.emit(self, cause)


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
	Events.hero_feast_changed.emit(self, feast)


## Give (true) or take away (false) the hang-glider.
func set_glider(carrying: bool) -> void:
	if not carrying:
		glide = 0
	run.set_glider(carrying)
	Events.glider_state_changed.emit(carrying, is_gliding())
	Events.hero_glider_state_changed.emit(self, carrying, is_gliding())


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
	# 2.0 (defaults in single-player): hatched, no shield, leash, hit-stop or squash, uncurled, off any mount, no fence.
	down = false
	shield = 0
	leash = 0
	hit_stop = 0
	squash = 0
	curl = CURL_NONE
	ball_batter = null
	leave_mount()
	_fenced = false
	end_totem_ride()
	if totem_rider != null:
		totem_rider.end_totem_ride()
	totem_drop_lock = 0
	walk_cap_override = 0
	jump_scale_3_4 = false
	jump_impulse_ticks = Tuning.JUMP_IMPULSE_TICKS
	if feast > 0:
		feast = 0
		Events.feast_changed.emit(0)
		Events.hero_feast_changed.emit(self, 0)
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


# --- 2.0 calls (PLAN.md P0.8; never made in single-player) --------------------------------------------------------------

## The launch primitive of PHYSICS.md C.0 #4 (geysers, see-saws, vine leaps, Batter Up, dismounts, hatching): each
## given component is clamped to +/- PartyTuning.LAUNCH_AXIS_CAP v16 (pass LAUNCH_KEEP to keep one, e.g. a geyser
## keeps xvel); then fall_ticks = 0, no_jump = Tuning.NO_JUMP_TICKS (a launched hero never adds the jump table),
## on_platform and grounded cleared; glide unchanged.
func launch(p_xvel: int, p_yvel: int) -> void:
	if p_xvel != LAUNCH_KEEP:
		xvel = clampi(p_xvel, -PartyTuning.LAUNCH_AXIS_CAP, PartyTuning.LAUNCH_AXIS_CAP)
	if p_yvel != LAUNCH_KEEP:
		yvel = clampi(p_yvel, -PartyTuning.LAUNCH_AXIS_CAP, PartyTuning.LAUNCH_AXIS_CAP)
	fall_ticks = 0
	no_jump = Tuning.NO_JUMP_TICKS
	on_platform = false
	grounded = false


## Make this hero an egg where he is (PHYSICS.md C.12: after his death toss, or at once for the leash and the
## voluntary egg): [member down] set, `dead` cleared (an egg is not dead), no control, no strike, no glide, no curl,
## off any mount, motion stopped; Events.hero_down(self, cause). The egg's box, drift, nudge and Expert return are
## the party component's (player-A), the team-wipe check the PartyDriver's (world-A). `cause` as for [method kill]
## (plus &"leash", &"voluntary").
func go_down(cause: StringName) -> void:
	if down:
		return
	down = true
	dead = false
	control_enabled = false
	club_box_active = false
	attack_gate = false
	glide = 0
	curl = CURL_NONE
	ball_batter = null
	xvel = 0
	yvel = 0
	leave_mount()
	end_totem_ride()
	if totem_rider != null:
		totem_rider.end_totem_ride()
	Events.hero_down.emit(self, cause)


## Hatch this egg (PHYSICS.md C.12): hatched again with `hearts` hearts and no bones in his run, control back,
## [member shield] = PartyTuning.HATCH_BLINK_TICKS, the pop launch(0, PartyTuning.HATCH_POP_YVEL);
## Events.hero_revived(self, by). `by` = the partner whose box, projectile or stomp hatched it (null: a checkpoint).
## Does nothing unless he is down.
func hatch(by: PlayerBase, hearts: int) -> void:
	if not down:
		return
	down = false
	control_enabled = true
	hit_timer = 0
	shield = PartyTuning.HATCH_BLINK_TICKS
	run.hearts = hearts
	run.bones = 0
	run.emit_energy()
	launch(0, PartyTuning.HATCH_POP_YVEL)
	Events.hero_revived.emit(self, by)


## A partner's front strike batted this curled hero (PHYSICS.md C.11): he flies as a ball, launch(p_xvel, p_yvel)
## (each component within PartyTuning.LAUNCH_AXIS_CAP), credited to `batter`. The flight, the grounder roll and the
## uncurl are the party component's (player-A).
func bat(p_xvel: int, p_yvel: int, batter: PlayerBase) -> void:
	curl = CURL_BALL
	ball_batter = batter
	launch(p_xvel, p_yvel)


## objects/mount seats this hero (PHYSICS.md C.9): `seat` SEAT_DRIVER or SEAT_GUNNER, yvel 0, no glide. The mount
## places him every tick; his own update is the mount component's (player-B) while seated.
func sit_on_mount(p_mount: SimEntity, seat: int) -> void:
	mount = p_mount
	mount_seat = seat if seat == SEAT_GUNNER else SEAT_DRIVER
	yvel = 0
	glide = 0
	on_platform = false


## Leave the seat (a dismount, the mount bolting, a stage start). Safe when not mounted.
func leave_mount() -> void:
	mount = null
	mount_seat = SEAT_NONE


## Fence this tick's x commit (PHYSICS.md 2, the rule of step 8e) into `left` <= x < `right_excl` on top of the level
## bounds: co-op edge walls (C.13), raft rails (C.7). Several fences in one tick intersect; the fence ends with this
## tick's x step (call it every tick it applies, before the PLAYER phase or in it before the x step). A component
## that runs the hero's x step itself (the ball flight, a seated rider) applies [method fence_allows] and
## [method clear_fence] the same way.
func fence_x(left: int, right_excl: int) -> void:
	if _fenced:
		_fence_left = maxi(_fence_left, left)
		_fence_right = mini(_fence_right, right_excl)
	else:
		_fenced = true
		_fence_left = left
		_fence_right = right_excl


## True when the fence of this tick lets the x commit move him to `x` (always true without a fence: the 1.0 rule).
func fence_allows(x: int) -> bool:
	return not _fenced or (x >= _fence_left and x < _fence_right)


## End this tick's fence (the hero calls it right after his x step).
func clear_fence() -> void:
	_fenced = false


## True when the x commit rule (PHYSICS.md 2) lets this hero stand at `x` now: inside the level bounds and, in a
## co-op party, inside the edge walls of the tribe camera (C.13; the hero answers that part). For moves that carry him
## outside his own x step (the Totem carry). Without a level: true.
func x_commit_allows(x: int) -> bool:
	var level: LevelBase = Game.level
	if level == null:
		return true
	return x >= Tuning.X_MIN and x < level.grid.x_max_excl()


# --- 2.0 duo moves (PHYSICS.md C.10, C.12 b; the hero's side of the PartyDriver's steps a and b) --------------------

## May this hero start a head contact this tick (PHYSICS.md C.10 step b)? yvel >= 0, alive and hatched, not gliding,
## climbing, curled or a ball, mounted, already riding, nor in a drop lock.
func can_land_on_partner() -> bool:
	# (glide & 1) is is_gliding(), written out: the driver asks this for every hero on every co-op tick (P2.12).
	return yvel >= 0 and not dead and not down and (glide & 1) == 0 and state != Defs.HeroState.CLIMB \
			and curl == CURL_NONE and mount == null and totem_carrier == null and totem_drop_lock == 0


## The PartyDriver's step b for one pair (PHYSICS.md C.10, C.12 b), after every hero moved: this hero (A) against
## `partner` (B), another living hero. When A may land ([method can_land_on_partner]) and Overlap.body(A, B, A) finds a
## contact with the stomp flag (2.2: A's feet in the top half of B's box, or A falling at 8 px/tick or more):
##  - B is an egg: A bounces -64 (Tuning.BOUNCE_YVEL, the enemy bounce without UP: a 10 px rise) **whether UP is held
##    or not** and hatches it ([method hatch] with PartyTuning.hatch_hearts) - HEAD_HATCH. An egg is no springboard
##    (orchestrator resolution after G1, closing the G1 verifier's "egg pinned over the active hero" bounce): the full
##    Shoulder Hop height needs an active partner's head, which world-A's PartyDriver decides (it never offers a hero
##    holding UP an idle, just-hatched partner);
##  - A holds UP: the Shoulder Hop ([method shoulder_hop]; B in any state, airborne too) - HEAD_HOP;
##  - else the Totem Ride on B ([method start_totem_ride]; not on a curled partner) - HEAD_RIDE.
## Returns what happened (HEAD_NONE: nothing). At most one head contact per hero per tick: the driver stops testing A
## after a result other than HEAD_NONE. Co-op only (versus heads are the referee's stomps).
func land_on_partner(partner: PlayerBase) -> int:
	if partner == null or partner == self:
		return HEAD_NONE
	# Overlap.body's coarse reject first (the two-hero performance pass, PLAN.md P2.12): the driver asks every pair on
	# every co-op tick and the two heroes are nearly always farther apart than any two boxes reach.
	var apart: Vector2i = sim_pos - partner.sim_pos
	if absi(apart.x) >= Tuning.OVERLAP_MAX_DX or absi(apart.y) >= Tuning.OVERLAP_MAX_DY:
		return HEAD_NONE
	if partner.dead or not can_land_on_partner():
		return HEAD_NONE
	if partner.mount != null or partner.totem_carrier == self:
		return HEAD_NONE
	if not Overlap.body(self, partner, self) or not Overlap.stomp:
		return HEAD_NONE
	var depth: int = Overlap.depth
	if partner.down:
		bounce(Tuning.BOUNCE_YVEL, depth)
		partner.hatch(self, PartyTuning.hatch_hearts(Game.difficulty))
		return HEAD_HATCH
	if holds_up():
		shoulder_hop(partner, depth)
		return HEAD_HOP
	if partner.curl != CURL_NONE:
		return HEAD_NONE
	start_totem_ride(partner)
	return HEAD_RIDE


## Shoulder Hop (PHYSICS.md C.10): exactly the enemy bounce of section 9 off `partner`'s head - yvel -224
## (PartyTuning.SHOULDER_HOP_YVEL), fall_ticks 0, lifted by `depth`, no_jump left armed; `partner` is unaffected.
func shoulder_hop(partner: PlayerBase, depth: int) -> void:
	bounce(PartyTuning.SHOULDER_HOP_YVEL, depth)
	_party_cue(Sfx.DUO_HOP, DUO_HOP_BOOST)
	Events.hero_bounced.emit(self, partner, 0)


## Totem Ride start (PHYSICS.md C.10): this hero, the rider, stands on `carrier`'s head - y = carrier.y - 34
## (PartyTuning.TOTEM_REST_PX: the carrier's 32 x 35 riding box, rest 1 px inside), yvel 0, `on_platform`, the
## grounded bookkeeping (no_jump - 1, jump_ticks 0, fall_ticks 0, last_ground_y); the two are linked
## ([member totem_carrier], [member totem_rider]).
func start_totem_ride(carrier: PlayerBase) -> void:
	if carrier == null or carrier == self:
		return
	end_totem_ride()
	if carrier.totem_rider != null and carrier.totem_rider != self:
		carrier.totem_rider.end_totem_ride()
	totem_carrier = carrier
	carrier.totem_rider = self
	sim_pos.y = carrier.sim_pos.y - PartyTuning.TOTEM_REST_PX
	yvel = 0
	totem_carry_yvel = 0
	_totem_bookkeeping()
	_party_cue(Sfx.DUO_HOP, DUO_HOP_CARRY)


## The PartyDriver's step a for this rider (PHYSICS.md C.10 Carry; every tick, before new head contacts): he follows
## his carrier's motion of this tick (dx, dy = carrier.sim_pos - carrier.sim_prev). The ride ends - returns false, both
## unlinked - when he jumped or was knocked up (his yvel more than 16 v16 above what the last carry gave him:
## yvel - [member totem_carry_yvel] < PartyTuning.TOTEM_JUMP_OFF_YVEL; on a still carrier exactly C.10's yvel < -16,
## and a rising carrier keeps his rider, which the R6 Totem launch needs), either is down or dead,
## or |x + dx - carrier.x| > 16 (PartyTuning.TOTEM_FOOT_REACH_PX). Otherwise: x += dx (level bounds and edge walls
## only, [method x_commit_allows]), y = carrier.y - 34, yvel = dy * 16, `on_platform` and the grounded bookkeeping;
## then the scrape - his wall-probe cell (x +/- 9 towards dx, row - 1) a wall (SIDE 1) or his head probe
## (col, row - 2) a ceiling: x -= dx and the ride ends (he falls off). True while he still rides.
func carry_totem() -> bool:
	var carrier: PlayerBase = totem_carrier
	if carrier == null:
		return false
	if not is_instance_valid(carrier) or dead or down or carrier.dead or carrier.down:
		end_totem_ride()
		return false
	var dx: int = carrier.sim_pos.x - carrier.sim_prev.x
	var dy: int = carrier.sim_pos.y - carrier.sim_prev.y
	if yvel - totem_carry_yvel < PartyTuning.TOTEM_JUMP_OFF_YVEL \
			or absi(sim_pos.x + dx - carrier.sim_pos.x) > PartyTuning.TOTEM_FOOT_REACH_PX:
		end_totem_ride()
		return false
	var moved: int = 0
	if dx != 0 and x_commit_allows(sim_pos.x + dx):
		sim_pos.x += dx
		moved = dx
	sim_pos.y = carrier.sim_pos.y - PartyTuning.TOTEM_REST_PX
	yvel = dy * Tuning.V16_PER_PX
	totem_carry_yvel = yvel
	_totem_bookkeeping()
	var level: LevelBase = Game.level
	if level != null:
		var row: int = Tuning.to_cell(sim_pos.y)
		var toward: int = signi(dx) if dx != 0 else signi(xvel)
		var probe_col: int = Tuning.to_cell(sim_pos.x + Tuning.WALL_PROBE * toward)
		if level.grid.side_at(probe_col, row - 1) == TileGrid.SIDE_WALL \
				or level.grid.ceiling_at(Tuning.to_cell(sim_pos.x), row - Tuning.HEAD_PROBE_ROWS) == TileGrid.CEILING_SOLID:
			sim_pos.x -= moved
			end_totem_ride()
			on_platform = false
			grounded = false
			return false
	return true


## Leave the Totem Ride (called on the rider; safe when he does not ride): both links cleared.
func end_totem_ride() -> void:
	if totem_carrier != null:
		if is_instance_valid(totem_carrier) and totem_carrier.totem_rider == self:
			totem_carrier.totem_rider = null
		totem_carrier = null


## The rider's drop (PHYSICS.md C.10: Down + Up on the carrier's head): he leaves with yvel 0 and falls through the
## carrier to the floor; no head contact for PartyTuning.TOTEM_DROP_LOCK_TICKS.
func drop_from_totem() -> void:
	end_totem_ride()
	yvel = 0
	on_platform = false
	grounded = false
	totem_drop_lock = PartyTuning.TOTEM_DROP_LOCK_TICKS


## A hurt carrier throws his rider off (PHYSICS.md C.10): launch(0, -64), no damage. Safe without a rider.
func throw_off_totem_rider() -> void:
	var rider: PlayerBase = totem_rider
	if rider == null:
		return
	rider.end_totem_ride()
	if is_instance_valid(rider):
		rider.launch(0, PartyTuning.TOTEM_THROW_OFF_YVEL)


func _totem_bookkeeping() -> void:
	on_platform = true
	grounded = true
	ice = 0
	if no_jump > 0:
		no_jump -= 1
	jump_ticks = 0
	fall_ticks = 0
	last_ground_y = sim_pos.y


## A 2.0 cue of the hero (Sfx names whose AudioTable rows arrive in batches, PLAN.md P1.1): played only once its row
## exists, so a missing row is silence instead of an error. `variant` as Audio.play_sfx (-1 = the row's rotation).
static func _party_cue(event: StringName, variant: int = -1) -> void:
	if AudioTable.SFX.has(event):
		Audio.play_sfx(event, variant)
