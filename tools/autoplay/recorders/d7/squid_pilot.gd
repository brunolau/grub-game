extends RefCounted
## D7 copy of tests/test_enemies_squid.gd SquidBot (enemies-B): the closed-loop club pilot of the solo Inkjaw,
## with the surface row of the grotto as a variable (the test grotto has it at y 144).


const SIDE_DX: int = 37
var SURFACE_Y: int = 144
## Clear of the slam box (12 px either side of its mark) with the hero's half width (16), and a px.
const SLAM_CLEAR: int = 29
## Never this close to the squid's spot while it occupies it (a dodge slides a few px on).
const SQUID_CLEAR: int = 34
## Where it waits: at least this far from the edges of the islands (a run takes a few px to stop).
const SLIDE_MARGIN: int = 12
## A dodge starts from a stand: less slide.
const DODGE_MARGIN: int = 6
## Up held this long for a jump over a gap: a short hop (a full jump overshoots a 64 px island).
const GAP_JUMP_HOLD: int = 5
var attack: bool = true
## D7: in phase 3 settle on the right island (the exit's side).
var prefer_right: bool = false
var _jump: int = 0
var _jump_flags: int = 0
var _jump_hold: int = 9
## Where the running jump should land (it steers there in the air, pressing back once past it).
var _jump_goal: int = 0

func flags(hero: PlayerBase, squid: Squid, level: LevelBase) -> int:
	if hero == null or hero.dead or squid == null or squid.dead:
		return 0
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
	var spot: int = squid.get_spot()
	var state: int = squid.get_state()
	var occupied: bool = state == Squid.State.BUBBLES or state == Squid.State.RISE or state == Squid.State.UP \
			or state == Squid.State.SINK
	# Phase 3 will sink the middle island (after the next dive and a 22-tick rumble): off it, to the nearer side
	# island, and never back.
	var sinking: bool = squid.get_phase() == 3 and not squid.is_whirlpool()
	# D7: the stage's exit totem and the fire-starter end up on the right island, and once the middle island has sunk
	# nothing on foot leads there: in phase 3 the hero settles on the right island (from wherever he is).
	if sinking and grounded and prefer_right and squid._island.x >= 0 and x < (squid._island.y + 1) * 16 + 12:
		return _go(level, squid, hero, _side_island_x(level, squid, x), spot, occupied)
	if sinking and _on_middle(squid, x) and grounded:
		return _go(level, squid, hero, _side_island_x(level, squid, x), spot, occupied)
	# Out from under the tentacle: on foot, on the same ground, not towards the squid.
	var mark: int = squid.get_slam_mark()
	var slam: Rect2i = squid.get_slam_rect()
	var danger: int = mark if mark >= 0 else (slam.get_center().x if slam.size.x > 0 else -1)
	if squid.is_whirlpool():
		danger = -1  # the whirlpool's slam strikes the raft and hurts nobody
	if danger >= 0 and absi(danger - x) < SLAM_CLEAR and grounded:
		# Outward (away from the squid) first.
		var out: int = -1 if danger < spot else 1
		var best: int = -1
		for c: int in [danger + out * SLAM_CLEAR, danger - out * SLAM_CLEAR]:
			if not _same_ground(level, squid, x, c) or not _roomy(level, squid, c, DODGE_MARGIN):
				continue
			if occupied and absi(c - spot) < SQUID_CLEAR:
				continue
			best = c
			break
		if best >= 0:
			return _step(x, best)
		return 0
	var target: int = _target_x(hero, squid, level, spot, sinking)
	if absi(x - target) > 3 or not grounded:
		return _go(level, squid, hero, target, spot, occupied)
	var face: int = 1 if spot >= x else -1
	if hero.facing != face and not hero.is_striking():
		return Defs.IN_RIGHT if face > 0 else Defs.IN_LEFT
	# Strike once this surfacing's slam is over (a strike locks him 9 ticks: started before the tentacle marks his
	# spot, it would keep him under it); the squid stays up long enough for one hit after it.
	var slam_over: bool = squid.get_state_ticks() > Squid.SQUID_TENTACLE_AT and squid.get_slam_mark() < 0 \
			and squid.get_slam_rect().size.x == 0
	if attack and state == Squid.State.UP and slam_over:
		if squid.hit_cooldown <= 6 or hero.is_striking():
			return Defs.IN_UP | Defs.IN_FIRE
	return 0

## D7: walk to goal after the fight (jumps the gaps with the pilot's jump continuation).
func walk_to(level: LevelBase, squid: Squid, hero: PlayerBase, goal: int) -> int:
	var x: int = hero.sim_pos.x
	if _jump > 0:
		if hero.is_grounded() and _jump > 2:
			_jump = 0
		else:
			_jump += 1
			var up: int = Defs.IN_UP if _jump <= _jump_hold else 0
			if absi(_jump_goal - x) <= 4:
				return up
			return up | (Defs.IN_RIGHT if _jump_goal > x else Defs.IN_LEFT)
	return _walk(level, squid, hero, goal)

