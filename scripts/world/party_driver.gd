class_name PartyDriver
extends SimEntity
## The party-wide steps of a co-op party (docs/expansion/PLAN.md P1.6; docs/spec/PHYSICS.md C.0 table, C.10-C.13;
## GAMEPLAY.md 13.9). Owner: world-A.
##
## Level registers one driver in co-op (Game.mode == COOP with two or more heroes, never in an arena) right after the
## heroes (LevelBase.register_party_driver): it ticks after every hero in each of its phases, so `Defs.Phase` stays as
## it is. A party of one never has a driver (TECH_AUDIT.md 2: N = 1 is the identity); single-player never reaches a
## line of this file. Everything is integer and deterministic: no signal, no listener, no randomness.
##
## The IDLE rule (orchestrator decision of phase 3, DESIGN.md G33): a hero whose own slot gave no input for
## PlayerBase.IDLE_TICKS (10 s), or none since he entered the level, is counted by no co-op rule of this driver and no
## duo move uses him: no head contact by him or on his head (no Shoulder Hop, Totem Ride or stomp hatch), a running ride
## ends when its rider or carrier becomes idle, no lee behind him, no Relay Bounce by him. The physical steps (edge
## walls, eggs) treat him as any hatched hero. PlayerBase.counts_for_coop / is_idle are the queries.
## wf11 ruling R6: an idle hero is no camera anchor (LevelCamera.tick_group follows the heroes who count) and he is
## the one the leash takes ([method _leash]): a hero who plays is never egged because his partner put the pad down.
##
## Per tick (each step runs after every hero's own step of the phase):
##  - WEAPONS: who is ACTIVE ([method is_active]); who stands in a crouching partner's lee on this tick
##    ([method _update_lee], LevelBase.lee_mask / wind_for); the co-op edge walls (C.13) - every hatched hero is
##    fenced into LevelBase.get_edge_walls() for this tick's x commit (PlayerBase.fence_x; rafts intersect their rails
##    later in PLATFORMS).
##  - PLAYER (after every hero moved): (a) the Totem Ride carry of every rider, (b) new head contacts in slot order -
##    Shoulder Hop, ride start, hatch by a stomp (C.10, C.12 b). The rules of both live on the hero
##    (PlayerBase.carry_totem / land_on_partner, player-A: the rider's drop and a hurt carrier's throw-off too); the
##    driver only decides who meets whom and when. **An egg is no springboard** (orchestrator resolution after G1):
##    the stomp that hatches an egg bounces Tuning.BOUNCE_YVEL (-64), UP held or not (the hero's rule), and a hero
##    holding UP meets only an ACTIVE partner's head - the full Shoulder Hop never comes from an egg nor from the idle
##    body that pops out of one.
##  - POST: rides whose rider or carrier left the tribe end; the leash (C.13: a hero off the authentic view becomes an egg after
##    PartyTuning.leash_egg_ticks); the egg drift, the owner's nudge, the clamp into the view and the Expert return
##    (C.12); the team wipe of a party whose last hatched hero became an egg without a death toss, and - phase 4 ruling
##    Q3, DESIGN.md G86 - of a party at the dead end beside an idle partner (the egg of a hero whose player plays,
##    every hatched hero IDLE) once that has lasted PartyTuning.IDLE_WIPE_TICKS ticks ([method _wipe_check]).
## Called by others (each only in a party; check `level.party_driver` and has_method):
##  - [method weapon_pass] from HeroParty.weapon_pass (player-A) at the start of a hero's WEAPONS pass: his projectiles
##    and his club box first hatch eggs and bat curled partners (Batter Up, C.11), and are consumed by it.
##  - [method handle_hero_death] from LevelBase.hero_death_finished: a death toss ends in an egg while a partner plays.
##  - [method exit_touched] / [method is_at_exit] (objects/exit: the team exit), [method travel_party] (objects/gate:
##    the party travels), [method hatch_all] (the shared checkpoint), [method bones_to_partner] (items/bone),
##    [method relay_bounce_count] / [method relay_multiplier] (EnemyBase: the Relay Bounce of the Feast Lands).

## Relay Bounce (GAMEPLAY.md 13.9.8): past Tuning.BOUNCE_COUNT_MAX (11) the counter rises only on a bounce by the
## other hero than the previous one, up to this; 12-13 pay PartyTuning.RELAY_BOUNCE_MULTIPLIERS[0], 14-15 [1].
const RELAY_COUNT_MAX: int = 15
## Kind of the level files that are Feast Lands (a co-op Feast Land is `kind = coop` with `coop_of` a bonus file).
const FEAST_KIND: String = "bonus"
## The lee ([method _update_lee]; *(tune)*, PartyTuning rows asked of core-A): how far downwind of a crouching partner
## (feet to feet, px) a hero is sheltered - 4 tiles, so that a pair leapfrogs gaps of up to 3 tiles: the second
## hero waits at the near edge in the lee of the first, who crouches just past the far edge - and how far his feet may
## be above or below the croucher's.
const LEE_REACH_PX: int = 64
const LEE_DY_PX: int = 16

## Ticks every hero has been an egg (index = slot; 0 = hatched). The Expert return starts at
## PartyTuning.egg_return_ticks.
var egg_ticks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Bit per slot: the hero reached the open exit and waits there for his team ([method exit_touched]).
var exit_mask: int = 0
## True from a team wipe the driver started until the level reset that follows it.
var wipe_pending: bool = false
## Bit per slot: the hero is ACTIVE - hatched, and his own slot held some input flag since he last became hatched
## (the level start, a team-wipe respawn, a hatch). Going down (an egg, a death toss) clears it. See [method is_active].
var active_mask: int = 0

