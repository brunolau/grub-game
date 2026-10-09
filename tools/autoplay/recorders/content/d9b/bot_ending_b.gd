extends "res://tools/autoplay/recorders/content/d9b/botlib.gd"
## D9b: the route of ending_b (The Long Raft Home): onto the hoard's hatch planks, crouch to drop aboard, push off
## (strikes towards the shore), ride, three high strikes at the big spot under the arch (Cave Painting 19), ride home
## to the welcome totem. Co-op (players=2): both do the same, P2 a few px behind, both strike and walk.
## content (wf10): the totem stands on the home beach (G45): ride until the raft docks at the bank (at rest, its rails
## open over the beach), then walk off the raft onto the sand to the totem (co-op: P1 first, P2 behind him).

const ARCH_SPOT: Vector2i = Vector2i(147, 16)
const ARCH_SPOT_X: int = 147 * 16 + 8
const EXIT_X: int = 173 * 16 + 8
## The raft's centre docked at the home beach (bank col 172, width 4).
const DOCK_X: int = 172 * 16 - 32
const HATCH_X: Array[int] = [126, 114]
## The raft's centre in the calm pool under the arch.
const POOL_X: int = 146 * 16

var trace: bool = false
## Co-op: the tick of each slot's last input of its own (any flag), across commands - the idle rule (G33) counts
## from there, so a waiting rider taps Down after KEEPALIVE quiet ticks whatever command he is in.
var _last_in: Dictionary = {}
const KEEPALIVE: int = 140


func flags(p_level: LevelBase, tick: int) -> PackedInt32Array:
	var out: PackedInt32Array = super.flags(p_level, tick)
	for s: int in out.size():
		if out[s] != 0:
			_last_in[s] = tick
	return out


## A one-tick Down when this rider gave no input for KEEPALIVE ticks (co-op), else `solo` (the recorded solo taps).
func _tap(h: PlayerBase, solo: int) -> int:
	if players == 1:
		return solo
	return D if t - int(_last_in.get(h.slot, t)) >= KEEPALIVE else 0


func header() -> String:
	if players > 1:
		return "# route: level=ending_b_coop difficulty=expert players=2 ends=exit after=the_end expect=wipes:0,eggs:0,painting:19,secrets:1\n"
	return "# route: level=ending_b difficulty=expert ends=exit after=the_end expect=painting:19,secrets:1,hurts:0\n"


func raft(lv: LevelBase) -> Raft:
	for entity: SimEntity in lv.get_kind(Defs.Kind.PLATFORM):
		if entity is Raft:
			return entity as Raft
	return null


func _spot(lv: LevelBase) -> HittableBase:
	for entity: SimEntity in lv.get_kind(Defs.Kind.HITTABLE):
		var hs: HittableBase = entity as HittableBase
		if hs != null and hs.cell == ARCH_SPOT:
			return hs
	return null


