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
const S: int = Defs.IN_SWAP

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


var lull_start: int = 0
var _last_wind: int = 0


func flags(p_level: LevelBase, tick: int) -> PackedInt32Array:
	level = p_level
	t = tick
	if level.wind == 0 and _last_wind != 0:
		lull_start = t
	_last_wind = level.wind
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
			# In a gust a hero standing still is blown away: crouch whenever a command rests on the ground.
			if f == 0 and level.wind != 0 and h_ok(s) and bool(opts.get("gust_crouch", true)):
				return D
			return f
		_pc[s] += 1
		_n[s] = 0
	return 0


func h_ok(s: int) -> bool:
	var h: PlayerBase = hero(s)
	return h != null and h.is_grounded() and h.state != Defs.HeroState.CLIMB and not h.is_striking()


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
		"clear":
			# ["clear", radius_px, max_ticks, opts]: stand and fight until no awake enemy is within radius (or max).
			var rad: int = int(cmd[1])
			if n > int(cmd[2]):
				return -1
			var near: bool = false
			for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
				var foe: EnemyBase = entity as EnemyBase
				var r2: int = 56 if foe is Flyer else rad
				if foe != null and not foe.dead and foe.awake and foe.tangible 						and absi(foe.sim_pos.x - h.sim_pos.x) < r2 and absi(foe.sim_pos.y - h.sim_pos.y) < r2:
					near = true
			if not near and n > 2:
				return -1
			var ko: Dictionary = cmd[3] if cmd.size() > 3 else {"fight": true}
			if not h.is_grounded() or h.is_striking():
				return 0
			# Face the side a threat comes from: a circling harrier swoops from the hero's left (its way-points
			# (-32, 40) -> (0, 24)); anything else from where it is.
			var want: int = 0
			for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
				var foe2: EnemyBase = entity as EnemyBase
				if foe2 == null or foe2.dead or not foe2.awake or not foe2.tangible:
					continue
				if absi(foe2.sim_pos.x - h.sim_pos.x) >= rad or absi(foe2.sim_pos.y - h.sim_pos.y) >= rad:
					continue
				if foe2 is Harrier:
					want = -1
					break
				want = signi(foe2.sim_pos.x - h.sim_pos.x)
			if want != 0 and h.facing != want and int(_st[h.slot].get("faced", 0)) < n - 3:
				_st[h.slot]["faced"] = n
				return R if want > 0 else L
			var fk5: int = _fight(h, ko)
			if fk5 > 0 and (fk5 & F) != 0:
				return fk5
			# waiting for a threat: a crouch blip now and then (an idle partner counts for nothing in co-op)
			return D if players > 1 and n % 60 == 59 else 0
		"lull":
			# ["lull", min_left, lull_len]: crouch while the wind blows or the lull has fewer than min_left ticks left.
			var left6: int = int(cmd[2]) - (t - lull_start) if level.wind == 0 else 0
			if level.wind == 0 and left6 >= int(cmd[1]) and h.is_grounded():
				return -1
			if n > 1200:
				return -1
			if bool(opts.get("lull_fight", false)) and h.is_grounded():
				var hk6: int = _harrier_keys(h) if not h.is_striking() else -1
				if hk6 >= 0 and hk6 != D:
					return hk6
				var fk6: int = _fight(h, {"fight": true, "wait_px": 0})
				if fk6 > 0 and (fk6 & F) != 0:
					return fk6
			return D
		"trek":
			# ["trek", x, opts]: walk to x (fight on); jump over a Guard / Roller / Charger closing in ahead.
			var x7: int = int(cmd[1])
			var o7: Dictionary = cmd[2] if cmd.size() > 2 else {}
			var dir7: int = 1 if x7 > h.sim_pos.x else -1
			if absi(x7 - h.sim_pos.x) <= 3 and h.is_grounded():
				return -1
			if n > 3000:
				return -1
			if int(st.get("air", 0)) > 0:
				st["air"] = int(st["air"]) - 1
				return U | (R if dir7 > 0 else L) if int(st["air"]) > 2 else (R if dir7 > 0 else L)
			if not h.is_grounded():
				return R if dir7 > 0 else L
			for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
				var foe7: EnemyBase = entity as EnemyBase
				if foe7 == null or foe7.dead or not foe7.awake or not foe7.tangible:
					continue
				if not (foe7 is Guard or foe7 is Roller or foe7 is Charger):
					continue
				var d7: int = (foe7.sim_pos.x - h.sim_pos.x) * dir7
				if absi(foe7.sim_pos.y - h.sim_pos.y) < 20 and d7 > 12 and d7 < int(o7.get("leap_at", 46)) 						and h.no_jump == 0:
					st["air"] = 11
					return U | (R if dir7 > 0 else L)
			var fk7: int = _fight(h, {"fight": true})
			if fk7 >= 0:
				st["still"] = 0
				return fk7
			if int(st.get("lastx", -99999)) == h.sim_pos.x and level.wind == 0:
				st["still"] = int(st.get("still", 0)) + 1
			else:
				st["still"] = 0
			st["lastx"] = h.sim_pos.x
			if int(st["still"]) > 10 and h.no_jump == 0:
				st["still"] = 0
				st["air"] = 6
				return U | (R if dir7 > 0 else L)
			return R if dir7 > 0 else L
		"guard":
			# ["guard", dir, max_px]: pass a shield Guard ahead (within max_px) the solo way: jump onto its head (Up held:
			# the high bounce), drift over it, land behind it, turn and strike its back before its shield turns.
			var gdir: int = int(cmd[1])
			var gmax: int = int(cmd[2]) if cmd.size() > 2 else 200
			var guard: EnemyBase = null
			var best: int = 1 << 20
			for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
				var foe8: EnemyBase = entity as EnemyBase
				if foe8 == null or foe8.dead or not foe8.tangible or not (foe8 is Guard):
					continue
				var d8: int = (foe8.sim_pos.x - h.sim_pos.x) * gdir
				var dy8: int = 24 if not st.has("phase") else 140
				if absi(foe8.sim_pos.y - h.sim_pos.y) < dy8 and d8 > -90 and d8 < gmax and absi(d8) < best:
					best = absi(d8)
					guard = foe8
			if guard == null:
				return -1 if n > 0 or not st.has("phase") else -1
			if n > 400:
				return -1
			var gd: int = (guard.sim_pos.x - h.sim_pos.x) * gdir
			var gphase: String = str(st.get("phase", "approach"))
			var gkey: int = R if gdir > 0 else L
			var bkey: int = L if gdir > 0 else R
			match gphase:
				"approach":
					if not h.is_grounded():
						return gkey
					if level.wind != 0 and signi(-level.wind) != gdir and gd < 140:
						return D
					var vclose: float = maxf(-float(guard.xvel) * gdir / 16.0, -2.0)
					if gd > 44.0 + 8.0 * (5.0 + vclose) or absi(h.xvel) < 64:
						return gkey
					if h.no_jump > 0 or h.is_striking():
						return 0
					st["phase"] = "jump"
					st["jt"] = 0
					return gkey | U
				"jump":
					st["jt"] = int(st["jt"]) + 1
					if h.is_grounded() and int(st["jt"]) > 3:
						if gd < -30:
							st["phase"] = "strike"
							st["sk"] = 0
							return bkey
						st["phase"] = "approach"
						return 0
					return gkey | U
				"strike":
					st["sk"] = int(st["sk"]) + 1
					if int(st["sk"]) > 60:
						return -1
					if h.facing != -gdir:
						return bkey
					if -gd > 40:
						return bkey if h.is_grounded() else 0
					if int(st.get("hold", 0)) > 0:
						st["hold"] = int(st["hold"]) - 1
						return F if int(st["hold"]) > 2 else 0
					if h.is_grounded() and not h.is_striking():
						st["hold"] = 9
						return F
					return 0
			return -1
		"hop":
			# ["hop", target_x, up_ticks, opts]: wait until a jump is possible (grounded, no lock-out, no strike), then
			# jump holding U for up_ticks while steering to target_x, and steer until grounded again.
			var tx3: int = int(cmd[1])
			var up3: int = int(cmd[2])
			var o3: Dictionary = cmd[3] if cmd.size() > 3 else {}
			var lead3: int = int(o3.get("lead", 3))
			if not st.has("t0"):
				if h.is_grounded() and bool(o3.get("fight", false)):
					var fk: int = _fight(h, o3)
					if fk >= 0:
						return fk
				if h.is_grounded() and n < int(o3.get("safe_max", 160)) and _danger(h, signi(tx3 - h.sim_pos.x), o3):
					return 0
				if not h.is_grounded() or h.no_jump > 0 or h.is_striking() or n < int(o3.get("pre", 0)):
					var pre_keys: int = int(o3.get("pre_keys", 0))
					return pre_keys
				st["t0"] = n
			var k3: int = n - int(st["t0"])
			var dx3: int = tx3 - h.sim_pos.x
			var keys3: int = 0
			if dx3 > lead3:
				keys3 = R
			elif dx3 < -lead3:
				keys3 = L
			if k3 < int(o3.get("delay_dir", 0)):
				keys3 = 0
			if k3 < up3:
				return U | keys3
			if k3 > 2 and h.is_grounded():
				return -1
			if k3 > int(o3.get("max", 120)):
				return -1
			return keys3
		"ride":
			# ["ride", vent_x, target_x, opts]: stand at vent_x until something throws the hero up (a geyser, a
			# see-saw), then steer to target_x until he stands again higher than he started.
			var vx: int = int(cmd[1])
			var tx4: int = int(cmd[2])
			var o4: Dictionary = cmd[3] if cmd.size() > 3 else {}
			if not st.has("y0"):
				st["y0"] = h.sim_pos.y
			if not bool(st.get("up", false)):
				if h.yvel < -100 and not h.is_grounded():
					st["up"] = true
				else:
					if n > int(o4.get("max_wait", 400)):
						return -1
					if h.is_grounded() and bool(o4.get("fight", false)):
						var fk4: int = _fight(h, o4)
						if fk4 >= 0:
							return fk4
					var dv: int = vx - h.sim_pos.x
					if h.is_grounded():
						var sp: int = absi(h.xvel)
						if h.xvel != 0 and signi(h.xvel) == signi(dv) and absi(dv) <= (sp * sp) / (2 * 12 * 16) + 2:
							return 0
						if h.xvel != 0 and signi(h.xvel) != signi(dv):
							return 0
						if absi(dv) > 2:
							return R if dv > 0 else L
					return int(o4.get("wait_keys", 0))
			if h.is_grounded() and h.sim_pos.y < int(st["y0"]) - 8:
				return -1
			if n > int(o4.get("max", 600)):
				return -1
			var d4: int = tx4 - h.sim_pos.x
			if h.yvel < int(o4.get("steer_after", -400)):
				return 0
			if d4 > 3:
				return R
			if d4 < -3:
				return L
			return 0
		"climb":
			# ["climb", row]: hold U (grab and climb a vine) until the hero stands on the floor of `row`.
			var row5: int = int(cmd[1])
			if h.is_grounded() and h.sim_pos.y == row5 * 16 and n > 2:
				return -1
			if n > (int(cmd[2]) if cmd.size() > 2 else 800):
				return -1
			return U
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
					# waiting: answer threats, and blip a crouch now and then (an idle partner counts for nothing)
					if h.is_grounded():
						var fk8: int = _fight(h, {"fight": true})
						if fk8 >= 0:
							return fk8
					return D if (n % 90 == 89 or level.wind != 0) and h.is_grounded() else 0
			_released[sync_name] = true
			return -1
	push_error("bot: unknown command %s" % str(cmd))
	return -1


