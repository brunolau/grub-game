extends "res://tools/autoplay/recorders/db1/p5/botlib.gd"
## D7 bot helpers on D6's bot library: rafts, blowholes, vines, Chomper, and the co-op idle guard.


## Every Raft of the level.
func rafts() -> Array[Raft]:
	var out: Array[Raft] = []
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			if entity is Raft:
				out.append(entity as Raft)
	return out


func raft_near(x: int) -> Raft:
	var best: Raft = null
	for raft: Raft in rafts():
		if best == null or absi(raft.sim_pos.x - x) < absi(best.sim_pos.x - x):
			best = raft
	return best


func mount() -> Mount:
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			if entity is Mount:
				return entity as Mount
	return null


## Walk off the bank in `dir` onto the raft lying flush against it; done once he stands on it and stopped.
func board_fn(dir: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if h.on_platform and h.is_grounded():
			st["on"] = int(st.get("on", 0)) + 1
			if int(st["on"]) > 2 and h.xvel == 0:
				return -1
			return 0
		if n > 200:
			return -1
		if not h.is_grounded():
			return 0
		# creep off the edge: a slow step lands him on the raft, a run carries him over it
		if absi(h.xvel) >= int(st.get("cap", 48)):
			return 0
		return R if dir > 0 else L


## Walk to the middle of the raft under him (`off` px from its centre) and stop there.
func center_fn(off: int = 0) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var raft: Raft = raft_near(h.sim_pos.x)
		var dx: int = raft.sim_pos.x + off - h.sim_pos.x
		if absi(dx) <= 3 and h.xvel == 0:
			return -1
		if n > 120:
			return -1
		if absi(dx) <= 3:
			return 0
		if h.xvel != 0 and signi(h.xvel) == signi(dx) and absi(dx) <= 6:
			return 0
		if absi(h.xvel) >= 32:
			return 0
		return R if dx > 0 else L


## Paddle the raft under the hero with forward strikes (facing against `dir`, so it goes `dir`) until its x passes
## `until_x`.
func paddle_fn(until_x: int, dir: int = 1) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var raft: Raft = raft_near(h.sim_pos.x)
		if (dir > 0 and raft.sim_pos.x >= until_x) or (dir < 0 and raft.sim_pos.x <= until_x):
			return -1
		if n > 400:
			return -1
		var st: Dictionary = _st[h.slot]
		if h.facing == dir:
			return L if dir > 0 else R
		if bool(st.get("pressed", false)):
			st["pressed"] = false
			return 0
		if h.is_striking():
			return 0
		st["pressed"] = true
		return F


## Ride the raft (fighting what comes) until it rests at a bank (or its x passes `until_x`).
func ride_fn(until_x: int, opts: Dictionary = {}) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var raft: Raft = raft_near(h.sim_pos.x)
		var st: Dictionary = _st[h.slot]
		if int(st.get("rx_last", -99999)) == raft.sim_pos.x:
			st["still"] = int(st.get("still", 0)) + 1
		else:
			st["still"] = 0
		st["rx_last"] = raft.sim_pos.x
		if raft.sim_pos.x >= until_x or (n > 12 and int(st["still"]) >= 6):
			return -1
		if n > 3000:
			return -1
		if not h.is_grounded():
			# a hit hop lifts him off the deck: steer back over the drifting raft
			var ax: int = raft.sim_pos.x + int(opts.get("off", 0)) + raft.cd * 6 - h.sim_pos.x
			if ax > 3:
				return R
			if ax < -3:
				return L
			return 0
		var o: Dictionary = {"fight": true, "wait_px": 0, "carry": raft.cd + raft.rx / 16.0}
		o.merge(opts, true)
		var fight: int = _fight(h, o)
		if fight >= 0:
			return fight
		var face: int = int(opts.get("face", 1))
		if face != 0 and h.facing != face and not h.is_striking():
			return R if face > 0 else L
		return int(opts.get("keys", 0))


## Stand on the vent at `vx` until the geyser launches him, then steer to `tx` until he lands higher up.
func launch_fn(vx: int, tx: int, hold_up: bool = false) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			st["y0"] = h.sim_pos.y
		var up: int = U if hold_up else 0
		if not bool(st.get("up", false)):
			if h.yvel < -100 and not h.is_grounded():
				st["up"] = true
			else:
				var dx0: int = vx - h.sim_pos.x
				if absi(dx0) > 3 and h.is_grounded():
					return R if dx0 > 0 else L
				return 0
		if (h.is_grounded() or h.state == Defs.HeroState.CLIMB) and h.sim_pos.y < int(st["y0"]) - 8:
			return -1
		if n > 600:
			return -1
		var dx: int = tx - h.sim_pos.x
		if dx > 3:
			return R | up
		if dx < -3:
			return L | up
		return up


## Climb the vine he holds to its top and step onto the ledge beside it (Up held), then stop.
func climb_fn(top_y: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_grounded() and h.sim_pos.y <= top_y:
			return -1
		if n > 600:
			return -1
		return U


## Wait (fighting) until `cond` holds.
func wait_fight_fn(cond: Callable, opts: Dictionary = {}) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if cond.call(lv, h):
			return -1
		if n > int(opts.get("max", 3000)):
			return -1
		var o: Dictionary = {"fight": true}
		o.merge(opts, true)
		var fight: int = _fight(h, o)
		if fight >= 0:
			return fight
		return 0


## Squid Grotto after the fight: the middle island has sunk (phase 3) and the squid's two rafts rest wherever its
## current last pushed them (it stops with the squid). A hero left of the pool crosses to the right island (the exit's
## side) by hops: from his footing (the left island, a root ledge, a raft) to the farthest-right footing he can reach
## (the root ledges over the gaps, the rafts, the right island). `wait_x` is where he stands at the left island's edge.
func grotto_cross_fn(wait_x: int = 720, use_rafts: bool = true) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > 1500:
			return -1
		var x: int = h.sim_pos.x
		var y: int = h.sim_pos.y
		var k: int = int(st.get("k", 0))
		if k > 0:
			# a hop in progress: Up `up` ticks, steer to the goal, until grounded again
			st["k"] = k + 1
			var goal: int = int(st["goal"])
			var keys: int = R if x < goal - 3 else (L if x > goal + 3 else 0)
			if k <= int(st["up"]):
				return U | keys
			if k > 3 and h.is_grounded():
				st["k"] = 0
				return 0
			return keys
		if not h.is_grounded() or h.no_jump > 0 or h.is_striking() or h.xvel != 0 and absi(h.xvel) < 16:
			return 0
		if x >= 54 * 16 + 6 and y >= 17 * 16 - 2:
			return -1
		if y >= 17 * 16 - 2 and x < 46 * 16 and not h.on_platform:
			# on the left island: to its edge first
			var dxw: int = wait_x - x
			if absi(dxw) > 3 or h.xvel != 0:
				var stop: int = (h.xvel * h.xvel) / (2 * 12 * 16) + 3
				if h.xvel != 0 and (signi(h.xvel) != signi(dxw) or absi(dxw) <= stop):
					return 0
				if absi(dxw) <= 3:
					return 0
				return R if dxw > 0 else L
		# footings to the right: [x, y] - the root ledges, the rafts, the right island
		var spots: Array = [[752, 14 * 16], [848, 14 * 16], [54 * 16 + 20, 17 * 16]]
		if use_rafts:
			for raft: Raft in rafts():
				spots.append([raft.sim_pos.x - 4, raft.sim_pos.y - raft.box_h])
		var best: Array = []
		for s: Array in spots:
			var dx: int = int(s[0]) - x
			var dy: int = int(s[1]) - y
			var reach: int = (64 if use_rafts else 100) if absi(dy) <= 8 else (104 if dy > 8 else 56)
			if dx >= 12 and dx <= reach and (best.is_empty() or int(s[0]) > int(best[0])):
				best = s
		if best.is_empty():
			return 0
		var dy2: int = int(best[1]) - y
		st["goal"] = int(best[0])
		st["up"] = 9 if dy2 < -8 else (6 if absi(dy2) <= 8 else 3)
		st["k"] = 1
		return U | R


## Wait at a pool's edge, fighting, until the leaper record at `px` has no copy out and will not produce one for
## `need` ticks (then a jump over the pool is safe).
func pool_fn(px: int, need: int = 30) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var rec: SpawnerEnemy = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var r: SpawnerEnemy = entity as SpawnerEnemy
			if r != null and not r.is_copy() and r is Leaper and absi(r.sim_pos.x - px) < 40:
				rec = r
		var fight: int = _fight(h, {"fight": true, "wait_px": 0})
		if fight >= 0:
			return fight
		var others: bool = false
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe.awake and foe.tangible and not (foe is Leaper) 					and absi(foe.sim_pos.x - h.sim_pos.x) < 110 and absi(foe.sim_pos.y - h.sim_pos.y) < 110:
				others = true
		if not others and (rec == null or (rec.alive_copies() == 0 and rec._cooldown >= need)) 				and h.is_grounded() and not h.is_striking():
			return -1
		if n > 600:
			return -1
		var face: int = 1 if px > h.sim_pos.x else -1
		if h.facing != face and h.is_grounded() and not h.is_striking():
			return R if face > 0 else L
		return 0


## Co-op Shellback pincer (two heroes, the pair coming from the left; the turtle patrols between its limits): the
## bait waits at the bank's edge `x_min`, the `striker` slot beside him; when the turtle walks LEFT (towards them)
## inside [jump_lo, jump_hi] the striker jumps over it and lands behind it, follows it at 26-40 px and strikes its back
## once the bait is the nearer hero (the shield faces the nearer active hero, GAMEPLAY 13.9.5) - the bait keeps about
## 24 px in front of it. -1 once it is dead (or none is there). The striker never steps right of `x_max` (a pool).
func shell_pair_fn(x_lo: int, x_hi: int, striker: int = 0, x_min: int = 0, x_max: int = 999999,
		jump_lo: int = 0, jump_hi: int = 999999) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var e: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe.coop_trait == Defs.CoopTrait.SHELL 					and foe.sim_pos.x >= x_lo and foe.sim_pos.x <= x_hi:
				e = foe
		if e == null or n > 2000:
			return -1
		var ex: int = e.sim_pos.x
		var other: PlayerBase = hero(1 - h.slot)
		var st: Dictionary = _st[h.slot]
		var x: int = h.sim_pos.x
		if h.dead or h.down:
			return 0
		if h.slot == striker:
			var k: int = int(st.get("k", 0))
			if k > 0:
				# the jump over it, steering to land behind it
				st["k"] = k + 1
				var goal: int = mini(ex + 44, x_max)
				var keys: int = R if x < goal - 3 else (L if x > goal + 3 else 0)
				if k <= 10:
					return U | keys
				if k > 3 and h.is_grounded():
					st["k"] = 0
					return 0
				return keys
			if not h.is_grounded() or h.is_striking():
				return 0
			if x < ex:
				var spot: int = x_min + 14
				if absi(x - spot) > 3 or h.xvel != 0:
					return brake_go(h, spot)
				if e.xvel < 0 and ex >= jump_lo and ex <= jump_hi and h.no_jump == 0:
					st["k"] = 1
					return U | R
				return 0
			# behind it: follow at 26-40 px, face it, strike its back once the bait is the nearer hero
			var d: int = x - ex
			var db: int = absi(other.sim_pos.x - ex) + absi(other.sim_pos.y - e.sim_pos.y)
			var ds: int = absi(d) + absi(h.sim_pos.y - e.sim_pos.y)
			if h.facing == -1 and d >= 8 and d <= 42 and db + 4 < ds and other.counts_for_coop():
				if bool(st.get("pressed", false)):
					st["pressed"] = false
					return 0
				st["pressed"] = true
				return F
			if d < 26 and x < x_max:
				return R
			if d > 40:
				return L
			if h.facing != -1:
				return L
			return 0
		# the bait: at the bank's edge until the striker is behind it, then about 24 px in front of it, facing it
		var s: PlayerBase = hero(striker)
		var want: int = x_min
		if s.sim_pos.x > ex + 8 and s.is_grounded():
			want = maxi(ex - 24, x_min)
		if not h.is_grounded():
			return 0
		if ex - x < 20 and x > x_min + 2:
			return L
		if absi(want - x) <= 3 and h.xvel == 0:
			if h.facing != 1:
				return R
			return 0
		return brake_go(h, want)


## Walk towards `goal` and stop on it (coast once the stopping distance covers the rest; let go when moving away; a
## one-tick tap for the last few px).
func brake_go(h: PlayerBase, goal: int) -> int:
	var st: Dictionary = _st[h.slot]
	var dx: int = goal - h.sim_pos.x
	var speed: int = absi(h.xvel)
	if h.xvel != 0 and signi(h.xvel) != signi(dx):
		return 0
	var stop: int = (speed * speed) / (2 * 12 * 16) + 2
	if h.xvel != 0 and absi(dx) <= stop:
		return 0
	if absi(dx) <= 3:
		return 0
	if speed == 0 and absi(dx) < 10:
		if int(st.get("tap", 0)) > 0:
			st["tap"] = int(st["tap"]) - 1
			return 0
		st["tap"] = 3
	return R if dx > 0 else L


## Squid Grotto after the fight (the middle island sunk, phase 3's rafts lying still): from the left island over the
## two root ledges (row 14, cols 46-47 and 52-53) to the right island; done at once when he already stands there.
func ledges_cross_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var x: int = h.sim_pos.x
		var y: int = h.sim_pos.y
		var k: int = int(st.get("k", 0))
		if n > 900:
			return -1
		if k > 0:
			st["k"] = k + 1
			var goal: int = int(st["goal"])
			var keys: int = R if x < goal - 3 else (L if x > goal + 3 else 0)
			if k <= int(st["up"]):
				return U | keys
			if k > 3 and h.is_grounded():
				st["k"] = 0
				st["rest"] = 3
				return 0
			return keys
		if not h.is_grounded():
			return 0
		if int(st.get("rest", 0)) > 0:
			st["rest"] = int(st["rest"]) - 1
			return 0
		if x >= 54 * 16 + 6 and y >= 17 * 16 - 2:
			return -1
		if y <= 14 * 16 + 2 and x >= 52 * 16:
			return R
		if y <= 14 * 16 + 2:
			# on the left ledge: to its right end, then over the 4-cell gap
			if absi(x - 764) > 3 or h.xvel != 0:
				return brake_go(h, 764)
			if h.no_jump > 0 or h.is_striking():
				return 0
			st["k"] = 1
			st["goal"] = 846
			st["up"] = 6
			return U | R
		# on the left island: to its edge, then up onto the left ledge
		if absi(x - 720) > 3 or h.xvel != 0:
			return brake_go(h, 720)
		if h.no_jump > 0 or h.is_striking():
			return 0
		st["k"] = 1
		st["goal"] = 758
		st["up"] = 9
		return U | R