## Sign of the wind the lee mask of the last tick was made for (0: no lee).
var _lee_sign: int = 0
## Phase 4 ruling Q3 (DESIGN.md G86), NO DEAD END BESIDE AN IDLE PARTNER: ticks in a row that ended with the party at
## that dead end ([method _idle_dead_end]: the egg of a hero whose player plays, every hatched hero IDLE, no death
## toss running). 0 on every tick that ends otherwise; at PartyTuning.IDLE_WIPE_TICKS the team is wiped.
var idle_wipe_ticks: int = 0
## Bit per slot: that hero was an egg at the last wipe check ([method _wipe_check]: a fresh egg is a hero going down).
var _egg_mask: int = 0
## Relay Bounce: enemy instance id -> slot of the hero who bounced on it last.
var _relay_last: Dictionary = {}
## Feast Land check of the running level, decided once (-1 = not yet).
var _feast_land: int = -1


func _init() -> void:
	name = "PartyDriver"


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WEAPONS, Defs.Phase.PLAYER, Defs.Phase.POST])


func _sim_tick(phase: int) -> void:
	var level: LevelBase = Game.level
	if level == null or level.hero_count() <= 1:
		return
	match phase:
		Defs.Phase.WEAPONS:
			_weapons_step(level)
		Defs.Phase.PLAYER:
			_carry_riders(level)
			_head_contacts(level)
		Defs.Phase.POST:
			_post(level)


## WEAPONS, in one pass over the party (the multi-hero performance pass of phase 3; the same results as the former
## separate passes, whose steps never read each other's): who is ACTIVE, a Totem Ride whose rider or carrier became
## IDLE ends (G33), the
## edge-wall fence of every hero of the tribe (PlayerBase.clear_fence + fence_x written out), then the lee - skipped
## while there is no wind and no lee left over (it would only write 0 again).
func _weapons_step(level: LevelBase) -> void:
	var walls: Vector2i = Vector2i.ZERO if level.completed else level.get_edge_walls()
	var fence: bool = walls != Vector2i.ZERO
	# wf11 R6: the view is the view of the heroes who COUNT - it is a wall for them only. An idle hero (PlayerBase.idle)
	# is no wall for the view and no view is a wall for him while a partner plays; with nobody counting, everybody is
	# fenced as before.
	var somebody_counts: bool = false
	for hero: PlayerBase in level.contact_order():
		if not hero.dead and not hero.down and not hero.idle and _r6_on():
			somebody_counts = true
			break
	for hero: PlayerBase in level.contact_order():
		var bit: int = 1 << hero.slot
		if hero.dead or hero.down:
			active_mask &= ~bit
			continue
		if GameInput.get_flags(hero.slot) != 0:
			active_mask |= bit
		var carrier: PlayerBase = hero.totem_carrier
		if carrier != null and (hero.idle or carrier.idle):
			# G33: a Totem Ride needs two heroes who play. On the tick either becomes idle the rider falls through the
			# carrier's head (his yvel as it is, no drop lock: an idle head starts no new ride, an idle rider none).
			hero.end_totem_ride()
			hero.on_platform = false
			hero.grounded = false
		if fence and not (hero.idle and somebody_counts):
			# A hero who is outside the walls (a teleport, a snap of the view) may still walk back in, never further out.
			var x: int = hero.sim_pos.x
			hero._fenced = true
			hero._fence_clamp = false  # C.13: a step out of the walls is refused (a raft's rails clamp, C.7)
			hero._fence_left = mini(walls.x, x)
			hero._fence_right = maxi(walls.y, x + 1)
	if level.wind != 0 or level.lee_mask != 0 or _lee_sign != 0:
		_update_lee(level)


## A team wipe reset the world: arrivals at the exit, egg clocks and bounce memories start afresh.
func _on_level_reset() -> void:
	exit_mask = 0
	egg_ticks.fill(0)
	_relay_last.clear()
	wipe_pending = false
	active_mask = 0
	_egg_mask = 0
	idle_wipe_ticks = 0
	_lee_sign = 0
	var level: LevelBase = Game.level
	if level != null:
		level.lee_mask = 0


# =================================================================================================================
# Queries
# =================================================================================================================

## The heroes of H (PHYSICS.md C.13): alive (no death toss) and hatched (PlayerBase.down read directly: this runs
## about ten times per co-op tick).
func is_in_tribe(hero: PlayerBase) -> bool:
	return hero != null and not hero.dead and not hero.down


## The hero whose head `rider` stands on (Totem Ride), null when none.
func carrier_of(rider: PlayerBase) -> PlayerBase:
	return rider.totem_carrier if rider != null else null


## The hero standing on `carrier`'s head (Totem Ride), null when none.
func rider_of(carrier: PlayerBase) -> PlayerBase:
	return carrier.totem_rider if carrier != null else null


## True when `hero` is ACTIVE: hatched (in H), his own slot held some input flag (GameInput.get_flags) on a tick
## since he last became hatched - the level start, a team-wipe respawn or a hatch - and he is not IDLE (the phase-3
## IDLE rule, PlayerBase.is_idle: no input of his own for PlayerBase.IDLE_TICKS). Only an active partner's head gives
## the full Shoulder Hop (G1 resolution: the egg and the idle body that pops out of it are no springboard). A hatched
## partner who has not pressed anything since his hatch (not active, not IDLE either) still carries a Totem Ride; an
## IDLE one carries none (G33, [method _head_contacts]).
func is_active(hero: PlayerBase) -> bool:
	return is_in_tribe(hero) and not hero.idle \
			and (active_mask & (1 << clampi(hero.slot, 0, Defs.MAX_PLAYERS - 1))) != 0


