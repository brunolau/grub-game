extends "res://tools/autoplay/recorders/db1/p5/d7lib.gd"
## DB1 (wf10) bot helpers on D6 / D7's closed-loop library: hops, twin strikes on giant roasts, partner waits.
## Development only (build/ is not versioned).

var problems: Array = []


func _problem(text: String) -> void:
	print("PROBLEM t=%d %s" % [t, text])
	problems.append(text)


func report() -> void:
	print("PROBLEMS %d" % problems.size())
	for p: String in problems:
		print("  " + p)


## A hop: wait until he stands (no jump lock, not striking), then U (steering to tx) for `up` ticks, then steer to tx
## until grounded. opts: "max" ticks, "lead" px, "air" extra keys after the U phase, "no_steer_until" ticks.
func hop_fn(tx: int, up: int, o: Dictionary = {}) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if not bool(st.get("go", false)):
			if h.is_grounded() and h.no_jump == 0 and not h.is_striking() and absi(h.xvel) <= int(o.get("vmax", 9999)):
				st["go"] = true
				st["k"] = 0
			else:
				if n > 300:
					_problem("P%d hop to %d never started at %s" % [h.slot + 1, tx, h.sim_pos])
					return -1
				return int(o.get("wait_keys", 0))
		var k: int = int(st["k"])
		st["k"] = k + 1
		var dx: int = tx - h.sim_pos.x
		var lead: int = int(o.get("lead", 3))
		var keys: int = 0
		if k >= int(o.get("no_steer_until", 0)):
			if dx > lead:
				keys = R
			elif dx < -lead:
				keys = L
		else:
			keys = int(o.get("first_keys", 0))
		if k < up:
			return U | keys
		if k > 3 and h.is_grounded():
			return -1
		if k > int(o.get("max", 200)):
			_problem("P%d hop to %d did not land (%s)" % [h.slot + 1, tx, h.sim_pos])
			return -1
		return keys | int(o.get("air", 0))


## The hittable whose cell is `cell` (null when none).
func spot_at(cell: Vector2i) -> HittableBase:
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		var spot: HittableBase = entity as HittableBase
		if spot != null and spot.cell == cell:
			return spot
	return null


## Strike (F | extra) until the hittable at `cell` is opened, one press per strike.
func strike_open_fn(cell: Vector2i, extra: int = 0, limit: int = 600) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var spot: HittableBase = spot_at(cell)
		var st: Dictionary = _st[h.slot]
		if int(st.get("hold", 0)) > 0:
			st["hold"] = int(st["hold"]) - 1
			return (F | extra) if int(st["hold"]) >= 2 else 0
		if spot == null or spot.opened:
			return -1 if h.is_grounded() else 0
		if n > limit:
			_problem("P%d strike at %s timed out" % [h.slot + 1, cell])
			return -1
		if not h.is_grounded() or h.is_striking() or h.no_jump > 0:
			return 0
		st["hold"] = 9
		return F | extra


## The twin strike on a big spot (giant roast, GAMEPLAY 13.9.8): role "a" strikes (F | keys) while the spot needs
## more than its last hit, then once more and waits for the answer (again after 40 ticks); role "b" answers `delay`
## ticks after a's hit landed. Ends (both) when the spot is open and the hero stands.
func twin_fn(cell: Vector2i, role: String, keys: int, delay: int = 3) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var spot: HittableBase = spot_at(cell)
		var st: Dictionary = _st[h.slot]
		if int(st.get("hold", 0)) > 0:
			st["hold"] = int(st["hold"]) - 1
			return (F | keys) if int(st["hold"]) >= 2 else 0
		if spot == null or spot.opened:
			return -1 if h.is_grounded() else 0
		if n > 1200:
			_problem("P%d twin strike at %s timed out" % [h.slot + 1, cell])
			return -1
		if not h.is_grounded() or h.is_striking() or h.no_jump > 0:
			return 0
		var other: PlayerBase = hero(1 - h.slot)
		if role == "a":
			if not other.is_grounded() or other.xvel != 0 or absi(other.sim_pos.x - h.sim_pos.x) > 80 or absi(other.sim_pos.y - h.sim_pos.y) > 8:
				return 0
			if spot.hits_left > 1 or Sim.total_ticks - int(st.get("last", -999)) > 40:
				st["last"] = Sim.total_ticks
				st["hold"] = 9
				return F | keys
			return 0
		var ts: Variant = spot.get(&"twin_slot")
		var tt: Variant = spot.get(&"twin_tick")
		if ts != null and int(ts) == 1 - h.slot and spot.hits_left == 1:
			var since: int = Sim.total_ticks - int(tt)
			if since >= delay and since <= delay + 3:
				st["hold"] = 9
				return F | keys
		return D if n % 120 == 119 else 0


