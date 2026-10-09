extends RefCounted
## D6 bot library (development only, build/ is not versioned): a program per hero slot, one command after the other,
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


func setup(p_mode: String, p_players: int, p_opts: Dictionary) -> void:
	mode = p_mode
	expert = mode == "expert"
	players = p_players
	opts = p_opts
	_progs = build()
	_pc.resize(players)
	_n.resize(players)
	for s: int in players:
		_st.append({})
		_syncs.append("")
		_done.append(false)


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
	for s: int in players:
		out[s] = _slot_flags(s)
		if not _done[s]:
			running = true
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
			if bool(opts.get("steps", true)):
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