## The IDLE rule (PlayerBase.is_idle; the query the boss forms asked for here, wf9_enemies_c_to_world_a.txt): true when
## `hero` is IDLE - no input of his own for PlayerBase.IDLE_TICKS, or none since he entered the level.
func is_idle(hero: PlayerBase) -> bool:
	return hero != null and hero.is_idle()


## (WEAPONS, [method _weapons_step]: a hero down or in his toss is inactive; a hatched hero becomes active on the first
## tick his slot holds any input flag. Every hatch the driver makes clears the bit too ([method _deactivate]), so an
## egg made and hatched inside one tick still pops out inactive; POST clears the bit of every hero who left the tribe
## during the tick ([method _post]).)
func _deactivate(hero: PlayerBase) -> void:
	if hero != null:
		active_mask &= ~(1 << clampi(hero.slot, 0, Defs.MAX_PLAYERS - 1))


## The first other hero of the party (slot order) who is alive and hatched, null when none: the partner an egg drifts
## after and a full hero's bones fly to.
func partner_of(hero: PlayerBase) -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	for other: PlayerBase in level.contact_order():
		if other != hero and is_in_tribe(other):
			return other
	return null


# =================================================================================================================
# WEAPONS: edge walls; Batter Up and the hatch by a box (called by the hero)
# =================================================================================================================

## (The edge walls: every hatched hero is fenced into LevelBase.get_edge_walls() in [method _weapons_step].)


## The lee (co-op gusts: the "lee leapfrog" of DESIGN.md 3-1b / 9-2; rule text proposed to the lead designer in
## build/engine_requests/wf8_world_a_to_lead_designer.txt #11). From the positions and states at the start of the
## tick, before any hero moves, LevelBase.lee_mask gets the bit of every hero of H who is sheltered on this tick, and
## his WIND primitive then feels no wind (LevelBase.wind_for):
##  - a WINDBREAK is a hero of H in the crouch state (5, not crawl) with ground or a platform under his feet;
##  - a hero of H is in its lee when his feet are downwind of the windbreak's (to its left while the wind blows left,
##    `wind > 0`; to its right for `wind < 0`) by 0 .. LEE_REACH_PX and at most LEE_DY_PX above or below them;
##  - a hero who was sheltered on the previous tick stays sheltered while he is airborne (a jump taken in the lee
##    crosses the gap in it) until he next has ground, a platform or a carrier under his feet, or the wind turns.
## No wind, a completed level or one hero of H: nobody is sheltered.
func _update_lee(level: LevelBase) -> void:
	var mask: int = 0
	var sign_now: int = signi(level.wind)
	if sign_now != 0 and not level.completed:
		var order: Array[PlayerBase] = level.contact_order()
		var carry: int = level.lee_mask if sign_now == _lee_sign else 0
		for hero: PlayerBase in order:
			if not is_in_tribe(hero):
				continue
			var bit: int = 1 << clampi(hero.slot, 0, Defs.MAX_PLAYERS - 1)
			if (carry & bit) != 0 and not hero.is_grounded():
				mask |= bit
			elif in_lee(order, hero, sign_now):
				mask |= bit
	level.lee_mask = mask
	_lee_sign = sign_now if mask != 0 else 0


## True when `hero` stands in the lee of a crouching partner of `order` for a wind of sign `wind_sign` (see
## [method _update_lee]). An IDLE partner (PlayerBase.counts_for_coop) is no windbreak.
func in_lee(order: Array[PlayerBase], hero: PlayerBase, wind_sign: int) -> bool:
	for windbreak: PlayerBase in order:
		if windbreak == hero or not windbreak.counts_for_coop() or windbreak.state != Defs.HeroState.CROUCH \
				or not windbreak.is_grounded():
			continue
		var downwind: int = (windbreak.sim_pos.x - hero.sim_pos.x) * wind_sign
		if downwind >= 0 and downwind <= LEE_REACH_PX \
				and absi(windbreak.sim_pos.y - hero.sim_pos.y) <= LEE_DY_PX:
			return true
	return false


## The hero's own WEAPONS pass starts here in a party (HeroParty.weapon_pass, PHYSICS.md C.0: "a box first tests
## curled partners (bat, C.11) and eggs (hatch, C.12), then enemies"): each of his live projectiles that overlaps an
## egg (weapon test) hatches it and is consumed; then his club box - a front frame (forward, high or low front) of a
## melee weapon (club, hammer) on a curled partner bats him (C.11 table, x3/2 when charged), else any frame on an
## egg hatches it - and the box is consumed (`club_box_active = false`), so it hits no enemy. Thrown weapons never bat.
func weapon_pass(hero: PlayerBase) -> void:
	var level: LevelBase = Game.level
	if level == null or hero == null or hero.dead or hero.down or level.hero_count() <= 1:
		return
	# Nothing to bat or hatch (no partner is an egg or curled - nearly every co-op tick): no projectile is looked at
	# (the multi-hero performance pass of phase 3; the steps below find nothing then).
	var targets: bool = false
	for other: PlayerBase in level.contact_order():
		if other != hero and not other.dead and (other.down or other.curl == PlayerBase.CURL_CURLED):
			targets = true
			break
	if not targets:
		return
	var hearts: int = PartyTuning.hatch_hearts(Game.difficulty)
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in projectiles.size():
		var shot: ProjectileBase = projectiles[i] as ProjectileBase
		if shot == null or shot.spent or shot.owner_slot != hero.slot:
			continue
		var egg: PlayerBase = _egg_under(level, hero, shot.sim_pos.x, shot.sim_pos.y, shot.box_w, shot.box_h,
				shot.box_xo)
		if egg != null:
			_deactivate(egg)
			egg.hatch(hero, hearts)
			egg_ticks[clampi(egg.slot, 0, egg_ticks.size() - 1)] = 0
			shot.consume()
	if not hero.club_box_active:
		return
	var box: Rect2i = hero.club_box
	var origin_x: int = box.position.x + hero.club_box_xo
	var batted: PlayerBase = _curled_under(level, hero)
	if batted != null:
		var launch: Vector2i = bat_launch(hero)
		batted.bat(launch.x, launch.y, hero)
		hero.club_box_active = false
		return
	var egg: PlayerBase = _egg_under(level, hero, origin_x, box.end.y, box.size.x, box.size.y, hero.club_box_xo)
	if egg != null:
		_deactivate(egg)
		egg.hatch(hero, hearts)
		egg_ticks[clampi(egg.slot, 0, egg_ticks.size() - 1)] = 0
		hero.club_box_active = false