## A wait (Down tapped now and then) until `cond(level, hero)` holds.
func wait_cmd(cond: Callable, limit: int = 3000, what: String = "") -> Array:
	return ["fn", func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if cond.call(lv, h):
			return -1
		if n > limit:
			_problem("P%d wait %s timed out at %s" % [h.slot + 1, what, h.sim_pos])
			return -1
		return D if n % 120 == 119 and h.is_grounded() and not h.on_platform else 0]


## The partner stands (grounded, still) with x in [x0, x1] and feet y == fy (fy < 0: any).
func partner_at(x0: int, x1: int, fy: int = -1) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		var o: PlayerBase = hero(1 - h.slot)
		return o.is_grounded() and o.xvel == 0 and o.sim_pos.x >= x0 and o.sim_pos.x <= x1 \
				and (fy < 0 or o.sim_pos.y == fy)


## The partner is grounded and his feet y is `fy` (or above it when `above`).
func partner_on(fy: int, above: bool = false) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		var o: PlayerBase = hero(1 - h.slot)
		return o.is_grounded() and (o.sim_pos.y == fy or (above and o.sim_pos.y < fy))


## The partner's x is at least / at most `x` (dir +1 / -1), any state.
func partner_beyond_x(x: int, dir: int = 1) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		var o: PlayerBase = hero(1 - h.slot)
		return o.sim_pos.x >= x if dir > 0 else o.sim_pos.x <= x


## Away from x: the partner is farther than `px` from x, or not at feet y `fy`.
func partner_clear(x: int, fy: int, px: int = 36) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		var o: PlayerBase = hero(1 - h.slot)
		return absi(o.sim_pos.x - x) > px or o.sim_pos.y != fy


func both(a: Callable, b: Callable) -> Callable:
	return func(lv: LevelBase, h: PlayerBase) -> bool:
		return a.call(lv, h) and b.call(lv, h)


## The live enemy nearest to (px, py) within `r` px (null when none).
func enemy_near(px: int, py: int, r: int, awake_only: bool = false, cls: String = "") -> EnemyBase:
	var best: EnemyBase = null
	var bd: int = r + 1
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead:
			continue
		if awake_only and (not foe.awake or not foe.tangible):
			continue
		if cls != "" and foe.get_script().get_global_name() != StringName(cls):
			continue
		var d: int = maxi(absi(foe.sim_pos.x - px), absi(foe.sim_pos.y - py))
		if d < bd:
			bd = d
			best = foe
	return best


## Stand where he is and strike the enemy nearest (px, py) (within r) whenever a strike would hit it (forward or high,
## predicted 4-7 ticks ahead as in _fight), facing it; done when it is dead or gone (or after `limit` ticks).
func kill_fn(px: int, py: int, r: int = 48, limit: int = 900, o: Dictionary = {}) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var foe: EnemyBase = enemy_near(px, py, r, bool(o.get("awake_only", false)), str(o.get("cls", "")))
		if foe == null and int(_st[h.slot].get("striking", 0)) <= 0:
			return -1 if h.is_grounded() else 0
		if n > limit:
			_problem("P%d kill near (%d, %d) timed out at %s" % [h.slot + 1, px, py, h.sim_pos])
			return -1
		var f: int = strike_foe(h, foe, o)
		if f >= 0:
			return f
		if o.has("approach") and h.is_grounded() and not h.is_striking():
			# walk on towards the stand point (striking whenever a strike would hit on the way); with "crawl_from" the
			# last stretch is crawled (Down + direction charges the club: the strike that follows is a charged one,
			# x4 - one blow for an hp-25 enemy under the one-hit-per-strike rule of co-op files, G57)
			var ax: int = int(o["approach"])
			var hx: int = h.sim_pos.x
			if absi(ax - hx) > 2:
				if o.has("crawl_from") and ((ax > hx and hx >= int(o["crawl_from"])) or (ax < hx and hx <= int(o["crawl_from"]))):
					return D | (R if ax > hx else L)
				return brake_go(h, ax)
			if o.has("crawl_from"):
				return D
		if bool(o.get("charge", false)) and h.is_grounded() and not h.is_striking():
			# crouch while waiting: the club charges (a charged strike is x4)
			return D
		return D if n % 120 == 119 and h.is_grounded() else 0


