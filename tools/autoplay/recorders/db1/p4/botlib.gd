extends "res://tools/autoplay/recorders/db1/p3/botlib.gd"
## DB1 phase-3 bot library, second protocol (development only; build/ is not versioned): `follow3`.
##
## Lock-step leader and follower over a solo route's sections, built for the team exit and the tribe camera:
##   - before section k P1 stamps r<k> where he stands and waits until P2 stood there too (ready2[k]);
##   - P1 plays section k (the solo flags, or his own commands c1[k]);
##   - P2 replays section k from the same point once P1 moved `lead` px on (or finished it), steering away from P1's
##     head when he would land on it; sections in `skip` (spot strikes) he does not replay;
##   - after a replayed section P1 steps aside (forward if the floor goes on, else back), waits until P2 has landed,
##     and walks back to his own end point - so P2 never lands on his head and both stand together again.
## Every wait taps Down now and then: no hero stands 243 ticks without input (the IDLE rule, DESIGN.md G33).

## Section k -> true once P2 finished his replay of k (or his own commands c2[k]).
var done2: Dictionary = {}
## Section k -> true once P2 stood at P1's ready point r<k>.
var ready2: Dictionary = {}
## Section k -> true once P1 finished section k and stepped aside (P2 then replays it).
var aside_done: Dictionary = {}
## Section k -> true when it does not start at a rest point and runs on from k - 1 (no wait, no aside).
var merged: Dictionary = {}


static func mirrored_at(cfg: Dictionary, k: int) -> bool:
	return str(cfg.get("mode", "replay")) == "mirror" or (cfg.get("mirror", []) as Array).has(k)


## A wait that taps Down every 120 ticks until `done` (callable() -> bool) holds.
func wait_for(done: Callable, limit: int = 3000, what: String = "") -> Array:
	return ["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if done.call():
			return -1
		if n > limit:
			_problem("P%d wait_for %s timed out at t=%d %s" % [h.slot + 1, what, t, h.sim_pos])
			return -1
		return D if n % 120 == 119 and h.is_grounded() else 0]


## Set a flag in a dictionary (a zero-tick command).
func flag_cmd(dict: Dictionary, key: Variant) -> Array:
	return ["fn", func(_lv: LevelBase, _h: PlayerBase, _n: int) -> int:
		dict[key] = true
		return -1]


## True when a hero could stand with his feet at (x, y) (floor under him, no wall in his body).
func can_stand(x: int, y: int) -> bool:
	var grid: TileGrid = level.grid
	var col: int = x >> 4
	for c: int in [(x - 6) >> 4, col, (x + 6) >> 4]:
		for r: int in [(y - 1) >> 4, (y - 17) >> 4, (y - 33) >> 4]:
			if grid.side_at(c, r) != 0:
				return false
	return TileGrid.is_ground(grid.floor_at(col, y >> 4)) or TileGrid.is_ground(grid.floor_at((x - 4) >> 4, y >> 4)) \
			and TileGrid.is_ground(grid.floor_at((x + 4) >> 4, y >> 4))


## P1 after a replayed section k: step aside (forward if the floor goes on there, else back), wait until P2 finished
## his replay and stands still, walk back to the end point of k.
func aside_cmds(k: int, opts_k: Dictionary = {}) -> Array:
	var ek: String = "e%d" % k
	var sk: String = "s%d" % k
	var cmds: Array = []
	cmds.append(["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			var e: Array = stamps[0].get(ek, [])
			var s: Array = stamps[0].get(sk, [])
			st["target"] = -1
			if e.is_empty() or not h.is_grounded():
				return -1
			var dir: int = signi(int(e[1]) - int(s[1])) if not s.is_empty() else 0
			if dir == 0:
				dir = h.facing
			if opts_k.has("dir"):
				dir = int(opts_k["dir"])
			var dist: int = int(opts_k.get("px", 30))
			for cand: int in [int(e[1]) + dist * dir, int(e[1]) - (dist + 6) * dir, int(e[1]) + (dist + 16) * dir]:
				var ok: bool = true
				for x: int in range(mini(cand, int(e[1])), maxi(cand, int(e[1])) + 1, 4):
					if not can_stand(x, int(e[2])):
						ok = false
						break
				if ok:
					st["target"] = cand
					break
			if int(st["target"]) < 0:
				print("ASIDE t=%d P1 no room beside %s" % [t, str(e)])
				return -1
		var tx: int = int(st["target"])
		var dx: int = tx - h.sim_pos.x
		if absi(dx) <= 6 or n > 60 or (int(st.get("dir0", 0)) != 0 and signi(dx) != int(st["dir0"])):
			return -1
		if not st.has("dir0"):
			st["dir0"] = signi(dx)
		return R if dx > 0 else L])
	cmds.append(wait_for(func() -> bool:
		var p2: PlayerBase = hero(1)
		return done2.has(k) and p2.is_grounded() and p2.xvel == 0, 3000, "P2 done %d" % k))
	cmds.append(["goto_stamp", 0, ek, 300])
	return cmds