## The Batter Up launch (xvel, yvel in v16) of `batter`'s current club box (PHYSICS.md C.11): forward front = line
## drive (+/-144, -128), high front = lob (+/-32, -240), low front = grounder (+/-96, 0), by his facing; x3/2 when the
## box was made charged (club_power above the weapon's base power), each component then clamped by
## PlayerBase.launch. Vector2i.ZERO for any other frame (no bat).
static func bat_launch(batter: PlayerBase) -> Vector2i:
	var launch: Vector2i = Vector2i.ZERO
	match club_frame_of(batter):
		Tuning.ClubFrame.FWD_FRONT:
			launch = Vector2i(PartyTuning.BAT_LINE_DRIVE_XVEL, PartyTuning.BAT_LINE_DRIVE_YVEL)
		Tuning.ClubFrame.HIGH_FRONT:
			launch = Vector2i(PartyTuning.BAT_LOB_XVEL, PartyTuning.BAT_LOB_YVEL)
		Tuning.ClubFrame.LOW_FRONT:
			launch = Vector2i(PartyTuning.BAT_GROUNDER_XVEL, 0)
		_:
			return Vector2i.ZERO
	launch.x *= batter.facing
	var weapon: int = clampi(batter.run.weapon, 0, Tuning.WEAPON_POWER.size() - 1)
	if batter.club_power > Tuning.WEAPON_POWER[weapon]:
		launch = Vector2i(PartyTuning.bat_charged(launch.x), PartyTuning.bat_charged(launch.y))
	return launch


## Club-box frame (Tuning.ClubFrame) of a hero's current box: Player.club_frame; NONE for a bare PlayerBase.
static func club_frame_of(hero: PlayerBase) -> int:
	var frame: Variant = hero.get(&"club_frame")
	return int(frame) if frame is int else Tuning.ClubFrame.NONE


## The first curled partner (slot order) that `hero`'s club box bats: a front frame of the club or the hammer.
func _curled_under(level: LevelBase, hero: PlayerBase) -> PlayerBase:
	var weapon: int = hero.run.weapon
	if weapon != Defs.Weapon.CLUB and weapon != Defs.Weapon.HAMMER:
		return null
	if bat_launch(hero) == Vector2i.ZERO:
		return null
	for other: PlayerBase in level.contact_order():
		if other == hero or other.dead or other.is_down() or other.curl != PlayerBase.CURL_CURLED:
			continue
		if Overlap.weapon(hero.club_box, hero.club_box_xo, other):
			return other
	return null


## The first egg (slot order, not `hero`) that a weapon box with feet point (x, y), size w x h and x offset xo
## overlaps (the weapon test against the egg's box, PartyTuning.EGG_BOX_*, at its feet point).
func _egg_under(level: LevelBase, hero: PlayerBase, x: int, y: int, w: int, h: int, xo: int) -> PlayerBase:
	for other: PlayerBase in level.contact_order():
		if other == hero or not other.is_down() or other.dead:
			continue
		if Overlap.test(x, y, w, h, xo, other.sim_pos.x, other.sim_pos.y, PartyTuning.EGG_BOX_W,
				PartyTuning.EGG_BOX_H, PartyTuning.EGG_BOX_XO, true):
			return other
	return null


# =================================================================================================================
# PLATFORMS and PLAYER: the Totem Ride and the head contacts (C.10)
# =================================================================================================================

## Step (a): every rider is carried by his carrier's motion of this tick (PlayerBase.carry_totem: it also ends the
## ride on a jump, a foot-reach miss or a scrape).
func _carry_riders(level: LevelBase) -> void:
	for rider: PlayerBase in level.contact_order():
		if rider.totem_carrier != null:
			rider.carry_totem()