## One tick of fighting `foe` (null: only finish a running strike): the flags (a strike, a turn, 0 while striking) or
## -1 when there is nothing to do now.
func strike_foe(h: PlayerBase, foe: EnemyBase, o: Dictionary = {}) -> int:
	var st: Dictionary = _st[h.slot]
	if int(st.get("striking", 0)) > 0:
		st["striking"] = int(st["striking"]) - 1
		return (F | int(st.get("strike_keys", 0))) if int(st["striking"]) > 3 else 0
	if foe == null:
		return -1
	if not h.is_grounded() or h.is_striking():
		return 0
	var face: int = 1 if foe.sim_pos.x > h.sim_pos.x else -1
	if absi(foe.sim_pos.x - h.sim_pos.x) <= 2 or bool(o.get("keep_face", false)):
		face = h.facing
	if h.facing != face:
		return R if face > 0 else L
	if not foe.awake or not foe.tangible:
		return -1
	var f: int = h.facing
	var dx: float = foe.sim_pos.x - h.sim_pos.x
	var dy: float = foe.sim_pos.y - h.sim_pos.y
	var vx: float = foe.xvel / 16.0
	var vy: float = foe.yvel / 16.0
	if bool(o.get("motion", h.on_platform)):
		# the motion actually made last tick, relative to the hero's own (a lift carries him; a flyer's speed is
		# not always in xvel)
		var fm: Vector2i = foe.sim_pos - foe.sim_prev
		var hm: Vector2i = h.sim_pos - h.sim_prev
		if absi(fm.x) <= 12 and absi(fm.y) <= 12:
			vx = float(fm.x)
			vy = float(fm.y)
		if absi(hm.x) <= 12 and absi(hm.y) <= 12:
			vx -= float(hm.x)
			vy -= float(hm.y)
	var levels: bool = foe is Stinger and vy > 0.0 and dy < 0.0
	var ks: Array = o.get("ks", fight_ks)
	for k: int in ks:
		var fx: float = dx + vx * k
		var fy2: float = dy + vy * k
		if foe is Hopper and foe.yvel != 0:
			# a hop is a ballistic arc (16 v16 per tick of gravity)
			fy2 += 0.5 * k * k
		if levels and fy2 > -4.0:
			# a diving stinger levels out at the hero's height (within 8 px) and flies on horizontally
			fy2 = -4.0
		var left: float = fx - foe.box_xo
		var right: float = left + foe.box_w
		var top: float = fy2 - foe.box_h
		var hit_x: bool = (right > 11.0 and left < 35.0) if f > 0 else (left < -11.0 and right > -35.0)
		var hit_y: bool = fy2 > -15.0 and top < -2.0
		if hit_x and hit_y and not bool(o.get("high_only", false)):
			st["striking"] = 9
			st["strike_keys"] = 0
			return F
		var high_x: bool = (right > 10.0 and left < 26.0) if f > 0 else (left < -10.0 and right > -26.0)
		var high_y: bool = fy2 > -43.0 and top < -27.0
		if high_x and high_y and not bool(o.get("no_high", false)):
			st["striking"] = 9
			st["strike_keys"] = U
			return F | U
	return -1


## Wait (striking any awake enemy within `r` px of him, Down tapped now and then) until `cond(level, hero)` holds.
func guard_cmd(cond: Callable, limit: int = 3000, what: String = "", r: int = 90, o: Dictionary = {}) -> Array:
	return ["fn", func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if int(_st[h.slot].get("striking", 0)) <= 0 and cond.call(lv, h):
			return -1
		if n > limit:
			_problem("P%d guard %s timed out at %s" % [h.slot + 1, what, h.sim_pos])
			return -1
		var f: int = strike_foe(h, enemy_near(h.sim_pos.x, h.sim_pos.y - 16, r, true), o)
		if f >= 0:
			return f
		return D if n % 120 == 119 and h.is_grounded() and not h.on_platform else 0]


var _barriers: Dictionary = {}
var _barrier_in: Dictionary = {}