## The lock-step programs (see the file comment). cfg: "skip": [k] (P2 does not replay k), "p1": {k: [commands]}
## (P1's own commands for k), "p2": {k: [commands]} (P2's own commands for k: he starts them from r<k>; he marks
## done2[k] at their end), "p2_free": [k] (P2 does not walk to r<k> first: his own commands start where he is),
## "lead": px [40], "aside": {k: {"dir": +1/-1, "px": n}}, "no_aside": [k].
func follow3(sections: Array, cfg: Dictionary) -> Array:
	var p1: Array = []
	var p2: Array = []
	var skip: Array = cfg.get("skip", [])
	var c1: Dictionary = cfg.get("p1", {})
	var c2: Dictionary = cfg.get("p2", {})
	var free: Array = cfg.get("p2_free", [])
	var aside_cfg: Dictionary = cfg.get("aside", {})
	var no_aside: Array = cfg.get("no_aside", [])
	var lead: int = int(cfg.get("lead", 40))
	var lagged: Array = cfg.get("replay", [])
	for k: int in sections.size():
		var rk: String = "r%d" % k
		var sk: String = "s%d" % k
		var ek: String = "e%d" % k
		var kk: int = k
		var mirrored: bool = str(cfg.get("mode", "replay")) == "mirror" or (cfg.get("mirror", []) as Array).has(k)
		if not skip.has(k) and not c2.has(k) and not lagged.has(k) and mirrored:
			# MIRROR: P2 stands where P1 stands and presses P1's keys on the same tick - the same path, side by side.
			p1.append(["stamp", rk])
			p1.append(wait_for(func() -> bool:
				var p2m: PlayerBase = hero(1)
				return ready2.has(kk) and p2m.is_grounded() and p2m.xvel == 0, 4000, "P2 ready %d" % kk))
			p1.append(["stamp", sk])
			p1.append(["note", str(sections[k][0])])
			p1.append_array(c1[k] if c1.has(k) else [["raw", sections[k][1]]])
			p1.append(["stamp", ek])
			if not free.has(k):
				p2.append(wait_for(func() -> bool: return stamps[0].has(rk), 6000, "P1 at r%d" % kk))
				p2.append(["goto_stamp", 0, rk, 600])
			p2.append(flag_cmd(ready2, k))
			p2.append(["progress", k])
			p2.append(wait_for(func() -> bool: return stamps[0].has(sk), 6000, "P1 at s%d" % kk))
			p2.append(["mirror", 0, ek])
			p2.append(flag_cmd(done2, k))
			continue
		var rep: bool = not skip.has(k) and not c2.has(k)
		var custom: bool = c2.has(k)
		var next_custom: bool = k + 1 < sections.size() and (c2.has(k + 1) or mirrored_at(cfg, k + 1))
		var last: bool = k + 1 >= sections.size()
		# --- P1 --- (P2 replays a section after P1 finished it and stepped aside; a section that does not start at a
		# rest point - P1 still moving or in the air - is MERGED with the one before: no wait, P2 replays on)
		p1.append(["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
			if merged.has(kk):
				return -1
			if n == 0:
				stamps[0][rk] = [t, h.sim_pos.x, h.sim_pos.y, h.facing, h.xvel, h.is_grounded()]
			if ready2.has(kk) and hero(1).is_grounded() and hero(1).xvel == 0:
				return -1
			if n > 4000:
				_problem("P1 wait for P2 ready %d timed out" % kk)
				return -1
			return D if n % 120 == 119 and h.is_grounded() else 0])
		p1.append(["stamp", sk])
		p1.append(["note", str(sections[k][0])])
		if c1.has(k):
			p1.append_array(c1[k])
		else:
			p1.append(["raw", sections[k][1]])
		p1.append(["stamp", ek])
		if not custom and not next_custom and not last:
			p1.append(["fn", func(_lv: LevelBase, h: PlayerBase, _n: int) -> int:
				if not h.is_grounded() or h.xvel != 0:
					merged[kk + 1] = true
					print("MERGE t=%d section %d runs on into %d (P1 at %s v%d)" % [t, kk, kk + 1, h.sim_pos, h.xvel])
				return -1])
		if rep and not no_aside.has(k):
			var asd: Array = aside_cmds(k, aside_cfg.get(k, {}))
			p1.append(["fn", func(lv: LevelBase, h: PlayerBase, n: int) -> int:
				if merged.has(kk + 1):
					aside_done[kk] = true
					return -1
				var r: int = int((asd[0][1] as Callable).call(lv, h, n))
				if r < 0:
					aside_done[kk] = true
				return r])
			p1.append(["fn", func(lv: LevelBase, h: PlayerBase, n: int) -> int:
				if merged.has(kk + 1):
					return -1
				return int((asd[1][1] as Callable).call(lv, h, n))])
			p1.append(["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
				if merged.has(kk + 1):
					return -1
				var e: Array = stamps[0][ek]
				return _goto(h.slot, h, int(e[1]), int(e[3]), 300, n)])
		elif rep:
			p1.append(flag_cmd(aside_done, k))
			p1.append(wait_for(func() -> bool: return done2.has(kk) or merged.has(kk + 1), 3000, "P2 done %d" % kk))
		elif custom and not cfg.get("p1_nowait", []).has(k):
			p1.append(wait_for(func() -> bool: return done2.has(kk), 4000, "P2 custom done %d" % kk))
		# --- P2 ---
		if not free.has(k):
			p2.append(wait_for(func() -> bool: return stamps[0].has(rk) or merged.has(kk), 6000, "P1 at r%d" % kk))
			p2.append(["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
				if merged.has(kk):
					return -1
				var r0: Array = stamps[0][rk]
				return _goto(h.slot, h, int(r0[1]), int(r0[3]), 600, n)])
		p2.append(flag_cmd(ready2, k))
		p2.append(["progress", k])
		if custom:
			p2.append_array(c2[k])
			p2.append(flag_cmd(done2, k))
		elif rep:
			var lag: int = int(cfg.get("lag", 30))
			p2.append(wait_for(func() -> bool:
				if aside_done.has(kk) or merged.has(kk):
					return true
				var st0: Array = stamps[0].get(sk, [])
				var me: PlayerBase = hero(0)
				return not st0.is_empty() and t - int(st0[0]) >= lag and (absi(me.sim_pos.x - int(st0[1])) >= lead 					or absi(me.sim_pos.y - int(st0[2])) >= lead), 6000, "P1 lead %d" % kk))
			p2.append(["replay_safe", 0, sk, ek])
			p2.append(["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
				if merged.has(kk + 1):
					return -1
				if h.is_grounded() and h.xvel == 0:
					return -1
				if n > 300:
					_problem("P2 did not come to rest after %d at %s" % [kk, h.sim_pos])
					return -1
				return 0])
			p2.append(flag_cmd(done2, k))
	return [p1, p2]