## Step (b): new head contacts, every hero A in slot order against every other hero B in slot order, at most one per
## hero and tick (PlayerBase.land_on_partner tests A's conditions and the stomp contact, then hops, rides or hatches).
## An egg is no springboard (G1 resolution): a hatch by a stomp bounces Tuning.BOUNCE_YVEL (-64) whatever UP does
## (the hero side's rule, PlayerBase.land_on_partner), and A holding UP meets no hatched B that is not ACTIVE
## ([method is_active]): no Shoulder Hop off the idle body that pops out of an egg; A passes through as heroes do.
## IDLE rule (G33): no duo move uses an IDLE hero (PlayerBase.is_idle) - an idle A makes no head contact at all (no
## hop, ride or stomp hatch), and an idle hatched B is no platform: A passes through his head, UP held or not.
func _head_contacts(level: LevelBase) -> void:
	var order: Array[PlayerBase] = level.contact_order()
	for a: PlayerBase in order:
		if a.idle:
			continue
		# a.can_land_on_partner() is pure: asked only once a partner is near (phase-3 performance pass; -1 = not yet).
		var may_land: int = -1
		var apos: Vector2i = a.sim_pos
		for b: PlayerBase in order:
			if b == a or b.dead:
				continue
			# Overlap.body's coarse reject first (as land_on_partner's own first test): nearly every co-op tick the
			# two heroes are farther apart than any two boxes reach, and nothing below may happen then.
			var bpos: Vector2i = b.sim_pos
			if absi(apos.x - bpos.x) >= Tuning.OVERLAP_MAX_DX or absi(apos.y - bpos.y) >= Tuning.OVERLAP_MAX_DY:
				continue
			if may_land < 0:
				may_land = 1 if a.can_land_on_partner() else 0
			if may_land == 0:
				break
			if b.down:
				_deactivate(b)
			elif b.idle or (a.holds_up() and not is_active(b)):
				continue
			var result: int = a.land_on_partner(b)
			if result == PlayerBase.HEAD_HATCH:
				egg_ticks[clampi(b.slot, 0, egg_ticks.size() - 1)] = 0
			if result != PlayerBase.HEAD_NONE:
				break


## Totem Ride end for `rider` (both links cleared; safe when he does not ride).
func end_ride(rider: PlayerBase) -> void:
	if rider != null:
		rider.end_totem_ride()


# =================================================================================================================
# POST: thrown riders, the leash, the eggs, the team wipe
# =================================================================================================================

func _post(level: LevelBase) -> void:
	var order: Array[PlayerBase] = level.contact_order()
	for hero: PlayerBase in order:
		# A hero who left the tribe this tick is inactive (_make_egg below deactivates the ones it makes).
		if hero.dead or hero.down:
			active_mask &= ~(1 << hero.slot)
		var rider: PlayerBase = hero.totem_rider
		if rider == null:
			continue
		if not is_instance_valid(rider) or rider.totem_carrier != hero:
			hero.totem_rider = null
		elif not is_in_tribe(hero) or not is_in_tribe(rider):
			end_ride(rider)
	if not level.completed:
		_leash(level, order)
		_eggs(level, order)
	_wipe_check(level, order)


## C.13 leash: a hero of H whose feet are outside the authentic view for leash_egg_ticks in a row becomes an egg.
## wf11 ruling R6 "the leash takes the idle one": the tribe camera follows the heroes who COUNT (LevelCamera), so when
## the pair parts it is the IDLE hero (PlayerBase.is_idle) who is left off the view and becomes the egg. A hero who
## counts is never leashed while he is the only one who does - nobody is egged because his partner put the pad down
## (before, an idle partner standing below held the view and the leash took the climber). With two heroes who count,
## or none, the leash is what it was.
func _leash(level: LevelBase, order: Array[PlayerBase]) -> void:
	var frame: Rect2i = level.get_party_frame()
	var limit: int = PartyTuning.leash_egg_ticks(Game.difficulty)
	# Overlap.point_in(frame, x, y - 1) written out on the frame's edges (once per hero and co-op tick).
	var left: int = frame.position.x
	var top: int = frame.position.y + 1
	var right: int = left + frame.size.x
	var bottom: int = top + frame.size.y
	var counting: int = -1  # hatched heroes who count; asked once a hero is off the view (-1 = not yet)
	for hero: PlayerBase in order:
		if hero.dead or hero.down:
			hero.leash = 0
			continue
		var feet: Vector2i = hero.sim_pos
		if feet.x >= left and feet.x < right and feet.y >= top and feet.y < bottom:
			hero.leash = 0
			continue
		if not hero.idle and _r6_on():
			if counting < 0:
				counting = 0
				for other: PlayerBase in order:
					if not other.dead and not other.down and not other.idle:
						counting += 1
			if counting == 1:
				hero.leash = 0  # R6: the view is his alone; an idle partner never costs him his body
				continue
		hero.leash += 1
		if hero.leash >= limit:
			hero.leash = 0
			_make_egg(level, hero, &"leash", hero.sim_pos)


## C.12 eggs: the Expert return to the checkpoint, else the drift after the partner with the owner's nudge, clamped
## into the view.
func _eggs(level: LevelBase, order: Array[PlayerBase]) -> void:
	# The view and the return clock are only asked once an egg is met (nearly every co-op tick has none).
	var frame: Rect2i = Rect2i()
	var return_after: int = 0
	var asked: bool = false
	for egg: PlayerBase in order:
		var slot: int = clampi(egg.slot, 0, egg_ticks.size() - 1)
		if not egg.down or egg.dead:
			egg_ticks[slot] = 0
			continue
		if not asked:
			asked = true
			frame = level.get_party_frame()
			return_after = PartyTuning.egg_return_ticks(Game.difficulty)
		egg_ticks[slot] += 1
		var pos: Vector2i = egg.sim_pos
		if return_after >= 0 and egg_ticks[slot] > return_after:
			var home: Vector2i = level.get_respawn_pos()
			pos.x += clampi(home.x - pos.x, -PartyTuning.EGG_RETURN_SPEED_PX, PartyTuning.EGG_RETURN_SPEED_PX)
			pos.y += clampi(home.y - pos.y, -PartyTuning.EGG_RETURN_SPEED_PX, PartyTuning.EGG_RETURN_SPEED_PX)
			egg.sim_pos = pos
			continue
		var partner: PlayerBase = partner_of(egg)
		if partner != null:
			var target: Vector2i = partner.sim_pos \
					+ Vector2i(PartyTuning.EGG_OFFSET_X * partner.facing, PartyTuning.EGG_OFFSET_Y)
			pos.x += _drift_step(target.x - pos.x)
			pos.y += _drift_step(target.y - pos.y)
		var flags: int = GameInput.get_flags(egg.slot)
		if (flags & Defs.IN_LEFT) != 0 and (flags & Defs.IN_RIGHT) == 0:
			pos.x -= PartyTuning.EGG_NUDGE_PX
		elif (flags & Defs.IN_RIGHT) != 0 and (flags & Defs.IN_LEFT) == 0:
			pos.x += PartyTuning.EGG_NUDGE_PX
		egg.sim_pos = clamp_egg(pos, frame)


