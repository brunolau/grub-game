extends RefCounted
## DB3 bot library (from D6's; development only, build/ is not versioned): a program per hero slot, one command after the other,
## each command a per-tick flag source. probe_work.gd records the flags as a route file.
##
## Commands (Arrays):
##   ["keys", n, flags]            hold flags n ticks
##   ["wait", n]                   idle n ticks
##   ["go", x, opts]               walk to x and stop there (opts: {"tol": px, "fight": bool, "keys": extra flags})
##   ["run", x, opts]              hold the direction until x is passed (no stop)
##   ["jump", dir, up, opts]       U (+dir) for `up` ticks, then dir until grounded (opts {"min": ticks, "air": flags})
##   ["strike", flags]             F (+flags) for 8 ticks, then 2 idle
##   ["face", dir]                 a one-tick tap when facing the other way
##   ["until", Callable, flags]    hold flags until callable(level, hero) is true
##   ["fn", Callable]              callable(level, hero, n) -> flags, or -1 when done (n = ticks in this command)
##   ["sync", name]                co-op: idle until every slot reached this sync name
##   ["mark", text]                print a line
##   ["hold", flags]               hold flags forever (the exit walk)
##   ["trail", other, dx, until]   keep at the other hero's x + dx until until(level, hero)
##   ["shadow", until, opts]       (P2) replay P1's inputs from where he stood still, parking behind him (see _shadow)

const L: int = Defs.IN_LEFT
const R: int = Defs.IN_RIGHT
const U: int = Defs.IN_UP
const D: int = Defs.IN_DOWN
const F: int = Defs.IN_FIRE

var mode: String = "beginner"
var players: int = 1
var opts: Dictionary = {}
var expert: bool = false
var level: LevelBase = null
var t: int = 0
var _progs: Array = []
var _pc: PackedInt32Array = PackedInt32Array()
var _n: PackedInt32Array = PackedInt32Array()
var _st: Array = []
var _syncs: Array = []
var _done: Array = []
## No hero may stay without input this long (the idle-partner rule counts 243 ticks): a one-tick Down tap then.
var anti_idle: int = 160
var _quiet: PackedInt32Array = PackedInt32Array()


func setup(p_mode: String, p_players: int, p_opts: Dictionary) -> void:
	mode = p_mode
	expert = mode == "expert"
	players = p_players
	opts = p_opts
	# a fresh run (the probe calls setup again for every attempt; `fixes` and the search stack are kept)
	_pc = PackedInt32Array()
	_n = PackedInt32Array()
	_quiet = PackedInt32Array()
	_st = []
	_syncs = []
	_done = []
	_released = {}
	_ovr = []
	rec_flags = PackedInt32Array()
	rec_x = PackedInt32Array()
	rec_y = PackedInt32Array()
	rec_parked = PackedByteArray()
	rec_still = PackedByteArray()
	_first_hurt = []
	_abort = false
	_marks = {}
	_pc.resize(players)
	_n.resize(players)
	_quiet.resize(players)
	for s: int in players:
		_st.append({})
		_syncs.append("")
		_done.append(false)
		_ovr.append([0, 0])
	learn = opts.has("learn")
	if not _fixes_loaded and opts.has("fixes_in"):
		_fixes_loaded = true
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(opts["fixes_in"])))
		if data is Dictionary:
			for key: String in data:
				fixes[key] = [int(data[key][0]), int(data[key][1])]
		print("LEARN: %d fixes loaded from %s" % [fixes.size(), opts["fixes_in"]])
	if not _hurt_connected:
		_hurt_connected = true
		Events.hero_hurt.connect(_on_hurt)
		Events.hero_down.connect(func(hero_node: PlayerBase, _cause: StringName) -> void: _on_hurt(hero_node, -1, null))
		Events.hero_died.connect(func(hero_node: PlayerBase, _cause: StringName) -> void: _on_hurt(hero_node, -1, null))
	_progs = build()


# --- Learning from hurts (opts "learn"): a depth-first search over local fixes ----------------------------------
## Learned overrides: "slot:tick" -> [flags, ticks] (pressed instead of the program's flags from that tick on).
var fixes: Dictionary = {}
var learn: bool = false
var _fixes_loaded: bool = false


## The fixes as JSON (the probe's report: opts "fixes_out").
func save_fixes() -> void:
	if opts.has("fixes_out"):
		var out: FileAccess = FileAccess.open(str(opts["fixes_out"]), FileAccess.WRITE)
		out.store_string(JSON.stringify(fixes))
		out.close()
