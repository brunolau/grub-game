extends RefCounted
## DB1 phase-3 bot library (development only; build/ is not versioned). Based on D6's botlib (build/d6): a program
## per hero slot, one command after the other, each command a per-tick flag source; probe_work.gd records the flags
## as a two-stream route file and replays it through the bench runner.
##
## Commands (Arrays):
##   ["keys", n, flags]            hold flags n ticks
##   ["wait", n]                   idle n ticks
##   ["go", x, opts]               walk to x and stop there (opts: {"tol": px, "fight": bool, "keys": extra flags})
##   ["run", x, opts]              hold the direction until x is passed (no stop)
##   ["jump", dir, up, opts]       U (+dir) for `up` ticks, then dir until grounded (opts {"min": ticks, "air": flags})
##   ["leap", tx, up, opts]        jump, steer to tx in the air, until grounded
##   ["strike", flags]             F (+flags) for 8 ticks, then 2 idle
##   ["face", dir]                 a one-tick tap when facing the other way
##   ["until", Callable, flags]    hold flags until callable(level, hero) is true
##   ["fn", Callable]              callable(level, hero, n) -> flags, or -1 when done (n = ticks in this command)
##   ["sync", name]                co-op: idle until every slot reached this sync name
##   ["mark", text]                print a line
##   ["stamp", name]               remember this slot's tick and position under `name`
##   ["raw", PackedInt32Array]     play these flags
##   ["replay", src, a, b]         play the flags slot `src` played between its stamps a and b (exact copy)
##   ["ghost", src, delay, n]      play slot `src`'s flags of `delay` ticks ago, n ticks
##   ["hold", flags]               hold flags forever (the exit walk)

const L: int = Defs.IN_LEFT
const R: int = Defs.IN_RIGHT
const U: int = Defs.IN_UP
const D: int = Defs.IN_DOWN
const F: int = Defs.IN_FIRE
const K: int = Defs.IN_LOOK
const S: int = Defs.IN_SWAP

var mode: String = "beginner"
var players: int = 1
var opts: Dictionary = {}
var expert: bool = false
var level: LevelBase = null
var t: int = 0
var verbose: bool = true
var _progs: Array = []
var _pc: PackedInt32Array = PackedInt32Array()
var _n: PackedInt32Array = PackedInt32Array()
var _st: Array = []
var _syncs: Array = []
var _done: Array = []
var _released: Dictionary = {}
## Per slot: every flag value it played, and its feet point before each tick.
var hist: Array[PackedInt32Array] = []
var hx: Array[PackedInt32Array] = []
var hy: Array[PackedInt32Array] = []
## Per slot: stamp name -> [tick, x, y].
var stamps: Array[Dictionary] = []
var _diverged: Dictionary = {}
## Per slot: the section a follower last started ("progress" command).
var progress: Dictionary = {}
## The flags each slot chose on this tick so far (slot 0 first: the "mirror" command reads them).
var cur: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Route comments: [[tick, text], ...] (the "note" command; the first at tick 0).
var notes: Array = []
## Problems found while playing (printed at the end).
var problems: PackedStringArray = PackedStringArray()


func setup(p_mode: String, p_players: int, p_opts: Dictionary) -> void:
	mode = p_mode
	expert = mode == "expert"
	players = p_players
	opts = p_opts
	verbose = not p_opts.has("quiet_steps")
	_progs = build()
	_pc.resize(players)
	_n.resize(players)
	for s: int in players:
		_st.append({})
		_syncs.append("")
		_done.append(false)
		hist.append(PackedInt32Array())
		hx.append(PackedInt32Array())
		hy.append(PackedInt32Array())
		stamps.append({})


## Override: one program (Array of commands) per slot.
func build() -> Array:
	return [[]]


## Override: the route header lines (with the trailing newline).
func header() -> String:
	return ""


func hero(slot: int = 0) -> PlayerBase:
	if level == null or slot >= level.heroes.size():
		return null
	return level.heroes[slot]