## One axis of the egg drift: up to EGG_DRIFT_PX towards the target, EGG_DRIFT_FAST_PX while farther than
## EGG_DRIFT_FAR_PX.
static func _drift_step(distance: int) -> int:
	var reach: int = PartyTuning.EGG_DRIFT_FAST_PX if absi(distance) > PartyTuning.EGG_DRIFT_FAR_PX \
			else PartyTuning.EGG_DRIFT_PX
	return clampi(distance, -reach, reach)


## An egg's feet point clamped so that its box (PartyTuning.EGG_BOX_*) lies PartyTuning.EGG_VIEW_INSET_PX inside
## `frame` (the authentic view).
static func clamp_egg(feet: Vector2i, frame: Rect2i) -> Vector2i:
	var inset: int = PartyTuning.EGG_VIEW_INSET_PX
	var left: int = frame.position.x + inset + PartyTuning.EGG_BOX_XO
	var right: int = frame.end.x - inset - (PartyTuning.EGG_BOX_W - PartyTuning.EGG_BOX_XO)
	var top: int = frame.position.y + inset + PartyTuning.EGG_BOX_H
	var bottom: int = frame.end.y - inset
	return Vector2i(clampi(feet.x, left, maxi(left, right)), clampi(feet.y, top, maxi(top, bottom)))


## The team wipe without a death toss (C.12): every hero is an egg (a leash or a voluntary egg while the partner was
## already down). A wipe that waits for a toss happens in LevelBase.hero_death_finished.
## wf11 R6 (6), "the wipe when the last COUNTING hero goes down": on the tick a hero who COUNTED (not idle) becomes an
## egg, the team is wiped too when nobody is left who counts - every other hero an egg or IDLE (PlayerBase.idle).
## Before, a player who went down beside a hatched partner whose pad lay on the table was an egg nobody could hatch.
## It is the going down of a hero who plays that wipes at once: an idle hero turning egg (the leash's catch) wipes
## nothing, and a hero who puts the pad down while his partner is an egg wipes nothing on that tick.
## Phase 4 ruling Q3 (DESIGN.md G86), "no dead end beside an idle partner": that last case was an egg that waited for
## ever. Now a clock runs while the party is at that dead end ([method _idle_dead_end], [member idle_wipe_ticks]) and
## after PartyTuning.IDLE_WIPE_TICKS such ticks in a row the team is wiped as when both are down.
func _wipe_check(level: LevelBase, order: Array[PlayerBase]) -> void:
	if wipe_pending or level.completed or order.is_empty():
		idle_wipe_ticks = 0
		return
	var eggs: int = 0
	var all_eggs: bool = true
	for hero: PlayerBase in order:
		if hero.down and not hero.dead:
			eggs |= 1 << hero.slot
		else:
			all_eggs = false
	var fresh: int = eggs & ~_egg_mask
	_egg_mask = eggs
	if not all_eggs:
		if not _r6_on():
			idle_wipe_ticks = 0
			return
		# The clock is counted on every tick (it falls to 0 on a tick that does not end at the dead end).
		var stuck: bool = _idle_dead_end(order, eggs)
		if not stuck and not (fresh != 0 and _last_counting_went_down(order, fresh)):
			return
	wipe_pending = true
	idle_wipe_ticks = 0
	level.team_wipe()


## wf11 R6 (6): true when the heroes of `fresh` (bit per slot: they became eggs on this tick) include one who COUNTED
## (not idle) and nobody is left who counts - every other hero an egg or IDLE - with no death toss running (a toss is
## LevelBase.hero_death_finished's to decide when it ends).
func _last_counting_went_down(order: Array[PlayerBase], fresh: int) -> bool:
	var counted: bool = false
	for hero: PlayerBase in order:
		if hero.dead:
			return false  # a toss is running: LevelBase.hero_death_finished decides when it ends
		if (fresh & (1 << hero.slot)) != 0:
			counted = counted or not hero.idle
		elif not hero.down and not hero.idle:
			return false  # somebody still plays
	return counted


## Phase 4 ruling Q3 (DESIGN.md G86): one tick of the dead-end clock; true on the tick it reaches
## PartyTuning.IDLE_WIPE_TICKS (the caller wipes the team). THE DEAD END (`eggs`: bit per slot of the heroes who are
## eggs at the end of this tick; the caller has seen that not every hero is one): some hero is an egg whose OWN PLAYER
## PLAYS - his slot gave input within PlayerBase.IDLE_TICKS (PlayerBase.idle is false; an egg's nudge and any held key
## are input) - while every hatched hero is IDLE, so nobody can hatch him, and no hero is in his death toss (the toss
## decides first, as ever). Each such tick adds one to [member idle_wipe_ticks]; every other tick - a hatched hero's
## key, a hatch, a toss, the egg's own player leaving his pad - puts it back to 0. Two pads on the table never start
## it: an egg whose player is away is stuck for nobody, and the wipe is the stuck player's way out, not a fee for a
## rest. PartyTuning.IDLE_WIPE_TICKS <= 0 switches the rule off. No picture, no sound: the "Zzz" over the dozing
## hero is the warning (G58).
func _idle_dead_end(order: Array[PlayerBase], eggs: int) -> bool:
	var stuck: bool = eggs != 0 and PartyTuning.IDLE_WIPE_TICKS > 0
	if stuck:
		var plays: bool = false
		for hero: PlayerBase in order:
			if hero.dead:
				stuck = false  # a death toss is running
				break
			if hero.down:
				plays = plays or not hero.idle
			elif not hero.idle:
				stuck = false  # a hatched hero counts: he can hatch the egg
				break
		stuck = stuck and plays
	if not stuck:
		idle_wipe_ticks = 0
		return false
	idle_wipe_ticks += 1
	return idle_wipe_ticks >= PartyTuning.IDLE_WIPE_TICKS