var _hurt_connected: bool = false
var _first_hurt: Array = []
var _abort: bool = false
var _ovr: Array = []
var _marks: Dictionary = {}
## The search stack: [slot, hurt tick, candidate index, fix key or ""] per hurt being fixed.
var _stack: Array = []
var _attempts: int = 0
## Candidate fixes for a hurt at tick T: [ticks before T, flags, ticks held].
const FIX_CANDIDATES: Array = [[6, U, 2], [10, U, 3], [6, U, 3], [14, U, 3], [10, L, 8], [10, R, 8], [16, L, 12],
	[16, R, 12], [4, U, 2], [20, U, 3], [8, 0, 12], [22, L, 14], [22, R, 14], [12, D, 10], [26, U, 3], [30, L, 16],
	[30, R, 16]]


func _on_hurt(hero_node: PlayerBase, _kind: int, _source: SimEntity) -> void:
	if not learn or not _first_hurt.is_empty() or hero_node == null:
		return
	# opts "downs_only": a hurt is allowed (the header asks only eggs:0, wipes:0); only a downed / dead hero, or a
	# hurt that leaves him on his last heart, asks for a repair
	if opts.has("downs_only") and _kind >= 0 and hero_node.run != null and hero_node.run.hearts > 0:
		return
	_first_hurt = [hero_node.slot, t]
	_abort = true


func report() -> void:
	save_fixes()


func aborted() -> bool:
	return _abort


## Called by the probe after an aborted attempt: pick the next fix (depth-first). False when the search gives up.
func retry() -> bool:
	save_fixes()
	if _first_hurt.is_empty():
		return false
	_attempts += 1
	if _attempts > int(opts.get("max_attempts", "400")):
		print("LEARN: giving up after %d attempts" % _attempts)
		return false
	var slot: int = int(_first_hurt[0])
	var tick: int = int(_first_hurt[1])
	if not _stack.is_empty() and tick <= int(_stack[-1][1]):
		# no progress: the next candidate for the hurt on top of the stack
		return _next_candidate()
	_stack.append([slot, tick, -1, ""])
	print("LEARN: hurt P%d at tick %d (depth %d, %d fixes)" % [slot + 1, tick, _stack.size(), fixes.size()])
	return _next_candidate()


func _next_candidate() -> bool:
	while not _stack.is_empty():
		var top: Array = _stack[-1]
		if str(top[3]) != "":
			fixes.erase(str(top[3]))
		var index: int = int(top[2]) + 1
		while index < FIX_CANDIDATES.size():
			var c: Array = FIX_CANDIDATES[index]
			var at: int = int(top[1]) - int(c[0])
			var key: String = "%d:%d" % [int(top[0]), at]
			if at > 0 and not fixes.has(key):
				fixes[key] = [int(c[1]), int(c[2])]
				top[2] = index
				top[3] = key
				return true
			index += 1
		# every candidate failed: backtrack
		_stack.pop_back()
		print("LEARN: backtrack (depth %d)" % _stack.size())
	return false


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
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(players)
	var running: bool = false
	if _abort:
		return PackedInt32Array()
	# stuck (opts "stuck"=N): neither hero moved more than 4 px in the last N ticks - treated as a hurt of P1 now
	if learn and opts.has("stuck") and tick % 50 == 0 and hero(0) != null:
		var mark: Vector4i = Vector4i(hero(0).sim_pos.x, hero(0).sim_pos.y,
				hero(1).sim_pos.x if players > 1 else 0, hero(1).sim_pos.y if players > 1 else 0)
		_marks[tick] = mark
		var back: int = tick - int(opts["stuck"])
		if _marks.has(back):
			var old: Vector4i = _marks[back]
			if absi(old.x - mark.x) + absi(old.y - mark.y) + absi(old.z - mark.z) + absi(old.w - mark.w) <= 8:
				print("LEARN: stuck since tick %d" % back)
				_first_hurt = [0, tick]
				_abort = true
				return PackedInt32Array()
	for s: int in players:
		out[s] = _slot_flags(s)
		var fkey: String = "%d:%d" % [s, tick]
		if fixes.has(fkey):
			_ovr[s] = (fixes[fkey] as Array).duplicate()
			print("FIX t=%d P%d %d x%d" % [tick, s + 1, int(_ovr[s][0]), int(_ovr[s][1])])
		if int(_ovr[s][1]) > 0:
			out[s] = int(_ovr[s][0])
			_ovr[s][1] = int(_ovr[s][1]) - 1
		if not _done[s]:
			running = true
		if out[s] == 0:
			_quiet[s] += 1
			if anti_idle > 0 and _quiet[s] >= anti_idle and hero(s) != null and hero(s).is_grounded():
				out[s] = Defs.IN_LOOK
				_quiet[s] = 0
		else:
			_quiet[s] = 0
	if not running:
		return PackedInt32Array()
	# P1's record for the shadow command (his flags and where he stood when they were given)
	var lead: PlayerBase = hero(0)
	if lead != null:
		rec_flags.append(out[0])
		rec_x.append(lead.sim_pos.x)
		rec_y.append(lead.sim_pos.y)
		rec_parked.append(1 if (lead.is_grounded() and lead.xvel == 0 and lead.yvel == 0 and not lead.is_striking()) else 0)
		rec_still.append(1 if (lead.is_grounded() and lead.xvel == 0 and lead.yvel == 0) else 0)
	return out