# --- The giant roast of a co-op Feast Land (GAMEPLAY.md 13.9.8, objects-A's HiddenSpot twin rule) -----------------

## The hittable whose cell is `cell` (null when none).
func spot_at(cell: Vector2i) -> HittableBase:
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		var spot: HittableBase = entity as HittableBase
		if spot != null and spot.cell == cell:
			return spot
	return null


## The twin strike on a big spot: role "a" strikes (F | keys) while the spot needs more than its last hit, then once
## and waits for the answer (again after 40 ticks); role "b" answers `delay` ticks after a's hit landed. Ends (both)
## when the spot is open and the hero stands.
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
		if not h.is_grounded() or h.is_striking():
			return 0
		if role == "a":
			if spot.hits_left > 1 or Sim.total_ticks - int(st.get("last", -999)) > 40:
				st["last"] = Sim.total_ticks
				st["hold"] = 9
				return F | keys
			return 0
		var other: int = 1 - h.slot
		var ts: Variant = spot.get(&"twin_slot")
		var tt: Variant = spot.get(&"twin_tick")
		if ts != null and int(ts) == other and spot.hits_left == 1:
			var since: int = Sim.total_ticks - int(tt)
			if since >= delay and since <= delay + 3:
				st["hold"] = 9
				return F | keys
		return D if n % 120 == 119 else 0