func flags(p_level: LevelBase, tick: int) -> PackedInt32Array:
	level = p_level
	t = tick
	for s: int in players:
		var h: PlayerBase = hero(s)
		hx[s].append(h.sim_pos.x if h != null else 0)
		hy[s].append(h.sim_pos.y if h != null else 0)
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(players)
	var running: bool = false
	for s: int in players:
		out[s] = _slot_flags(s)
		cur[s] = out[s]
		if not _done[s]:
			running = true
	for s: int in players:
		hist[s].append(out[s])
	if not running:
		return PackedInt32Array()
	return out


func _slot_flags(s: int) -> int:
	var prog: Array = _progs[s] if s < _progs.size() else []
	var guard: int = 0
	while guard < 64:
		guard += 1
		if _pc[s] >= prog.size():
			_done[s] = true
			return 0
		var cmd: Array = prog[_pc[s]]
		if _n[s] == 0:
			_st[s] = {}
			if verbose:
				var h: PlayerBase = hero(s)
				print("STEP t=%d P%d #%d %s at %s" % [t, s + 1, _pc[s], _cmd_text(cmd), h.sim_pos if h != null else "-"])
		var f: int = _run(s, cmd)
		if f >= 0:
			_n[s] += 1
			return f
		_pc[s] += 1
		_n[s] = 0
	return 0