## P1's flags per tick and his feet when they were given (the shadow command replays them for P2).
var rec_flags: PackedInt32Array = PackedInt32Array()
var rec_x: PackedInt32Array = PackedInt32Array()
var rec_y: PackedInt32Array = PackedInt32Array()
var rec_parked: PackedByteArray = PackedByteArray()
## P1 stood still on that tick (grounded, no speed; striking or not): the follower skips such stretches of the trail.
var rec_still: PackedByteArray = PackedByteArray()
var shadow_gap: int = 36


## The shadow (P2 only): replay P1's own inputs (without strikes) from the last spot where P1 stood still, a little
## later, so P2 walks, jumps and drops exactly where P1 did; P2 parks `shadow_gap` px behind P1 whenever P1 stands
## still ahead, and resumes from the spot P1 leaves. Done when `until` is true.
func _shadow(h: PlayerBase, st: Dictionary, until: Callable, o: Dictionary) -> int:
	if until.call(level, h):
		return -1
	var a: PlayerBase = hero(0)
	var now: int = rec_flags.size()
	var gap: int = int(o.get("gap", shadow_gap))
	var mode: String = str(st.get("mode", "seek"))
	if mode == "seek":
		if not st.has("resume"):
			# the most recent spot P1 stood still on P2's floor and has left by `gap` px
			var i: int = now - 1
			while i >= 0:
				if rec_parked[i] == 1 and absi(rec_y[i] - h.sim_pos.y) <= 3 and absi(a.sim_pos.x - rec_x[i]) >= gap:
					break
				i -= 1
			if i < 0:
				return 0
			st["resume"] = i
		var rx: int = rec_x[int(st["resume"])]
		if absi(h.sim_pos.x - rx) <= 1 and h.xvel == 0 and h.is_grounded():
			if absi(a.sim_pos.x - rx) < gap and a.is_grounded():
				return 0
			st["mode"] = "replay"
			st["j"] = int(st["resume"])
			st.erase("resume")
			return _shadow(h, st, until, o)
		return _go_x(h, st, rx, 0)
	if mode == "replay":
		var j: int = int(st["j"])
		if j >= now:
			return 0
		if h.is_grounded() and a.is_grounded() and a.xvel == 0:
			var d: int = a.sim_pos.x - h.sim_pos.x
			var dir: int = signi(h.xvel) if h.xvel != 0 else signi(d)
			if d * dir >= 0 and absi(d) <= gap + 20 and absi(a.sim_pos.y - h.sim_pos.y) <= 3 					and not _jump_ahead(j, now):
				st["mode"] = "park"
				st["park_x"] = a.sim_pos.x
				return 0
		st["j"] = j + 1
		return rec_flags[j] & ~F
	# park: stand behind P1 until he leaves his spot by `gap` px, then seek it
	var park_x: int = int(st["park_x"])
	if absi(a.sim_pos.x - park_x) >= gap:
		st["mode"] = "seek"
		st.erase("resume")
		return _shadow(h, st, until, o)
	var side: int = 1 if park_x >= h.sim_pos.x else -1
	return _go_x(h, st, park_x - gap * side, 3)


func _jump_ahead(from: int, to: int) -> bool:
	for i: int in range(from, mini(to, rec_flags.size())):
		if (rec_flags[i] & U) != 0:
			return true
	return false


