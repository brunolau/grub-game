extends "res://tools/autoplay/recorders/d7/squid_pilot.gd"
## D7: one hero of the co-op Tentacle Lock (DESIGN.md B.3, v2 of build/d7/squid_duo.gd). P1 (`side` -1) takes the flank
## left of the gap the squid comes up in, P2 (`side` +1) the flank right of it, both FLANK px out (34 is the body's
## touch distance, 55 the high strike's reach of the tentacle). While it dives both wait on the middle island; the
## bubbles name the gap and the outer hero jumps it at once (the squid is under water and harmless). Up, the hero the
## tentacle marks steps outward clear of it and comes back once it slammed; the other strikes high at once and keeps
## the cadence (Up + Strike 9 ticks, released 2: every strike refreshes his tentacle's flinch), so the head opens on
## the first strike of the marked hero and the next strikes hit it. Every walk brakes for its stopping distance (no
## overshoot). Phase 3 keeps the solo rule: the solo pilot.

const FLANK: int = 37
var side: int = -1
## The middle island's centre x.
var mid_x: int = 0
var _cad: int = 0
var _tap: int = 0


func flags(hero: PlayerBase, squid: Squid, level: LevelBase) -> int:
	if hero == null or hero.dead or squid == null or squid.dead:
		return 0
	if squid.get_phase() == 3 or squid.is_whirlpool():
		return super.flags(hero, squid, level)
	var x: int = hero.sim_pos.x
	var grounded: bool = hero.is_grounded()
	if _jump > 0:
		if grounded and _jump > 2:
			_jump = 0
		else:
			_jump += 1
			var up: int = Defs.IN_UP if _jump <= _jump_hold else 0
			if absi(_jump_goal - x) <= 4:
				return up
			return up | (Defs.IN_RIGHT if _jump_goal > x else Defs.IN_LEFT)
	var state: int = squid.get_state()
	var spot: int = squid.get_spot()
	var known: bool = spot >= 0 and (state == Squid.State.BUBBLES or state == Squid.State.RISE \
			or state == Squid.State.UP or state == Squid.State.SINK)
	var up_now: bool = state == Squid.State.RISE or state == Squid.State.UP or state == Squid.State.SINK
	var flank: int = spot + side * FLANK
	var goal: int = mid_x + side * 10
	var mark: int = squid.get_slam_mark()
	var slam: Rect2i = squid.get_slam_rect()
	var danger: int = mark if mark >= 0 else (slam.get_center().x if slam.size.x > 0 else -1)
	# wf10 (bosses): a strike reaches 20 px past the hero's front - no strike while a slam is marked or down this
	# near (the old margin let the club box poke into the slam: a bone on most surfacings)
	var threatened: bool = danger >= 0 and absi(danger - x) < SLAM_CLEAR + 16
	if known:
		goal = flank
		if danger >= 0 and absi(danger - flank) < SLAM_CLEAR + 2:
			# the tentacle marks my flank: wait outward, clear of it, until it slammed
			goal = danger + side * (SLAM_CLEAR + 3)
	if grounded and not _same_ground(level, squid, x, goal):
		# another island: jump the gap, never while the squid is up in it
		if up_now and _passes(x, goal, spot):
			return 0
		return _walk(level, squid, hero, goal)
	if absi(goal - x) > 3 or hero.xvel != 0 or not grounded:
		if hero.is_striking() and not threatened:
			return 0
		return _approach(hero, goal)
	var face: int = (1 if spot >= x else -1) if known else -side
	# wf10: no turn on the spot while a slam is marked or down this near (a turning hero's box widens into it)
	if hero.facing != face and not hero.is_striking() and not threatened:
		return Defs.IN_RIGHT if face > 0 else Defs.IN_LEFT
	# strike once the tentacle has picked its mark (UP tick SQUID_TENTACLE_AT): a strike locks him 9 ticks, so one
	# started before it marks his spot would keep him under it
	var marked: bool = squid.get_state_ticks() > Squid.SQUID_TENTACLE_AT
	if state == Squid.State.UP and marked and absi(x - flank) <= 4 and not threatened:
		_cad += 1
		return (Defs.IN_UP | Defs.IN_FIRE) if (_cad - 1) % 11 < 9 else 0
	_cad = 0
	return 0


## Walk on this ground towards `goal` and stop on it: coast once the stopping distance covers the rest, brake by
## letting go when moving away, a one-tick tap for the last few px.
func _approach(hero: PlayerBase, goal: int) -> int:
	var x: int = hero.sim_pos.x
	var dx: int = goal - x
	var speed: int = absi(hero.xvel)
	if not hero.is_grounded():
		return 0
	if hero.xvel != 0 and signi(hero.xvel) != signi(dx):
		return 0
	var stop: int = (speed * speed) / (2 * 12 * 16) + 2
	if hero.xvel != 0 and absi(dx) <= stop:
		return 0
	if absi(dx) <= 3:
		return 0
	if speed == 0 and absi(dx) < 10:
		if _tap > 0:
			_tap -= 1
			return 0
		_tap = 3
	return Defs.IN_RIGHT if dx > 0 else Defs.IN_LEFT