var _released: Dictionary = {}


## A circling harrier near a grounded hero: face left, high-strike it as it comes in from the left toward its
## way-point (0, 24), crouch under the swoop otherwise; -1 when no harrier needs an answer.
## True while an awake harrier hovers within 60 px over the hero (a hop would meet it).
func _harrier_over(h: PlayerBase) -> bool:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var hr: Harrier = entity as Harrier
		if hr != null and not hr.dead and hr.awake and hr.tangible and absi(hr.sim_pos.x - h.sim_pos.x) < 40 				and hr.sim_pos.y - h.sim_pos.y > -70 and hr.sim_pos.y < h.sim_pos.y:
			return true
	return false


func _harrier_keys(h: PlayerBase) -> int:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var hr: Harrier = entity as Harrier
		if hr == null or hr.dead or not hr.awake or not hr.tangible:
			continue
		var hdx: int = hr.sim_pos.x - h.sim_pos.x
		var hdy: int = hr.sim_pos.y - h.sim_pos.y
		if absi(hdx) > 90 or absi(hdy) > 90:
			continue
		var wp: int = hr.get_waypoint()
		if wp == 6 or wp == 7:
			if h.facing > 0:
				return L
			if wp == 7 and hdx >= -46 and hdx <= -26 and hdy < -16:
				return U | F
		if (wp == 7 or wp == 8) and absi(hdx) < 40:
			# a dodge crouch, but never more than 30 ticks in a row (a harrier may hover over a croucher)
			var st: Dictionary = _st[h.slot]
			if int(st.get("hk_t", -99)) != t - 1:
				st["hk_n"] = 0
			st["hk_t"] = t
			st["hk_n"] = int(st.get("hk_n", 0)) + 1
			if int(st["hk_n"]) % 60 < 30:
				return D
	return -1