## Ride (the raft carries him) until the raft's centre passes x; every `tap` ticks a one-tick Down (input of his own:
## the idle rule) - a crouch on the raft changes nothing.
func ride_fn(x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var r: Raft = raft(lv)
		if trace and n % 120 == 0:
			print("R t=%d P%d (%d,%d) g%d raft %s rx%d" % [t, h.slot + 1, h.sim_pos.x, h.sim_pos.y,
				int(h.is_grounded()), str(r.sim_pos) if r != null else "-", r.rx if r != null else 0])
		if r == null or r.sim_pos.x >= x or n > 9000 or (Game.level != null and Game.level.completed):
			return -1
		return _tap(h, D if n % 150 == 149 else 0)


## Paddle: `strokes` forward strikes facing left (the raft goes right), then face right again.
func paddle(strokes: int) -> Array:
	var p: Array = []
	p.append(["face", -1])
	for i: int in strokes:
		p.append(["strike", 0])
		p.append(["wait", 4])
	p.append(["face", 1])
	return p


## In the calm pool under the arch: step under the spot (never past the raft's carried part) and strike high until
## it opens.
func arch_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var spot: HittableBase = _spot(lv)
		if spot == null or spot.opened or n > 600:
			return -1
		var st: Dictionary = _st[h.slot]
		var dx: int = ARCH_SPOT_X - h.sim_pos.x
		if bool(st.get("pressed", false)):
			st["pressed"] = false
			return 0
		if not h.is_grounded() or h.is_striking():
			return 0
		if dx > 24:
			return R
		if dx < 12:
			return L
		if h.facing < 0:
			return R
		st["pressed"] = true
		return U | F


## Stand still under the falling painting (it drops onto the raft) until it is caught.
func catch_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var paint: SimEntity = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
			if entity is Painting:
				paint = entity
		if (paint == null and n > 20) or n > 200:
			return -1
		var r: Raft = raft(lv)
		# content (wf10): a waiting co-op rider taps Down after KEEPALIVE quiet ticks here too (G58: the "Zzz soon"
		# bubble shows from the 170th quiet tick); solo unchanged.
		if paint == null or r == null:
			return _tap(h, 0)
		# Step towards it, but only inside the raft's safe middle (today's bow strip drowns: wf9_d9b_to_objects-B).
		var goal: int = clampi(paint.sim_pos.x, r.sim_pos.x - 18, r.sim_pos.x + 10)
		if absi(goal - h.sim_pos.x) <= 3:
			return _tap(h, 0)
		return R if goal > h.sim_pos.x else L


func program(slot: int) -> Array:
	var p: Array = []
	p.append(["mark", "the jetty"])
	if slot == 1:
		# P2 waits on the wooden plank until P1 is aboard and has made room (no landing on his head).
		p.append(["go", 100, {"tol": 2}])
		p.append(["fn", func(lv: LevelBase, hh: PlayerBase, n: int) -> int:
			var p1: PlayerBase = hero(0)
			if (p1.is_grounded() and p1.sim_pos.y > 290 and p1.sim_pos.x >= 142) or n > 400:
				return -1
			return D if n % 60 == 30 else 0])
	p.append(["go", HATCH_X[slot], {"tol": 2}])
	p.append(["mark", "drop aboard"])
	p.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
		return hh.is_grounded() and hh.sim_pos.y > 290, D])
	p.append(["wait", 4])
	if slot == 0 and players > 1:
		p.append(["go", 144, {"tol": 2}])
	if players > 1:
		p.append(["sync", "aboard"])
	if slot == 0:
		p.append(["mark", "push off"])
		p.append_array(paddle(3))
	p.append(["mark", "the credits"])
	p.append(["fn", ride_fn(POOL_X)])
	if slot == 0:
		p.append(["mark", "the arch"])
		p.append(["fn", arch_fn()])
		p.append(["fn", catch_fn()])
		p.append(["mark", "paddle on"])
		p.append_array(paddle(6))
		p.append(["mark", "pool left"])
	else:
		p.append(["fn", func(lv: LevelBase, hh: PlayerBase, n: int) -> int:
			var r: Raft = raft(lv)
			if r == null or r.sim_pos.x > POOL_X or n > 3000:
				return -1
			return _tap(hh, D if n % 100 == 50 else 0)])
	p.append(["mark", "home"])
	p.append(["fn", ride_fn(DOCK_X)])
	p.append(["fn", docked_fn()])
	p.append(["mark", "ashore"])
	p.append(["fn", ashore_fn(slot)])
	return p


## Ride on until the raft rests against the home beach's bank (its rails open over the beach, G45).
func docked_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var r: Raft = raft(lv)
		if r == null or n > 600 or (Game.level != null and Game.level.completed):
			return -1
		if r.sim_pos.x >= DOCK_X and r.rx == 0 and r.cd == 0:
			return -1
		return _tap(h, 0)


## Walk off the docked raft onto the beach to the welcome totem (co-op: P2 lets P1 step off first).
func ashore_fn(slot: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 600 or (Game.level != null and Game.level.completed):
			return -1
		if slot == 1 and n < 12:
			return 0
		return R


func build() -> Array:
	trace = opts.has("trace")
	var progs: Array = []
	for slot: int in players:
		progs.append(program(slot))
	return progs