## Walk to x and stop (with a tap near it).
func _go_x(h: PlayerBase, st: Dictionary, x: int, tol: int) -> int:
	var dx: int = x - h.sim_pos.x
	var speed: int = absi(h.xvel)
	var stop: int = (speed * speed) / (2 * 12 * 16) + 1
	if h.xvel != 0 and signi(h.xvel) == signi(dx) and absi(dx) <= stop:
		return 0
	if h.xvel != 0 and signi(h.xvel) != signi(dx) and dx != 0:
		return 0
	if absi(dx) <= tol:
		return 0
	if speed == 0 and absi(dx) < 8:
		if int(st.get("tap", 0)) > 0:
			st["tap"] = int(st["tap"]) - 1
			return 0
		st["tap"] = 2
	return R if dx > 0 else L


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
			if str(opts.get("steps", "1")) != "0":
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
			if not h.is_grounded():
				st["flew"] = true
			if n < up:
				return U | dkey
			var air: int = int(o.get("air", dkey))
			if n < int(o.get("min", 4)) or not h.is_grounded() or (not bool(st.get("flew", false)) and n < 30):
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
				# tap
				if int(st.get("tap", 0)) > 0:
					st["tap"] = int(st["tap"]) - 1
					return 0
				st["tap"] = 3
			return (R if dx > 0 else L) | int(o.get("keys", 0))
		"leap":
			# ["leap", target_x, up_ticks, opts]: jump, steer to target_x in the air, until grounded again.
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
			if n < int(o2.get("delay", 0)):
				keys2 = 0
			if not h.is_grounded():
				st["flew"] = true
			if n < up2:
				return U | keys2
			if h.is_grounded() and (bool(st.get("flew", false)) or n > 30):
				return -1
			if n > int(o2.get("max", 120)):
				return -1
			return keys2 | int(o2.get("air", 0))
		"trail":
			# ["trail", other_slot, offset_px, until_callable, opts]: keep at the other hero's x + offset (walk there
			# and stop), jumping when he jumps over something close ahead; done when until(level, h) is true.
			var other: PlayerBase = hero(int(cmd[1]))
			var c2: Callable = cmd[3]
			var o3: Dictionary = cmd[4] if cmd.size() > 4 else {}
			if c2.call(level, h):
				return -1
			if int(st.get("air", 0)) > 0:
				st["air"] = int(st["air"]) - 1
				return int(st.get("air_keys", 0))
			var tx: int = other.sim_pos.x + int(cmd[2])
			var dxt: int = tx - h.sim_pos.x
			var fight2: int = _fight(h, o3)
			if fight2 >= 0:
				return fight2
			var sp: int = absi(h.xvel)
			var stp: int = (sp * sp) / (2 * 12 * 16) + 2
			if absi(dxt) <= int(o3.get("tol", 6)):
				return 0
			if h.xvel != 0 and signi(h.xvel) == signi(dxt) and absi(dxt) <= stp:
				return 0
			return (R if dxt > 0 else L)
		"shadow":
			return _shadow(h, st, cmd[1], cmd[2] if cmd.size() > 2 else {})
		"follow":
			return _follow(h, st, int(cmd[1]), cmd[2], cmd[3] if cmd.size() > 3 else {})
		"until":
			var c: Callable = cmd[1]
			if c.call(level, h):
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
					return 0
			_released[sync_name] = true
			return -1
	push_error("bot: unknown command %s" % str(cmd))
	return -1


var _released: Dictionary = {}


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


## Cell helpers.
static func cx(col: float) -> int:
	return int(col * 16.0) + 8


static func fy(row: int) -> int:
	return (row + 1) * 16


# --- Duo routines -------------------------------------------------------------------------------------------------

## The nearest living, awake `daze` enemy (a Raptor) whose x lies in [x0, x1], or null.
func daze_target(x0: int, x1: int, near: PlayerBase) -> EnemyBase:
	var best: EnemyBase = null
	var best_d: int = 1 << 30
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead or not foe.tangible:
			continue
		var traits: CoopTraits = foe.coop_traits()
		if traits == null or traits.kind != Defs.CoopTrait.DAZE:
			continue
		if foe.sim_pos.x < x0 or foe.sim_pos.x > x1:
			continue
		var d: int = absi(foe.sim_pos.x - near.sim_pos.x)
		if d < best_d:
			best_d = d
			best = foe
	return best