## True while an awake enemy is in the space a jump toward `dir` would cross (opts "safe": [ahead, up] px, default
## [110, 120]); a hop waits for it to pass (at most "safe_max" ticks).
func _danger(h: PlayerBase, dir: int, o: Dictionary) -> bool:
	if not o.has("safe"):
		return false
	var box: Array = o["safe"]
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead or not foe.awake or not foe.tangible:
			continue
		var dx: int = (foe.sim_pos.x - h.sim_pos.x) * (dir if dir != 0 else 1)
		var dy: int = foe.sim_pos.y - h.sim_pos.y
		if dx > -40 and dx < int(box[0]) and dy > -int(box[1]) and dy < 24:
			return true
	return false


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
	if not h.is_striking():
		var hk: int = _harrier_keys(h)
		if hk >= 0:
			return hk
	var wait: bool = false
	var turn: int = 0
	var f: int = h.facing
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead or not foe.awake or not foe.tangible:
			continue
		if o.has("ignore") and (o["ignore"] as Array).has(String(foe.name)):
			continue
		if int((st.get("futile", {}) as Dictionary).get(foe.get_instance_id(), -1)) > t:
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
				# three high strikes in a row at one enemy that is still there: it hovers out of reach, leave it
				var hid: int = foe.get_instance_id()
				if int(st.get("hs_id", 0)) == hid and t - int(st.get("hs_t", -999)) < 40:
					st["hs_n"] = int(st.get("hs_n", 0)) + 1
				else:
					st["hs_n"] = 1
				st["hs_id"] = hid
				st["hs_t"] = t
				if int(st["hs_n"]) > 3:
					if not st.has("futile"):
						st["futile"] = {}
					(st["futile"] as Dictionary)[hid] = t + 90
					st["hs_n"] = 0
					continue
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