## `hero` becomes an egg at `at` clamped into the view (no toss; PHYSICS.md C.12, C.13).
func _make_egg(level: LevelBase, hero: PlayerBase, cause: StringName, at: Vector2i) -> void:
	var rider: PlayerBase = hero.totem_rider
	if rider != null:
		end_ride(rider)
	if hero.totem_carrier != null:
		end_ride(hero)
	_deactivate(hero)
	hero.go_down(cause)
	hero.teleport(clamp_egg(at, level.get_party_frame()))
	egg_ticks[clampi(hero.slot, 0, egg_ticks.size() - 1)] = 0


# =================================================================================================================
# Deaths, the team exit, gate travel, the checkpoint, bones (calls of other modules)
# =================================================================================================================

## LevelBase.hero_death_finished asks this first (LevelBase.register_party_driver): `hero`'s death toss is over. While
## another hero of the party is alive and hatched he becomes an egg where his toss STARTED, clamped into the view
## (C.12) - true. Otherwise false: the level's default waits for the last toss and wipes the team. wf11 R6 (6): false
## too when `hero` COUNTED (not idle) and every hatched partner is IDLE - the last counting hero went down.
func handle_hero_death(hero: PlayerBase) -> bool:
	var level: LevelBase = Game.level
	if level == null or hero == null or partner_of(hero) == null:
		return false
	if not hero.idle and _r6_on() and not _another_counts(level, hero):
		return false  # wf11 R6 (6): he played, his partner is hatched but IDLE - nobody could hatch this egg: a wipe
	var cause: Variant = hero.get(&"death_cause")
	_make_egg(level, hero, StringName(cause) if cause is StringName or cause is String else &"death",
			death_origin(hero))
	return true


## False only while R6 is switched off for a measurement (PlayerBase.gate_rules_off).
static func _r6_on() -> bool:
	return (PlayerBase.gate_rules_off & PlayerBase.GATE_R6) == 0


## True when a hero of the party other than `hero` COUNTS (alive, hatched, not idle - PlayerBase.counts_for_coop).
func _another_counts(level: LevelBase, hero: PlayerBase) -> bool:
	for other: PlayerBase in level.contact_order():
		if other != hero and not other.dead and not other.down and not other.idle:
			return true
	return false


## Where `hero`'s death toss started: Player.death_origin when the hero side records it, else the toss walked back
## from its current tick (Player.death_ticks and the toss step of PHYSICS.md 10.4).
static func death_origin(hero: PlayerBase) -> Vector2i:
	var origin: Variant = hero.get(&"death_origin")
	if origin is Vector2i:
		return origin
	var ticks: Variant = hero.get(&"death_ticks")
	var dx: Variant = hero.get(&"_death_dx")
	if not (ticks is int) or not (dx is int):
		return hero.sim_pos
	var dy: int = 0
	var vy: int = Tuning.DEATH_VY_START
	for i: int in int(ticks):
		dy += vy
		vy = mini(vy + 1, Tuning.DEATH_VY_MAX)
	return hero.sim_pos - Vector2i(int(dx) * int(ticks), dy)


## Team exit (GAMEPLAY.md 13.9.2): `hero` touches the open exit `exit`. He is recorded as arrived (his controls
## freeze: he waits at the totem); true when the whole team is at the exit now - every other hero arrived, or is an
## egg on the view - and the exit should end the level. Idempotent; an egg or a dead hero arrives nowhere.
func exit_touched(_exit: SimEntity, hero: PlayerBase) -> bool:
	if hero != null and is_in_tribe(hero):
		if not is_at_exit(hero):
			exit_mask |= 1 << clampi(hero.slot, 0, Defs.MAX_PLAYERS - 1)
			hero.xvel = 0
			hero.set_control_enabled(false)
	return team_at_exit()


## True once `hero` reached the exit and waits for his team.
func is_at_exit(hero: PlayerBase) -> bool:
	return hero != null and (exit_mask & (1 << clampi(hero.slot, 0, Defs.MAX_PLAYERS - 1))) != 0


## True when some hero arrived at the exit and every other hero arrived too or is an egg on the view. IDLE rule (G33,
## lead designer's ruling of phase 3): the exit waits only for heroes who play - an IDLE hatched hero (PlayerBase.
## is_idle) on the view counts as present, as an egg on the view does (an AFK partner never blocks the exit; off the
## view the leash makes him an egg anyway). A hero in his death toss is never present (the totem waits).
func team_at_exit() -> bool:
	var level: LevelBase = Game.level
	if level == null or exit_mask == 0:
		return false
	var frame: Rect2i = level.get_party_frame()
	for hero: PlayerBase in level.contact_order():
		if is_at_exit(hero):
			continue
		if (hero.down or hero.idle) and not hero.dead and frame.has_point(hero.sim_pos - Vector2i(0, 1)):
			continue
		return false
	return true