## A section with a big spot: [P1 commands, P2 commands]. P1 plays the section's flags up to its first strike, stands
## there until P2 joined him, opens the spot with P2 (the twin strike) and plays the flags after its last strike; P2
## walks to P1's strike point, answers his strikes and plays the same last flags.
func spot_section(k: int, flags: PackedInt32Array, cell: Vector2i, keys: int, delay: int = 3) -> Array:
	var first: int = -1
	var last: int = -1
	for i: int in flags.size():
		if flags[i] & F:
			if first < 0:
				first = i
			last = i
	var head: PackedInt32Array = flags.slice(0, maxi(first, 0))
	var tail: PackedInt32Array = flags.slice(last + 1)
	# The tail starts with the idle ticks of the last strike: keep them out (the twin loop already waited).
	var lead_idle: int = 0
	while lead_idle < tail.size() and tail[lead_idle] == 0:
		lead_idle += 1
	tail = tail.slice(mini(lead_idle, 2))
	var stamp: String = "sp%d" % k
	var joined: String = "sp%d_joined" % k
	var c1: Array = [["raw", head], ["stamp", stamp],
		wait_for(func() -> bool:
			var p2h: PlayerBase = hero(1)
			return ready2.has(joined) and p2h.is_grounded() and p2h.xvel == 0, 3000, "P2 at spot %d" % k),
		["fn", twin_fn(cell, "a", keys, delay)], ["raw", tail]]
	var c2: Array = [wait_for(func() -> bool: return stamps[0].has(stamp), 4000, "P1 at spot %d" % k),
		["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
			# Opposite P1 across the spot, facing it (a pogo never lands one on the other's head).
			# 20 px from the spot's centre on the side away from P1 (behind him when he stands on it), facing it:
			# the strike reaches the cell and neither hero's pogo lands on the other's head.
			var a: Array = stamps[0][stamp]
			var cxp: int = cell.x * 16 + 8
			var side: int = signi(cxp - int(a[1])) if absi(cxp - int(a[1])) >= 4 else -int(a[3])
			return _goto(h.slot, h, cxp + 20 * side, -side, 600, n)],
		flag_cmd(ready2, joined),
		["fn", twin_fn(cell, "b", keys, delay)], ["raw", tail]]
	return [c1, c2]


# --- follow4: the segment queue (no enemies: the Feast Lands) -------------------------------------------------------
# P1 plays runs of solo sections as one flag list and PAUSES at every rest point (grounded, still, not striking) once
# he moved since the last pause: he publishes the segment he just played, steps aside, waits until P2 replayed it
# from the same point and stands still there, walks back to the exact point (facing as before) and goes on - a rest
# point is a state the solo hero was in, so his path stays the solo path. P2 replays each published segment as soon
# as P1 stepped aside: he lands where P1 stood a moment before, never on his head, and stays on the same view.

## unit id -> Array of [start tick, end tick] (P1's history indices).
var segs: Dictionary = {}
## unit id -> true once P1 published its last segment.
var unit_done: Dictionary = {}
## "unit:j" -> true once P1 stepped aside after segment j; "unit:j:p2" once P2 replayed it and stands still.
var seg_flags: Dictionary = {}