# --- co-op helpers -------------------------------------------------------------------------------------------------

## True once every drop platform whose home lies in columns c0..c1 waits at home.
func drops_home(c0: int, c1: int) -> Callable:
	return func(lv: LevelBase, _hh: PlayerBase) -> bool:
		for entity: SimEntity in lv.get_kind(Defs.Kind.PLATFORM):
			var dp: DropPlatform = entity as DropPlatform
			if dp == null:
				continue
			if dp.home.x >= c0 * 16 and dp.home.x < (c1 + 1) * 16:
				if dp.state != DropPlatform.State.WAIT or dp.sim_pos != dp.home:
					return false
		return true


## True once the partner stands at or above `row` (feet row).
func partner_up(row: int) -> Callable:
	return func(_lv: LevelBase, hh: PlayerBase) -> bool:
		var other: PlayerBase = hero(1 - hh.slot)
		return other != null and other.is_grounded() and other.sim_pos.y <= row * 16


## True once the partner stands at or beyond x (in the direction `dir`).
func partner_past(x: int, dir: int = 1) -> Callable:
	return func(_lv: LevelBase, hh: PlayerBase) -> bool:
		var other: PlayerBase = hero(1 - hh.slot)
		return other != null and other.is_grounded() and (other.sim_pos.x - x) * dir >= 0


## Wait in place, crouching for one tick every 90 (an idle partner counts for nothing), until `cond` holds.
func wait_until(cond: Callable, maxn: int = 2000) -> Array:
	return ["fn", func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if cond.call(lv, h) or n > maxn:
			return -1
		if h.is_grounded() and (n % 90 == 89 or lv.wind != 0):
			return D
		return 0]