## Gate travel (GAMEPLAY.md 13.9.2): `user` went through a gate from `from_pos` and arrived at `to_pos` (the gate
## already moved him). Every other hero comes along, PartyTuning.RESPAWN_SPREAD_PX per place behind him towards the
## side where the floor continues: hatched when he was within one view of `from_pos` (PartyTuning.GATE_PARTNER_RANGE_PX
## across, Tuning.VIEW_ROWS rows up or down), otherwise - and when he was an egg already - as an egg. A hero in his
## death toss stays where he is. Each is moved with no interpolation and notify_hero_teleported.
func travel_party(user: PlayerBase, from_pos: Vector2i, to_pos: Vector2i) -> void:
	var level: LevelBase = Game.level
	if level == null or user == null:
		return
	if user.totem_carrier != null:
		end_ride(user)
	var place: int = 0
	for hero: PlayerBase in level.contact_order():
		if hero == user or hero.dead:
			continue
		place += 1
		if hero.totem_carrier != null:
			end_ride(hero)
		var far: bool = absi(hero.sim_pos.x - from_pos.x) > PartyTuning.GATE_PARTNER_RANGE_PX \
				or absi(hero.sim_pos.y - from_pos.y) > Tuning.VIEW_ROWS * Tuning.TILE
		var dest: Vector2i = level.party_spread_point(to_pos, place)
		hero.xvel = 0
		hero.yvel = 0
		if hero.is_down() or far:
			_deactivate(hero)
			if not hero.is_down():
				hero.go_down(&"gate")
				egg_ticks[clampi(hero.slot, 0, egg_ticks.size() - 1)] = 0
			hero.teleport(Vector2i(dest.x, dest.y + PartyTuning.EGG_OFFSET_Y))
		else:
			hero.teleport(dest)
		hero.leash = 0
		level.notify_hero_teleported(hero)


## The shared checkpoint (C.12 c): every egg hatches in place (PartyTuning.hatch_hearts). Returns how many.
func hatch_all(by: PlayerBase) -> int:
	var level: LevelBase = Game.level
	if level == null:
		return 0
	var count: int = 0
	for hero: PlayerBase in level.contact_order():
		if hero.is_down() and not hero.dead:
			_deactivate(hero)
			hero.hatch(by, PartyTuning.hatch_hearts(Game.difficulty))
			egg_ticks[clampi(hero.slot, 0, egg_ticks.size() - 1)] = 0
			count += 1
	return count


## Bones picked up by `hero` at full energy fly to the partners below full energy (GAMEPLAY.md 13.9.2), in slot
## order: up to `count` bones, each partner until his hearts are full. Returns how many were given (0 = nobody
## needed them; the caller then keeps the 1.0 rule).
func bones_to_partner(hero: PlayerBase, count: int) -> int:
	var level: LevelBase = Game.level
	if level == null or count <= 0:
		return 0
	var given: int = 0
	for partner: PlayerBase in level.contact_order():
		if partner == hero or not is_in_tribe(partner):
			continue
		while given < count and not partner.run.is_full_energy():
			given += 1
			if partner.run.add_bones(1) > 0:
				Events.popup_requested.emit(&"heart", 1, Vector2i(partner.sim_pos.x, partner.sim_pos.y - partner.box_h))
		if given >= count:
			break
	return given


## Relay Bounce (GAMEPLAY.md 13.9.8; EnemyBase.on_bounced asks it in a party): the bounce count of `enemy` after a
## bounce by `hero`, given the count `count` before it. Below Tuning.BOUNCE_COUNT_MAX it rises as in 1.0; past it, in
## a co-op Feast Land only, it rises (up to RELAY_COUNT_MAX) only when `hero` is not the hero of the previous bounce
## and is not IDLE (PlayerBase.is_idle: a dozing body dropped on the enemy relays nothing).
func relay_bounce_count(enemy: SimEntity, hero: PlayerBase, count: int) -> int:
	var id: int = enemy.get_instance_id() if enemy != null else 0
	var last: int = int(_relay_last.get(id, -1))
	if hero != null and not hero.idle:
		_relay_last[id] = hero.slot
	if count < Tuning.BOUNCE_COUNT_MAX or not relay_active():
		return mini(count + 1, Tuning.BOUNCE_COUNT_MAX)
	if hero == null or last < 0 or last == hero.slot or hero.idle:
		return mini(count, RELAY_COUNT_MAX)
	return mini(count + 1, RELAY_COUNT_MAX)


## The score multiplier of a bounce count with the Relay Bounce: Tuning.bounce_multiplier up to 11, then x10 for
## 12-13 and x12 for 14-15.
static func relay_multiplier(count: int) -> int:
	if count <= Tuning.BOUNCE_COUNT_MAX:
		return Tuning.bounce_multiplier(count)
	var steps: Array[int] = PartyTuning.RELAY_BOUNCE_MULTIPLIERS
	return steps[clampi((count - Tuning.BOUNCE_COUNT_MAX - 1) / 2, 0, steps.size() - 1)]


## True in a co-op Feast Land with a party (the Relay Bounce rule is on).
func relay_active() -> bool:
	var level: LevelBase = Game.level
	if level == null or level.hero_count() <= 1 or Game.mode != Defs.GameMode.COOP:
		return false
	if _feast_land < 0:
		var kind: String = str(level.meta.get("kind", ""))
		var base: String = str(level.meta.get("coop_of", ""))
		var feast: bool = kind == FEAST_KIND
		if kind == "coop" and not base.is_empty():
			feast = Levels.get_level_kind(StringName(base)) == FEAST_KIND or base.begins_with("bonus")
		_feast_land = 1 if feast else 0
	return _feast_land == 1