func at_rest(h: PlayerBase) -> bool:
	return h.is_grounded() and h.xvel == 0 and h.yvel == 0 and not h.is_striking()


## P1: play `flags` (notes: [[offset, text], ...]) as unit `uid`, pausing at rest points for P2.
func segs_fn(uid: String, flags: PackedInt32Array, notes_at: Array, min_seg: int = 8) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			st["i"] = 0
			st["a"] = t
			st["phase"] = "play"
			st["moved"] = false
			st["uid"] = uid
			st["flags"] = flags
			st["notes_at"] = notes_at
			segs[uid] = []
		var phase: String = str(st["phase"])
		if phase == "play":
			var i: int = int(st["i"])
			var ended: bool = i >= flags.size()
			var rest: bool = at_rest(h)
			if not ended and not rest:
				st["moved"] = true
			if (ended and rest) or (rest and bool(st["moved"]) and t - int(st["a"]) >= min_seg and i < flags.size() \
					and (flags[i] & (L | R | U)) != 0):
				# A rest point: publish the segment, step aside.
				(segs[uid] as Array).append([int(st["a"]), t])
				st["j"] = (segs[uid] as Array).size() - 1
				st["px"] = h.sim_pos.x
				st["face"] = h.facing
				st["phase"] = "aside"
				st["n0"] = n
				st["ended"] = ended
				st["target"] = _aside_target(h)
				return _seg_step(h, st)
			if ended:
				if n - int(st.get("end_n", n)) > 300:
					_problem("P1 unit %s never came to rest at %s" % [uid, h.sim_pos])
					unit_done[uid] = true
					return -1
				if not st.has("end_n"):
					st["end_n"] = n
				return 0
			for note: Array in notes_at:
				if int(note[0]) == i:
					if notes.is_empty() and t > 0:
						notes.append([0, "Start."])
					notes.append([t, str(note[1])])
			st["i"] = i + 1
			return flags[i]
		return _seg_step(h, st)


func _aside_target(h: PlayerBase) -> int:
	var x: int = h.sim_pos.x
	var dir: int = h.facing
	for cand: int in [x + 30 * dir, x - 36 * dir, x + 46 * dir, x - 50 * dir]:
		var ok: bool = true
		# The walk may slide up to 16 px past the point: the floor must go on that far too.
		var over: int = cand + 16 * signi(cand - x)
		for xx: int in range(mini(over, x), maxi(over, x) + 1, 2):
			if not can_stand(xx, h.sim_pos.y):
				ok = false
				break
		if ok:
			return cand
	return x


func _seg_step(h: PlayerBase, st: Dictionary) -> int:
	var phase: String = str(st["phase"])
	var uid_j: String = "%s:%d" % [str(st.get("uid", "")), int(st["j"])]
	if phase == "aside":
		var tx: int = int(st["target"])
		var dx: int = tx - h.sim_pos.x
		if absi(dx) <= 12 or int(st["n0"]) + 60 < _n[h.slot] or tx == int(st["px"]):
			seg_flags[_key_now(st)] = true
			st["phase"] = "wait"
			st["wn"] = 0
			return 0
		return R if dx > 0 else L
	if phase == "wait":
		st["wn"] = int(st["wn"]) + 1
		var p2: PlayerBase = hero(1)
		if seg_flags.has(_key_now(st) + ":p2") and p2.is_grounded() and p2.xvel == 0:
			if bool(st["ended"]):
				st["phase"] = "back_end"
			else:
				st["phase"] = "back"
			st["gn"] = 0
			return 0
		if int(st["wn"]) > 3000:
			_problem("P1 waited for P2's segment %s too long" % _key_now(st))
			st["phase"] = "back"
			st["gn"] = 0
		return D if int(st["wn"]) % 120 == 119 and h.is_grounded() else 0
	# "back" / "back_end": stand exactly at the pause point, facing as before.
	var gn: int = int(st["gn"])
	st["gn"] = gn + 1
	var r: int = _goto_raw(h, st, int(st["px"]), int(st["face"]), gn)
	if r >= 0:
		return r
	if phase == "back_end":
		unit_done[str(st["uid"])] = true
		return -1
	st["phase"] = "play"
	st["a"] = t
	st["moved"] = false
	return _st_play_next(h, st)