## Kill every Raptor (`daze`) between x0 and x1 as a pair: the "bounce" hero jumps onto its head (it is dazed), the
## "strike" hero waits beside it facing it and clubs it while it is dazed. Done when none is left (or after `max`).
func duo_daze_fn(role: String, x0: int, x1: int, max_ticks: int = 1500) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var other: PlayerBase = hero(1 - h.slot)
		var target: EnemyBase = daze_target(x0, x1, other if role == "strike" else h)
		if target == null or n > max_ticks:
			return -1 if h.is_grounded() else 0
		var dazed: int = target.coop_traits().dazed
		var dx: int = target.sim_pos.x - h.sim_pos.x
		if int(st.get("striking", 0)) > 0:
			st["striking"] = int(st["striking"]) - 1
			return F if int(st["striking"]) > 2 else 0
		if role == "strike":
			if dazed > 0 and h.is_grounded():
				if h.facing != signi(dx) and dx != 0:
					return R if dx > 0 else L
				if absi(dx) >= 14 and absi(dx) <= 34:
					st["striking"] = 10
					return F
			# keep about 26 px from it on my side (the side away from the bouncer when I can), facing it
			var side: int = -signi(dx) if dx != 0 else -1
			var want: int = target.sim_pos.x + side * 26
			var ddx: int = want - h.sim_pos.x
			if not h.is_grounded():
				return 0
			if absi(ddx) > 4:
				if target.coop_traits().dazed <= 0 and absi(dx) < 18:
					# too close to an awake one: step back
					return R if dx < 0 else L
				return R if ddx > 0 else L
			if h.facing != signi(dx) and dx != 0:
				return R if dx > 0 else L
			return 0
		# the bouncer
		if bool(st.get("air", false)):
			if h.is_grounded() and int(st.get("air_n", 0)) > 3:
				st["air"] = false
				return 0
			st["air_n"] = int(st.get("air_n", 0)) + 1
			var k: int = U if int(st["air_n"]) < 12 else 0
			if absi(dx) > 2:
				k |= R if dx > 0 else L
			return k
		if dazed > 0:
			return 0
		# how long the Raptor has stood since its last hop (it hops again after its pause of 22 ticks)
		if target._grounded:
			st["ground_n"] = int(st.get("ground_n", 0)) + 1
		else:
			st["ground_n"] = 0
		if not h.is_grounded():
			return 0
		var settled: int = int(st.get("ground_n", 0))
		if absi(dx) <= 40 and target._grounded and (settled <= 6 or settled > 40):
			st["air"] = true
			st["air_n"] = 0
			return U | (R if dx > 0 else L)
		if absi(dx) > 40:
			return R if dx > 0 else L
		return 0


## Get past the walkers (and anything else on the floor) between me and x_goal by jumping over them (a head bounce
## is fine): walk; when one is within 44 px ahead and I am grounded, jump with the direction held. Done at x_goal.
func pass_fn(x_goal: int, max_ticks: int = 600) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var dir: int = 1 if x_goal > h.sim_pos.x else -1
		if absi(x_goal - h.sim_pos.x) <= 3 and h.is_grounded():
			return -1
		if n > max_ticks:
			return -1
		var key: int = R if dir > 0 else L
		if int(st.get("air_n", -1)) >= 0:
			st["air_n"] = int(st["air_n"]) + 1
			if h.is_grounded() and int(st["air_n"]) > 3:
				st["air_n"] = -1
			else:
				return (U if int(st["air_n"]) < 14 else 0) | key
		if not h.is_grounded():
			return key
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe == null or foe.dead or not foe.awake or not foe.tangible:
				continue
			var dx: int = (foe.sim_pos.x - h.sim_pos.x) * dir
			if dx > 0 and dx <= 44 and absi(foe.sim_pos.y - h.sim_pos.y) < 24:
				st["air_n"] = 0
				return U | key
		return key