func _cmd_text(cmd: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item: Variant in cmd:
		if item is Callable:
			parts.append("<fn>")
		elif item is PackedInt32Array:
			parts.append("<%d flags>" % (item as PackedInt32Array).size())
		else:
			parts.append(str(item))
	return " ".join(parts)


## Flags of command `cmd` on this tick, or -1 when it is finished (then the next command runs on the same tick).
func _run(s: int, cmd: Array) -> int:
	var h: PlayerBase = hero(s)
	var n: int = _n[s]
	var st: Dictionary = _st[s]
	match str(cmd[0]):
		"keys":
			return int(cmd[2]) if n < int(cmd[1]) else -1
		"wait":
			return 0 if n < int(cmd[1]) else -1
		"hold":
			return int(cmd[1])
		"mark":
			print("MARK t=%d P%d %s at %s" % [t, s + 1, str(cmd[1]), h.sim_pos])
			return -1
		"note":
			if notes.is_empty() and t > 0:
				notes.append([0, "Start."])
			notes.append([t, str(cmd[1])])
			return -1
		"stamp":
			stamps[s][str(cmd[1])] = [t, h.sim_pos.x, h.sim_pos.y, h.facing, h.xvel, h.is_grounded()]
			if verbose:
				print("STAMP t=%d P%d %s at %s v%d,%d g%s" % [t, s + 1, str(cmd[1]), h.sim_pos, h.xvel, h.yvel,
					h.is_grounded()])
			return -1
		"raw":
			var arr: PackedInt32Array = cmd[1]
			return arr[n] if n < arr.size() else -1
		"replay":
			var src: int = int(cmd[1])
			var a: Array = stamps[src].get(str(cmd[2]), [])
			var b: Array = stamps[src].get(str(cmd[3]), [])
			if a.is_empty():
				_problem("P%d replay: stamp %s of P%d missing" % [s + 1, cmd[2], src + 1])
				return -1
			var index: int = int(a[0]) + n
			if not b.is_empty() and index >= int(b[0]):
				return -1
			if index >= hist[src].size():
				_problem("P%d replay overtook P%d at t=%d" % [s + 1, src + 1, t])
				return 0
			if n == 0 and (h.sim_pos.x != int(a[1]) or h.sim_pos.y != int(a[2])):
				_problem("P%d replay %s starts at %s, P%d was at (%d, %d)" % [s + 1, cmd[2], h.sim_pos, src + 1,
					int(a[1]), int(a[2])])
			_check_ghost(s, src, index)
			return hist[src][index]
		"replay_raw":
			# ["replay_raw", src, a, b]: play slot src's flags between its stamps a and b, from wherever this hero is.
			var src4: int = int(cmd[1])
			var a4: Array = stamps[src4].get(str(cmd[2]), [])
			var b4: Array = stamps[src4].get(str(cmd[3]), [])
			if a4.is_empty():
				return 0
			var index4: int = int(a4[0]) + n
			if not b4.is_empty() and index4 >= int(b4[0]):
				return -1
			if index4 >= hist[src4].size():
				return 0
			return hist[src4][index4]
		"goto_stamp_off":
			# ["goto_stamp_off", src, name, dx, max]: as goto_stamp, dx px beside that point.
			var so: Array = stamps[int(cmd[1])].get(str(cmd[2]), [])
			if so.is_empty():
				return 0
			return _goto(s, h, int(so[1]) + int(cmd[3]), int(so[3]), int(cmd[4]) if cmd.size() > 4 else 400, n)
		"mirror":
			# ["mirror", src, until_stamp]: the flags slot src (a lower slot) chose on this very tick, until src has
			# taken the stamp `until_stamp`.
			if stamps[int(cmd[1])].has(str(cmd[2])):
				return -1
			return cur[int(cmd[1])]
		"progress":
			progress[s] = int(cmd[1])
			return -1
		"replay_safe":
			# ["replay_safe", src, a, b]: as replay, but a falling hero never lands on the standing partner: he
			# steers away from him (and stops checking the copy).
			var src3: int = int(cmd[1])
			var a3: Array = stamps[src3].get(str(cmd[2]), [])
			var b3: Array = stamps[src3].get(str(cmd[3]), [])
			if a3.is_empty():
				_problem("P%d replay: stamp %s of P%d missing" % [s + 1, cmd[2], src3 + 1])
				return -1
			var index3: int = int(a3[0]) + n
			if not b3.is_empty() and index3 >= int(b3[0]):
				return -1
			if index3 >= hist[src3].size():
				return 0
			if n == 0:
				_diverged.erase(s)
				if h.sim_pos.x != int(a3[1]) or h.sim_pos.y != int(a3[2]) or h.facing != int(a3[3]):
					_problem("P%d replay %s starts at %s f%d, P%d was at (%d, %d) f%d" % [s + 1, cmd[2], h.sim_pos,
						h.facing, src3 + 1, int(a3[1]), int(a3[2]), int(a3[3])])
			var f3: int = hist[src3][index3]
			var other: PlayerBase = hero(src3)
			if bool(st.get("steer", false)) or (other != null and not other.is_down() and not h.is_grounded() and h.yvel >= -48 and absi(other.sim_pos.x - h.sim_pos.x) < 30 and other.sim_pos.y - h.sim_pos.y >= -4 and other.sim_pos.y - h.sim_pos.y <= 96 and not bool(cmd[4] if cmd.size() > 4 else false)):
				if not bool(st.get("steer", false)):
					st["steer"] = true
					st["away"] = signi(h.sim_pos.x - other.sim_pos.x) if h.sim_pos.x != other.sim_pos.x 						else -other.facing
					print("STEER t=%d P%d away from P%d (%s over %s)" % [t, s + 1, src3 + 1, h.sim_pos, other.sim_pos])
					_diverged[s] = true
				if h.is_grounded():
					return f3 & ~(L | R | U)
				return (f3 & ~(L | R)) | (R if int(st["away"]) > 0 else L)
			_check_ghost(s, src3, index3)
			return f3
		"ghost":
			var src2: int = int(cmd[1])
			var delay: int = int(cmd[2])
			if n >= int(cmd[3]):
				return -1
			var index2: int = t - delay
			if index2 < 0 or index2 >= hist[src2].size():
				return 0
			_check_ghost(s, src2, index2)
			return hist[src2][index2]
		"face":
			var dir: int = int(cmd[1])
			if n == 0 and h.facing != dir:
				return R if dir > 0 else L
			return -1
		"strike":
			var extra: int = int(cmd[1]) if cmd.size() > 1 else 0
			if n < 8:
				return F | extra
			return 0 if n < 10 else -1
		"jump":
			var dir: int = int(cmd[1])
			var up: int = int(cmd[2])
			var o: Dictionary = cmd[3] if cmd.size() > 3 else {}
			var dkey: int = (R if dir > 0 else (L if dir < 0 else 0))
			if n < up:
				return U | dkey
			var air: int = int(o.get("air", dkey))
			if n < int(o.get("min", 4)) or not h.is_grounded():
				if n > int(o.get("max", 120)):
					return -1
				return air
			return -1
		"run":
			var x: int = int(cmd[1])
			var o: Dictionary = cmd[2] if cmd.size() > 2 else {}
			if not st.has("dir"):
				st["dir"] = 1 if x > h.sim_pos.x else -1
			var dir: int = int(st["dir"])
			if (dir > 0 and h.sim_pos.x >= x) or (dir < 0 and h.sim_pos.x <= x):
				return -1
			var fight: int = _fight(h, o)
			if fight >= 0:
				return fight
			return (R if dir > 0 else L) | int(o.get("keys", 0))
		"go":
			var x: int = int(cmd[1])
			var o: Dictionary = cmd[2] if cmd.size() > 2 else {}
			var tol: int = int(o.get("tol", 2))
			var dx: int = x - h.sim_pos.x
			var fight: int = _fight(h, o)
			if fight >= 0:
				return fight
			if absi(dx) <= tol and h.xvel == 0 and h.is_grounded():
				return -1
			if n > int(o.get("max", 2000)):
				_problem("P%d go %d timed out at %s" % [s + 1, x, h.sim_pos])
				return -1
			var speed: int = absi(h.xvel)
			var stop: int = (speed * speed) / (2 * 12 * 16) + 2
			if h.xvel != 0 and signi(h.xvel) == signi(dx) and absi(dx) <= stop:
				return int(o.get("keys", 0))
			if h.xvel != 0 and signi(h.xvel) != signi(dx) and dx != 0:
				return int(o.get("keys", 0))
			if absi(dx) <= tol:
				return int(o.get("keys", 0))
			if speed == 0 and absi(dx) < 8:
				if int(st.get("tap", 0)) > 0:
					st["tap"] = int(st["tap"]) - 1
					return 0
				st["tap"] = 3
			return (R if dx > 0 else L) | int(o.get("keys", 0))
		"goto":
			# ["goto", x, facing, max]: stand still exactly at x facing `facing` (1-tick taps move 1 px).
			return _goto(s, h, int(cmd[1]), int(cmd[2]), int(cmd[3]) if cmd.size() > 3 else 400, n)
		"goto_stamp":
			# ["goto_stamp", src, name, max]: stand where slot src stood at its stamp, facing as it did.
			var sa: Array = stamps[int(cmd[1])].get(str(cmd[2]), [])
			if sa.is_empty():
				return 0
			return _goto(s, h, int(sa[1]), int(sa[3]), int(cmd[3]) if cmd.size() > 3 else 400, n)
		"leap":
			var tx: int = int(cmd[1])
			var up2: int = int(cmd[2])
			var o2: Dictionary = cmd[3] if cmd.size() > 3 else {}
			var keys2: int = 0
			var ddx: int = tx - h.sim_pos.x
			var lead: int = int(o2.get("lead", 3))
			if ddx > lead:
				keys2 = R
			elif ddx < -lead:
				keys2 = L
			if n < up2:
				return U | keys2
			if n > 2 and h.is_grounded():
				return -1
			if n > int(o2.get("max", 120)):
				return -1
			return keys2 | int(o2.get("air", 0))
		"until":
			var c: Callable = cmd[1]
			if c.call(level, h):
				return -1
			var limit: int = int(cmd[3]) if cmd.size() > 3 else 3000
			if n > limit:
				_problem("P%d until timed out at t=%d %s" % [s + 1, t, h.sim_pos])
				return -1
			return int(cmd[2]) if cmd.size() > 2 else 0
		"fn":
			var c: Callable = cmd[1]
			return int(c.call(level, h, n))
		"sync":
			var sync_name: String = str(cmd[1])
			if _released.has(sync_name):
				return -1
			_syncs[s] = sync_name
			for other: int in players:
				if str(_syncs[other]) != sync_name:
					# A waiting hero taps Down now and then: the IDLE rule (243 ticks) never takes him.
					return D if n % 120 == 119 else 0
			_released[sync_name] = true
			return -1
	push_error("bot: unknown command %s" % str(cmd))
	return -1


## Stand still exactly at x, facing `face` (+1 / -1): walk near, then taps (a 1-tick tap moves 1 px, a 2-tick tap
## 4 px) whose last one points `face` (so he comes from the other side).
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
	var slack: int = 0 if n < 60 else (1 if n < 120 else (2 if n < 180 else 4))
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


func _check_ghost(s: int, src: int, index: int) -> void:
	if _diverged.has(s):
		return
	var h: PlayerBase = hero(s)
	if index < hx[src].size() and (h.sim_pos.x != hx[src][index] or h.sim_pos.y != hy[src][index]):
		_diverged[s] = true
		_problem("P%d diverged from P%d at t=%d: %s vs (%d, %d) of t=%d" % [s + 1, src + 1, t, h.sim_pos,
			hx[src][index], hy[src][index], index])


## A new ghost / replay command may check again.
func reset_divergence() -> void:
	_diverged.clear()


func _problem(text: String) -> void:
	problems.append(text)
	print("PROBLEM " + text)


func report() -> void:
	print("BOT problems: %d" % problems.size())
	for p: String in problems:
		print("  " + p)


## A strike at an enemy in front (opts "fight": true): -1 when there is nothing to do. Strikes when the enemy's box
## will overlap the forward club box (11..35 px in front, 2..15 px over the feet) 4-7 ticks from now; stops walking
## while an enemy closes in ahead; turns to one closing in from behind.
func _fight(h: PlayerBase, o: Dictionary) -> int:
	if not bool(o.get("fight", false)):
		return -1
	var st: Dictionary = _st[h.slot]
	if int(st.get("striking", 0)) > 0:
		st["striking"] = int(st["striking"]) - 1
		return (F | int(st.get("strike_keys", 0))) if int(st["striking"]) > 3 else 0
	if not h.is_grounded():
		return -1
	var wait: bool = false
	var turn: int = 0
	var f: int = h.facing
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead or not foe.awake or not foe.tangible:
			continue
		if o.has("ignore") and (o["ignore"] as Array).has(String(foe.name)):
			continue
		var dx: float = foe.sim_pos.x - h.sim_pos.x
		var dy: float = foe.sim_pos.y - h.sim_pos.y
		var vx: float = foe.xvel / 16.0
		var vy: float = foe.yvel / 16.0
		var hv: float = h.xvel / 16.0
		for k: int in [4, 5, 6, 7]:
			var fx: float = dx + (vx - hv * 0.5) * k
			var fy2: float = dy + vy * k
			var left: float = fx - foe.box_xo
			var right: float = left + foe.box_w
			var top: float = fy2 - foe.box_h
			var club_near: float = 11.0
			var club_far: float = 35.0
			var hit_x: bool = (right > club_near and left < club_far) if f > 0 else (left < -club_near and right > -club_far)
			var hit_y: bool = fy2 > -15.0 and top < -2.0
			if hit_x and hit_y:
				st["striking"] = 9
				st["strike_keys"] = 0
				return F
			var high_x: bool = (right > 10.0 and left < 26.0) if f > 0 else (left < -10.0 and right > -26.0)
			var high_y: bool = fy2 > -43.0 and top < -27.0
			if high_x and high_y and not bool(o.get("no_high", false)):
				st["striking"] = 9
				st["strike_keys"] = U
				return F | U
		var closing: bool = vx * signf(-dx) > 0.2
		if dy > -80.0 and dy < 30.0 and dx * f > 0 and absf(dx) < float(o.get("wait_px", 70)) and closing:
			wait = true
		if absf(dy) < 30.0 and dx * f < 0 and absf(dx) < 56.0 and closing:
			turn = -f
	if turn != 0:
		return R if turn > 0 else L
	if wait:
		return 0
	return -1


## Strike (forward, or with `extra` keys) whenever grounded and not striking, until the hittable whose cell is `cell`
## is opened (a big spot, a block).
func open_fn(cell: Vector2i, extra: int = 0) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		for entity: SimEntity in lv.get_kind(Defs.Kind.HITTABLE):
			var spot: HittableBase = entity as HittableBase
			if spot != null and spot.cell == cell and spot.opened:
				return -1
		if n > 600:
			return -1
		var st: Dictionary = _st[h.slot]
		if bool(st.get("pressed", false)):
			st["pressed"] = false
			return 0
		if not h.is_grounded() or h.is_striking():
			return 0
		st["pressed"] = true
		return F | extra


## Leader-follower programs from a solo route's sections ([[comment, flags], ...]): P1 plays each section as the solo
## hero did; P2 replays it from the same standing point (goto_stamp + replay_safe) once P1 has moved `lead` px on or
## finished it, and P1 waits before a section until P2 began the previous one (the tribe stays on one view).
## cfg: "skip": [k] (P2 does not replay section k), "p2": {k: [commands]} (P2's own commands instead), "p1": {k:
## [commands]} (P1's own commands instead of the solo keys), "p1_after": {k: [commands]} / "p2_after": {k: [...]}
## (extra commands after section k), "nowait": [k] (P1 does not wait before k), "lead": px [48].
func follow(sections: Array, cfg: Dictionary) -> Array:
	var p1: Array = []
	var p2: Array = []
	var skip: Array = cfg.get("skip", [])
	var c1: Dictionary = cfg.get("p1", {})
	var c2: Dictionary = cfg.get("p2", {})
	var a1: Dictionary = cfg.get("p1_after", {})
	var b1: Dictionary = cfg.get("p1_before", {})
	var manual: Array = cfg.get("p2_progress_manual", [])
	var a2: Dictionary = cfg.get("p2_after", {})
	var nowait: Array = cfg.get("nowait", [])
	var lead: int = int(cfg.get("lead", 48))
	var gap: int = int(cfg.get("gap", 2))
	for k: int in sections.size():
		var sk: String = "s%d" % k
		var ek: String = "e%d" % k
		var need: int = -1
		for j: int in range(k - gap, -1, -1):
			if c2.has(j) or not skip.has(j):
				need = j
				break
		if b1.has(k):
			p1.append_array(b1[k])
		if k > 0 and need >= 0 and not nowait.has(k):
			# P1 goes on at once when P2 is near enough; else he waits, and comes to rest before his next section.
			var need_k: int = need
			p1.append(["fn", func(_lv: LevelBase, hh: PlayerBase, n: int) -> int:
				if n == 0 and int(progress.get(1, -1)) >= need_k:
					return -1
				if n > 4000:
					_problem("P1 waited for P2 too long at t=%d" % t)
					return -1
				if int(progress.get(1, -1)) >= need_k and hh.xvel == 0 and hh.is_grounded():
					return -1
				return 0])
		p1.append(["stamp", sk])
		p1.append(["note", str(sections[k][0])])
		if c1.has(k):
			p1.append_array(c1[k])
		else:
			p1.append(["raw", sections[k][1]])
		p1.append(["stamp", ek])
		if a1.has(k):
			p1.append_array(a1[k])
		if c2.has(k):
			if not manual.has(k):
				p2.append(["progress", k])
			p2.append_array(c2[k])
		elif not skip.has(k):
			var key_s: String = sk
			var key_e: String = ek
			p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool:
				if stamps[0].has(key_e):
					return true
				var st0: Array = stamps[0].get(key_s, [])
				var me: PlayerBase = hero(0)
				return not st0.is_empty() and me != null and (absi(me.sim_pos.x - int(st0[1])) >= lead 					or absi(me.sim_pos.y - int(st0[2])) >= lead), 0, 4000])
			p2.append(["goto_stamp", 0, sk])
			p2.append(["progress", k])
			p2.append(["replay_safe", 0, sk, ek])
		if a2.has(k):
			p2.append_array(a2[k])
	return [p1, p2]