func _key_now(st: Dictionary) -> String:
	return "%s:%d" % [str(st["uid"]), int(st["j"])]


## The flags of the next tick after a pause (play phase; the caller is the segs fn's own state).
func _st_play_next(_h: PlayerBase, st: Dictionary) -> int:
	var flags: PackedInt32Array = st["flags"]
	var i: int = int(st["i"])
	if i >= flags.size():
		return 0
	for note: Array in (st["notes_at"] as Array):
		if int(note[0]) == i:
			notes.append([t, str(note[1])])
	st["i"] = i + 1
	st["moved"] = true
	return flags[i]


## _goto with its own sub-state (keys "g_*" in st): -1 when standing at x facing `face`.
func _goto_raw(h: PlayerBase, st: Dictionary, x: int, face: int, n: int) -> int:
	var sub: Dictionary = st.get("g_sub", {})
	if n == 0:
		sub = {}
		st["g_sub"] = sub
	var saved: Dictionary = _st[h.slot]
	_st[h.slot] = sub
	var r: int = _goto(h.slot, h, x, face, 400, n)
	_st[h.slot] = saved
	return r


## P2: replay unit `uid`'s segments as P1 publishes them.
func follow_segs_fn(uid: String, first: int = 0) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			st["j"] = first
			st["k"] = -1
		var list: Array = segs.get(uid, [])
		var j: int = int(st["j"])
		if int(st["k"]) >= 0:
			var seg: Array = list[j]
			var index: int = int(seg[0]) + int(st["k"])
			if index < int(seg[1]):
				if int(st["k"]) == 0 and (h.sim_pos.x != hx[0][index] or h.sim_pos.y != hy[0][index]):
					_problem("P2 segment %s:%d starts at %s, P1 was at (%d, %d)" % [uid, j, h.sim_pos, hx[0][index],
						hy[0][index]])
				st["k"] = int(st["k"]) + 1
				return hist[0][index]
			# Played: come to rest, then report.
			if at_rest(h) or int(st["k"]) - (int(seg[1]) - int(seg[0])) > 240:
				seg_flags["%s:%d:p2" % [uid, j]] = true
				st["j"] = j + 1
				st["k"] = -1
				if hx[0].size() > int(seg[1]) and (h.sim_pos.x != hx[0][int(seg[1])] or h.sim_pos.y != hy[0][int(seg[1])]):
					print("SEG t=%d P2 ended %s:%d at %s, P1 at (%d, %d)" % [t, uid, j, h.sim_pos, hx[0][int(seg[1])],
						hy[0][int(seg[1])]])
				return 0
			st["k"] = int(st["k"]) + 1
			return 0
		if j < list.size() and seg_flags.has("%s:%d" % [uid, j]):
			st["k"] = 0
			return 0
		if unit_done.has(uid) and j >= list.size():
			return -1
		return D if n % 120 == 119 and h.is_grounded() else 0