## The breadcrumb follower (P2 only): play P1's own flags of `delay` ticks ago (strikes, swaps and looks left out),
## steering toward where P1 stood then whenever this hero is more than `tol` px from that spot (a recovery after a
## knock-back or a different landing). Done when until(level, h) is true.
func _follow(h: PlayerBase, _st: Dictionary, delay: int, until: Callable, o: Dictionary) -> int:
	if until.call(level, h):
		return -1
	var j: int = rec_flags.size() - 1 - delay
	if j < 0:
		return 0
	var f: int = rec_flags[j] & ~(F | Defs.IN_SWAP | Defs.IN_LOOK)
	if not bool(o.get("down", false)):
		f &= ~D
	var target_x: int = rec_x[j]
	var lead0: PlayerBase = hero(0)
	# P1 falls past my floor close by: stand still until he has landed (a falling hero whose box swings under my
	# feet is lifted onto my head and into the rock, G54)
	if bool(o.get("hold", true)) and lead0 != null and h.is_grounded() and not lead0.is_grounded() and lead0.sim_pos.y > h.sim_pos.y 			and lead0.sim_pos.y - h.sim_pos.y < 64 and absi(lead0.sim_pos.x - h.sim_pos.x) < 64:
		return 0
	# P1 stands on a floor just below me: never walk off my ledge onto his head
	var step_dir: int = 1 if (f & R) != 0 else (-1 if (f & L) != 0 else 0)
	if bool(o.get("below", false)) and step_dir != 0 and lead0 != null and h.is_grounded() and lead0.is_grounded() and lead0.xvel == 0 and lead0.sim_pos.y > h.sim_pos.y + 8 and lead0.sim_pos.y - h.sim_pos.y < 96 and absi(lead0.sim_pos.x - h.sim_pos.x) < 64:
		if level.get_cell((h.sim_pos.x + step_dir * (12 + (absi(h.xvel) >> 4) * 4)) >> 4, (h.sim_pos.y + 1) >> 4) == TileGrid.CH_AIR and int(_st.get("held", 0)) < 24:
			_st["held"] = int(_st.get("held", 0)) + 1
			return 0
	else:
		_st["held"] = 0
	var park: int = int(o.get("park", 26))
	if lead0 != null and absi(lead0.sim_pos.x - target_x) < park and absi(lead0.sim_pos.y - rec_y[j]) < 24 			and absi(lead0.sim_pos.y - h.sim_pos.y) < 40:
		# P1 still stands where his trail leads: wait beside him, never on his head
		var side: int = -1 if lead0.sim_pos.x >= h.sim_pos.x else 1
		target_x = lead0.sim_pos.x + side * park
		f &= ~U
	elif lead0 != null and h.is_grounded() and absi(rec_y[j] - h.sim_pos.y) < 8 			and absi(rec_x[j] - h.sim_pos.x) > int(o.get("tol", 6)):
		# the trail point lies behind me on my own floor (I waited beside P1): wait for it, keep the delay
		var toward: int = signi(lead0.sim_pos.x - h.sim_pos.x)
		if toward != 0 and signi(rec_x[j] - h.sim_pos.x) == -toward and lead0.is_grounded() and absi(lead0.sim_pos.y - h.sim_pos.y) < 8:
			return 0
	var dx: int = target_x - h.sim_pos.x
	var tol: int = int(o.get("tol", 6))
	# steer only toward a point on my own floor (or in the air): a trail point on a lower floor is reached by P1's
	# own keys along the ledge to its drop, not by walking straight at it
	var steer: bool = not h.is_grounded() or absi(rec_y[j] - h.sim_pos.y) <= 8 or target_x != rec_x[j]
	if bool(o.get("below", false)) and not steer and rec_y[j] > h.sim_pos.y + 8 and absi(dx) > 8:
		# a lower point: steer to it only when my ledge ends on the way (the drop P1 took lies between us)
		var probe_x: int = h.sim_pos.x
		var dir_x: int = signi(dx)
		while absi(probe_x - target_x) > 8:
			probe_x += dir_x * 8
			if level.get_cell(probe_x >> 4, (h.sim_pos.y + 1) >> 4) == TileGrid.CH_AIR:
				steer = true
				break
	if absi(dx) > tol and steer:
		f &= ~(L | R)
		f |= R if dx > 0 else L
	elif h.is_grounded() and target_x != rec_x[j]:
		f &= ~(L | R)
	# never come down on the partner's head (a head under a ledge lifts a hero into the rock, G54): while airborne
	# with him below within 56 px and closer than 24 px across, steer away from him
	var lead: PlayerBase = hero(0)
	if lead != null and not h.is_grounded():
		var ax: int = lead.sim_pos.x - h.sim_pos.x
		var ay: int = lead.sim_pos.y - h.sim_pos.y
		if ay > 0 and ay < 56 and absi(ax) < 24:
			f &= ~(L | R)
			f |= L if ax > 0 or (ax == 0 and h.facing < 0) else R
	return f