## A barrier: every slot waits here; once all arrived both go on the SAME later tick (unlike botlib's "sync", where
## the slot processed first loses a tick).
func barrier(name: String) -> Array:
	return ["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var arrived: Dictionary = _barrier_in.get(name, {})
		arrived[h.slot] = true
		_barrier_in[name] = arrived
		if not _barriers.has(name) and arrived.size() >= players:
			_barriers[name] = t + 1
		if _barriers.has(name) and t >= int(_barriers[name]):
			return -1
		if n > 4000:
			_problem("P%d barrier %s timed out" % [h.slot + 1, name])
			return -1
		return D if n % 120 == 119 and h.is_grounded() and not h.on_platform else 0]


## shell_pair_fn mirrored: the pair comes from the RIGHT. The bait waits at `x_max` (the near edge, right of the
## turtle), the striker beside him; when the turtle walks RIGHT (towards them) inside [jump_lo, jump_hi] the striker
## jumps over it to the left and lands behind it, follows it at 26-40 px and strikes its back once the bait is the
## nearer hero. -1 once it is dead (or none is there). The striker never steps left of `x_min`.
func shell_pair_r_fn(x_lo: int, x_hi: int, striker: int = 0, x_min: int = 0, x_max: int = 999999,
		jump_lo: int = 0, jump_hi: int = 999999) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var e: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe.coop_trait == Defs.CoopTrait.SHELL \
					and foe.sim_pos.x >= x_lo and foe.sim_pos.x <= x_hi:
				e = foe
		if e == null or n > 2000:
			if n > 2000:
				_problem("P%d shell pair (right) timed out" % (h.slot + 1))
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
				st["k"] = k + 1
				var goal: int = maxi(ex - 44, x_min)
				var keys: int = R if x < goal - 3 else (L if x > goal + 3 else 0)
				if k <= 10:
					return U | keys
				if k > 3 and h.is_grounded():
					st["k"] = 0
					return 0
				return keys
			if not h.is_grounded() or h.is_striking():
				return 0
			if x > ex:
				var spot: int = x_max - 14
				if absi(x - spot) > 3 or h.xvel != 0:
					return brake_go(h, spot)
				if e.xvel > 0 and ex >= jump_lo and ex <= jump_hi and h.no_jump == 0:
					st["k"] = 1
					return U | L
				return 0
			var d: int = ex - x
			var db: int = absi(other.sim_pos.x - ex) + absi(other.sim_pos.y - e.sim_pos.y)
			var ds: int = absi(d) + absi(h.sim_pos.y - e.sim_pos.y)
			if h.facing == 1 and d >= 8 and d <= 42 and db + 4 < ds and other.counts_for_coop():
				if bool(st.get("pressed", false)):
					st["pressed"] = false
					return 0
				st["pressed"] = true
				return F
			if d < 26 and x > x_min:
				return L
			if d > 40:
				return R
			if h.facing != 1:
				return R
			return 0
		var s: PlayerBase = hero(striker)
		var want: int = x_max
		if s.sim_pos.x < ex - 8 and s.is_grounded():
			want = mini(ex + 24, x_max)
		if not h.is_grounded():
			return 0
		if x - ex < 20 and x < x_max - 2:
			return R
		if absi(want - x) <= 3 and h.xvel == 0:
			if h.facing != -1:
				return L
			return 0
		return brake_go(h, want)


## Chase the enemy nearest to (px, py) (within r; awake ones) and strike it whenever a strike would hit, keeping
## about `keep` px from it, never beyond [x_lo, x_hi]; done when it is dead or gone.
func chase_kill_fn(px: int, py: int, r: int, keep: int = 26, x_lo: int = -99999, x_hi: int = 99999, limit: int = 900) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var foe: EnemyBase = enemy_near(px, py, r, true)
		if foe == null and int(_st[h.slot].get("striking", 0)) <= 0:
			return -1 if h.is_grounded() else 0
		if n > limit:
			_problem("P%d chase near (%d, %d) timed out at %s" % [h.slot + 1, px, py, h.sim_pos])
			return -1
		var f: int = strike_foe(h, foe)
		if f >= 0:
			return f
		if foe == null or not h.is_grounded() or h.is_striking():
			return 0
		var side: int = -1 if h.sim_pos.x < foe.sim_pos.x else 1
		var want: int = clampi(foe.sim_pos.x + side * keep, x_lo, x_hi)
		if absi(want - h.sim_pos.x) > 3:
			return brake_go(h, want)
		var face: int = 1 if foe.sim_pos.x > h.sim_pos.x else -1
		if h.facing != face:
			return R if face > 0 else L
		return 0