## The follow4 programs: runs of raw sections become units (segs_fn / follow_segs_fn); sections in `mirror` are
## played by both on the same tick from the same point; sections with own commands ("p1" / "p2") as in follow3.
## Before every unit and mirror section P1 waits until P2 stands exactly where he stands.
func follow4(sections: Array, cfg: Dictionary) -> Array:
	var p1: Array = []
	var p2: Array = []
	var c1: Dictionary = cfg.get("p1", {})
	var c2: Dictionary = cfg.get("p2", {})
	var mirror: Array = cfg.get("mirror", [])
	var k: int = 0
	var unit: int = 0
	var carry: bool = false
	var carry_start: int = 0
	while k < sections.size():
		var key: String = "u%d" % unit
		unit += 1
		var rk: String = "r_" + key
		var kind: String = "raw"
		if c2.has(k):
			kind = "custom"
		elif mirror.has(k):
			kind = "mirror"
		if kind != "custom" and not carry:
			# Both stand on one point before P1 goes on.
			var rkey: String = rk
			p1.append(["stamp", rk])
			p1.append(wait_for(func() -> bool:
				var p2h: PlayerBase = hero(1)
				return ready2.has(rkey) and p2h.is_grounded() and p2h.xvel == 0, 4000, "P2 at " + rkey))
			p2.append(wait_for(func() -> bool: return stamps[0].has(rkey), 8000, "P1 at " + rkey))
			p2.append(["goto_stamp", 0, rk, 600])
			p2.append(flag_cmd(ready2, rk))
		if kind == "custom":
			p1.append(["note", str(sections[k][0])])
			p1.append_array(c1[k])
			p2.append_array(c2[k])
			k += 1
			continue
		if kind == "mirror":
			var ek: String = "e_" + key
			p1.append(["note", str(sections[k][0])])
			p1.append(["raw", sections[k][1]])
			p1.append(["stamp", ek])
			p2.append(["mirror", 0, ek])
			if (cfg.get("mirror_on", []) as Array).has(k):
				# A ride: P2 keeps pressing P1's keys into the next unit until P1's first rest point there (both step off
				# the moving platform together); that first segment counts as replayed.
				var next_uid: String = "u%d" % unit
				p2.append(["fn", func(_lv: LevelBase, _h: PlayerBase, _n: int) -> int:
					if (segs.get(next_uid, []) as Array).size() >= 1:
						seg_flags[next_uid + ":0:p2"] = true
						return -1
					return cur[0]])
				carry = true
				carry_start = 1
			k += 1
			continue
		# A unit: raw sections up to the next custom / mirror one.
		var flags: PackedInt32Array = PackedInt32Array()
		var notes_at: Array = []
		while k < sections.size() and not c2.has(k) and not mirror.has(k):
			notes_at.append([flags.size(), str(sections[k][0])])
			flags.append_array(sections[k][1])
			k += 1
		p1.append(["fn", segs_fn(key, flags, notes_at, int(cfg.get("min_seg", 8)))])
		p2.append(["fn", follow_segs_fn(key, carry_start)])
		carry = false
		carry_start = 0
	return [p1, p2]


## As botlib's _goto, exact for longer (a follower replays from this very point).
func _goto(s: int, h: PlayerBase, x: int, face: int, limit: int, n: int) -> int:
	var st: Dictionary = _st[s]
	if n > limit:
		_problem("P%d goto %d (facing %d) timed out at %s facing %d" % [s + 1, x, face, h.sim_pos, h.facing])
		return -1
	if int(st.get("hold", 0)) > 0:
		st["hold"] = int(st["hold"]) - 1
		return int(st["hold_key"])
	if int(st.get("pause", 0)) > 0:
		st["pause"] = int(st["pause"]) - 1
		return 0
	if not h.is_grounded():
		return 0
	var dx: int = x - h.sim_pos.x
	if dx == 0 and h.xvel == 0 and h.facing == face:
		return -1
	# Taps that keep missing (a skid, a slope, a wall): settle for a point a pixel or two off after a while.
	var slack: int = 0 if n < 200 else (1 if n < 280 else (2 if n < 340 else 4))
	if absi(dx) <= slack and h.xvel == 0:
		if h.facing == face:
			return -1
		if not bool(st.get("turned", false)):
			st["turned"] = true
			st["pause"] = 3
			return R if face > 0 else L
	var aim: int = x
	if dx == 0 or signi(dx) != face:
		aim = x - 6 * face
	var d: int = aim - h.sim_pos.x
	if h.xvel != 0:
		var speed: int = absi(h.xvel)
		var stop: int = (speed * speed) / (2 * 12 * 16) + 2
		if signi(h.xvel) == signi(d) and absi(d) > stop + 6:
			return R if d > 0 else L
		return 0
	var key: int = R if d > 0 else L
	if absi(d) > 24:
		return key
	if absi(d) >= 4:
		st["hold"] = 1
		st["hold_key"] = key
		st["pause"] = 3
		return key
	st["pause"] = 3
	return key