## The moving platform whose home lies nearest to cell (col, row) (within 2 cells), or null.
func platform_near(col: float, row: float) -> MovingPlatform:
	var best: MovingPlatform = null
	var best_d: int = 1 << 30
	var at: Vector2i = Vector2i(int(col * 16.0) + 8, int(row * 16.0) + 16)
	for e: SimEntity in level.get_kind(Defs.Kind.PLATFORM):
		var mp: MovingPlatform = e as MovingPlatform
		if mp == null:
			continue
		var d: int = absi(mp.home.x - at.x) + absi(mp.home.y - at.y)
		if d < best_d:
			best_d = d
			best = mp
	return best if best_d <= 40 else null


## True when platform `mp` stands at its home and does not move.
static func at_home(mp: MovingPlatform) -> bool:
	return mp != null and mp.sim_pos == mp.home and mp.velocity == 0


## Solo stamps (bot_solo_stamps.gd JSON): "s<k>" -> [tick, x, y, facing, xvel, grounded] of the solo hero.
var solo: Dictionary = {}


func load_solo(path: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		solo = data


## Stand where the solo hero stood at the start of solo section k (exact x, facing).
func goto_solo(k: int, limit: int = 400) -> Array:
	var key: String = "s%d" % k
	return ["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var a: Array = solo.get(key, [])
		if a.is_empty():
			_problem("no solo stamp %s" % key)
			return -1
		return _goto(h.slot, h, int(a[1]), int(a[3]), limit, n)]


## Walk in direction `dir` until `done` (callable(hero) -> bool) holds.
func walk_until(dir: int, done: Callable, limit: int = 600) -> Array:
	return ["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if done.call(h):
			return -1
		if n > limit:
			_problem("P%d walk_until timed out at %s" % [h.slot + 1, h.sim_pos])
			return -1
		return R if dir > 0 else L]


## Wait (tapping Down now and then, never idle 243 ticks) until `done` (callable(hero) -> bool) holds.
func wait_until(done: Callable, limit: int = 3000) -> Array:
	return ["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if done.call(h):
			return -1
		if n > limit:
			_problem("P%d wait_until timed out at %s" % [h.slot + 1, h.sim_pos])
			return -1
		return D if n % 150 == 149 else 0]


## The first live enemy whose feet x lies in cells c0..c1 and feet y in rows r0..r1 (null when none).
func enemy_in(c0: int, c1: int, r0: int, r1: int) -> EnemyBase:
	for e: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = e as EnemyBase
		if foe != null and not foe.dead and foe.sim_pos.x >= c0 * 16 and foe.sim_pos.x < (c1 + 1) * 16 \
				and foe.sim_pos.y > r0 * 16 and foe.sim_pos.y <= (r1 + 1) * 16:
			return foe
	return null


## The Shellback pincer (shell trait: the shield faces the nearer hero): the BAIT gets to the far side of the turtle
## (a jump over it) and keeps about 30 px from it; the STRIKER keeps his side and clubs its back from about 38 px once
## the bait is nearer and the shield faces the bait. Done (-1) when no target lies in the box (c0..c1, r0..r1).
## opts: "bait_px" [30], "strike_px" [38], "bait_side" (+1 / -1: the side the bait takes; default: away from the
## striker), "max" [1500].
func pincer_fn(role: String, box: Rect2i, o: Dictionary = {}) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var foe: EnemyBase = enemy_in(box.position.x, box.end.x - 1, box.position.y, box.end.y - 1)
		var st: Dictionary = _st[h.slot]
		if int(st.get("hold", 0)) > 0:
			st["hold"] = int(st["hold"]) - 1
			return int(st["hold_key"])
		if foe == null:
			if not h.is_grounded():
				return 0
			return -1
		if n > int(o.get("max", 1500)):
			_problem("P%d pincer (%s) timed out at %s, target at %s" % [h.slot + 1, role, h.sim_pos, foe.sim_pos])
			return -1
		if h.is_down():
			return 0
		var other: PlayerBase = hero(1 - h.slot)
		var dx: int = h.sim_pos.x - foe.sim_pos.x
		var dist: int = absi(dx)
		var to_foe: int = R if dx < 0 else L
		var away: int = L if dx < 0 else R
		if role == "bait":
			var want: int = int(o.get("bait_side", 0))
			if want == 0:
				want = -signi(other.sim_pos.x - foe.sim_pos.x) if other.sim_pos.x != foe.sim_pos.x else 1
			var side: int = signi(dx) if dx != 0 else -want
			if not h.is_grounded():
				# In a crossing jump keep going over the target.
				return int(st.get("air_key", 0))
			if side != want:
				# Cross: run at it and jump over when close.
				if dist <= 44 and h.no_jump == 0:
					st["hold"] = 9
					st["hold_key"] = U | to_foe
					st["air_key"] = to_foe
					return U | to_foe
				return to_foe
			var near: int = int(o.get("bait_px", 30))
			if dist < near - 3:
				return away
			if dist > near + 4:
				return to_foe if h.xvel == 0 or signi(h.xvel) != signi(-dx) else 0
			return 0
		# Striker.
		var odx: int = other.sim_pos.x - foe.sim_pos.x
		var bait_ok: bool = signi(odx) == -signi(dx) and absi(odx) + 4 < dist and foe.facing == signi(odx) \
				and not other.is_down()
		var reach: int = int(o.get("strike_px", 38))
		if not h.is_grounded():
			return 0
		if h.facing != -signi(dx) and dx != 0 and not h.is_striking():
			st["pause"] = 2
			return to_foe
		if bait_ok and dist >= reach - 8 and dist <= reach + 6 and not h.is_striking() and h.xvel == 0:
			st["hold"] = 8
			st["hold_key"] = F
			return F
		if not bait_ok:
			# Stay out of the way until the bait is in place.
			if dist < 56:
				return away
			return 0
		if dist > reach + 6:
			return to_foe
		if dist < reach - 8:
			return away
		return 0


## The flags of a route file's body (one stream), split at its comment lines: [[comment, PackedInt32Array], ...].
static func route_sections(path: String, slot: int = 0) -> Array:
	var out: Array = []
	var comment: String = ""
	var body: String = ""
	for raw_line: String in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("#"):
			if body != "":
				out.append([comment, _parse_slot(body, slot)])
				body = ""
				comment = ""
			comment += (" " if comment != "" else "") + line.substr(1).strip_edges()
		elif line != "":
			body += line + ","
	if body != "":
		out.append([comment, _parse_slot(body, slot)])
	return out


static func _parse_slot(body: String, slot: int) -> PackedInt32Array:
	var text: String = body.trim_suffix(",")
	if text.contains("|"):
		return Autoplay.parse_inputs_multi(text)[slot]
	return Autoplay.parse_inputs(text)


## Concatenated flags of the sections [a, b) of `sections`.
static func join_sections(sections: Array, a: int, b: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in range(a, mini(b, sections.size())):
		out.append_array(sections[i][1])
	return out


## Cell helpers.
static func cx(col: float) -> int:
	return int(col * 16.0) + 8


static func fy(row: int) -> int:
	return (row + 1) * 16