## The strike spot beside the squid's spot on the side the hero is on (the other side when that one is water).
func _target_x(hero: PlayerBase, squid: Squid, level: LevelBase, spot_x: int, no_middle: bool) -> int:
	var side: int = -1 if hero.sim_pos.x < spot_x else 1
	var near: int = spot_x + side * SIDE_DX
	if _roomy(level, squid, near) and not (no_middle and _on_middle(squid, near)):
		return near
	var far: int = spot_x - side * SIDE_DX
	if _roomy(level, squid, far) and not (no_middle and _on_middle(squid, far)):
		return far
	return hero.sim_pos.x

## True when x lies over the middle island (the one the whirlpool sinks).
static func _on_middle(squid: Squid, x: int) -> bool:
	var col: int = Tuning.to_cell(x)
	return squid._island.x >= 0 and col >= squid._island.x and col <= squid._island.y

## The nearest roomy spot of a side island (not the middle one), searched outwards from x.
func _side_island_x(level: LevelBase, squid: Squid, x: int) -> int:
	if prefer_right and squid._island.x >= 0:
		var start: int = (squid._island.y + 1) * 16 + 4
		for c: int in range(maxi(start, x), start + 240, 4):
			if not _on_middle(squid, c) and _roomy(level, squid, c):
				return c
	for k: int in range(16, 200, 4):
		for candidate: int in [x - k, x + k]:
			if not _on_middle(squid, candidate) and _roomy(level, squid, candidate):
				return candidate
	return x

## True when going from `a` to `b` passes within SQUID_CLEAR of `spot_x`.
static func _passes(a: int, b: int, spot_x: int) -> bool:
	return mini(a, b) - SQUID_CLEAR < spot_x and spot_x < maxi(a, b) + SQUID_CLEAR

## Walk (jumping water on the way) towards `goal`; while the squid occupies its spot it never goes past it.
func _go(level: LevelBase, squid: Squid, hero: PlayerBase, goal: int, spot_x: int, occupied: bool) -> int:
	var x: int = hero.sim_pos.x
	if occupied and _passes(x, goal, spot_x) and not _same_ground(level, squid, x, goal):
		return 0
	return _walk(level, squid, hero, goal)

static func _step(x: int, goal: int) -> int:
	if absi(goal - x) <= 2:
		return 0
	return Defs.IN_RIGHT if goal > x else Defs.IN_LEFT

## True when every x from `a` to `b` is island ground: no water between.
func _same_ground(level: LevelBase, squid: Squid, a: int, b: int) -> bool:
	var step: int = 4 if b >= a else -4
	var x: int = a
	while (step > 0 and x <= b) or (step < 0 and x >= b):
		if not _standable(level, squid, x):
			return false
		x += step
	return _standable(level, squid, b)

## Ground under x and `margin` px either side of it: a spot he can stop on from a run.
func _roomy(level: LevelBase, squid: Squid, x: int, margin: int = SLIDE_MARGIN) -> bool:
	return _standable(level, squid, x - margin) and _standable(level, squid, x) and _standable(level, squid, x + margin)

## Island ground under the feet at x.
func _island(level: LevelBase, x: int) -> bool:
	var grid: TileGrid = level.grid
	return TileGrid.is_ground(grid.floor_at(Tuning.to_cell(x), Tuning.to_cell(SURFACE_Y))) \
			and grid.get_char(Tuning.to_cell(x), Tuning.to_cell(SURFACE_Y)) != TileGrid.CH_LIQUID

## Ground under the feet at x: island ground only. He never boards a raft - walking onto one from an island drowns
## him (his feet leave the island before the raft's ride test can carry him: it carries a hero only while
## raft x - 24 < his x < raft x + 16, PHYSICS.md 11.4), and a jump onto one may miss it as it drifts; the squid
## surfaces beside the islands as well.
func _standable(level: LevelBase, _squid: Squid, x: int) -> bool:
	return _island(level, x)

## Walk towards `goal`; at the edge of the ground jump the water ahead when there is ground beyond it (and the goal
## lies beyond), else stop at the edge.
func _walk(level: LevelBase, squid: Squid, hero: PlayerBase, goal: int) -> int:
	var x: int = hero.sim_pos.x
	if absi(goal - x) <= 3:
		return 0
	var dir: int = 1 if goal > x else -1
	var dir_flag: int = Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
	if not hero.is_grounded() or _standable(level, squid, x + dir * 14):
		return dir_flag
	if absi(goal - x) > 20 and _standable(level, squid, x + dir * 46):
		_jump = 1
		_jump_flags = dir_flag
		_jump_hold = GAP_JUMP_HOLD
		# Land on the far island's first roomy spot (on the way to the goal), not beyond it.
		_jump_goal = goal
		for k: int in range(30, 200, 4):
			var land: int = x + dir * k
			if (dir > 0 and land > goal) or (dir < 0 and land < goal):
				break
			if _roomy(level, squid, land):
				_jump_goal = land
				break
		return dir_flag | Defs.IN_UP
	return 0

