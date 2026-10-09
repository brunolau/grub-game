extends Node
## THE CONTINUOUS-PLAY EXPLORER of one co-op gate row for one hero (docs/expansion/DESIGN.md R7 / G71+, PLAN.md 8
## V3.c, LEVEL_DESIGN.md 15.7.6): proof (c) of a gate - "the explorer opens it in none of two seeded passes of 300 s
## per gate row over the whole level". The G3b verifier's explorer (build/g3bv/explore_runner.gd: it opened 19 rows
## the solo search refused), adopted and completed by world-B in wf11. Owner: world-B (PLAN.md 4.1).
##
## An archive search in the manner of Go-Explore on the solo search's own world (harness.gd: the real hero, the
## file's entities, the partner an egg or his idle hatched partner parked where the hero stands). Unlike the gate
## search it never resets the world between moves and never asks for a rest: every state is "the inputs from the
## gate's start so far", so momentum, woken and led enemies, moving doors, clocks, wounds and ride chains all carry; a
## path may be `maxt` ticks long (3 x the search's 1457) and may leave the gate's area (whole=1: the whole level -
## R7's bar).
## An archive cell is (hero cell, on the ground or not, head bounces so far, world signature, partner parked, special
## in hand); it keeps the shortest input sequence that got there. A round picks a cell (a tournament by nearness to
## the far cell, by height, by ride chains, by a follower in tow - or a random or a rarely tried one), replays its
## inputs from an EXACT reset (CoopSearch.Searcher.reset_world: every replay must come back to its state - "off
## their state" is 0) and plays a few moves on:
##   walks, waits, jumps of every hold, crouches and drops, strikes (forward, high, low, charged), the hop jump and
##   the pogo, throws of every special (standing, high, low, in a jump), the idle partner parked here, and
##   RIDE          Up held, coming down on the nearest awake enemy again and again (a leaper over a gap, a lurker at
##                 its lip, a perched keeper: cause A of G3b);
##   LURE          to where a follower of the WHOLE level wakes, then back toward the gate with it in tow (the gull of
##                 7-1 'dune', 22 columns away: cause A);
##   SPRING        onto a spring pad, a low strike begun there and Up from its hop (cause B: 256 px before R1);
##   LONG CLIMB    Up on a vine until its top, however long, and the leap or the run off it (cause D);
##   SECOND THROW  a special thrown at the far one of two targets and a second throw or a strike as it lands, with
##                 every delay - standing, walking on, or both in one jump (cause C: a bond's two hits in flight).
## The far cell of the gate's tablet is the goal on every tick.
##
## Usage: bash .tools/gd.sh script res://tools/coop_explore/main.gd -- explore <level> <gate> <0|1> key=value ...
##   seconds=<n>     wall time (default 120; R7: 300)       seed=<n>      random seed (default 1)
##   pass=<0|1>      R7's pass: the row's own seed (harness.gd row_seed) and 300 s, the result kept for the gate test
##   whole=<0|1>     the whole level (default 1)            maxt=<ticks>  longest path (default 4371)
##   out=<file>      where a found route is written (default build/coop_explore/found/<level>.<gate>.<d>.txt)
##   cache=1         keep the result for the gate test (harness.gd explore_key; implied by pass=), and read a kept
##                   one back instead of playing the pass again (fresh=1: play it again)
##   nothrow=1       club only                              noplace=1     the partner stays an egg
##   real=1          in the real game (real_harness.gd)     audit=1       CoopSearch.reset_audit
##   tick0=<n>       Sim.tick at the start of every run (default: the search world's, CoopSearch.TICK_BASE)
##   lure=<id part>@<col>,<row>;<wake x,...>;<ride x>       a scripted prefix: wake that follower, lead it to ride x
##   prefix=<route file>                                    roots from every 20th tick of a route found elsewhere
## Prints `EXPLORE <row>: REACHED the far cell in <t> ticks | NOT reached; <counts>`; a found route goes to `out` as
## a route file (harness.gd). Exit code 0 = not reached, 1 = REACHED (the gate is open), 2 = cannot run.

const HARNESS: String = "res://tools/coop_explore/harness.gd"
const REAL_HARNESS: String = "res://tools/coop_explore/real_harness.gd"
const NOWHERE: Vector2i = Vector2i(-1, -1)
const L: int = Defs.IN_LEFT
const R: int = Defs.IN_RIGHT
const U: int = Defs.IN_UP
const D: int = Defs.IN_DOWN
const F: int = Defs.IN_FIRE
## Enemy scripts that come to the hero (DESIGN.md G66): what LURE fetches and the "in tow" tournament counts.
const FOLLOWERS: Array[String] = ["harrier", "stinger", "hopper", "charger", "leaper", "lurker", "digger", "roller"]
## A frame passes every this many rounds (the engine's message queue is flushed; a search passes none).
const FRAME_EVERY: int = 25

var lib: RefCounted = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The tree of kept states: {"parent", "flags" (its own ticks), "events" ([tick, kind, value] absolute), "t", "check"
## (the world's hash there), "visits", "bounces", "hand", "placed", "start", "values"}.
var nodes: Array[Dictionary] = []
var cells: Dictionary = {}
var far_px: Vector2i = Vector2i.ZERO
var maxt: int = 4371
var replays: int = 0
var replay_misses: int = 0
var ticks_played: int = 0
var deaths: int = 0
var best_dist: int = 1 << 30
var best_y: int = 1 << 30
var most_bounces: int = 0
var found: Dictionary = {}
var real: bool = false
var no_throw: bool = false
var no_place: bool = false
var usec_begin: int = 0
var usec_sig: int = 0
var _events: Array = []
var _hand: int = -1
var _placed: bool = false
var _blocked: int = 0
var _jump_left: int = 0


func _arg(args: Dictionary, key: String, fallback: String) -> String:
	return str(args.get(key, fallback))


func run(arguments: PackedStringArray) -> int:
	if arguments.size() < 3:
		print("EXPLORE: want <level> <gate> <0|1> [key=value ...]")
		return 2
	var level: StringName = StringName(arguments[0])
	var gate: String = arguments[1]
	var difficulty: int = arguments[2].to_int()
	var args: Dictionary = {}
	for i: int in range(3, arguments.size()):
		var eq: int = arguments[i].find("=")
		if eq > 0:
			args[arguments[i].substr(0, eq)] = arguments[i].substr(eq + 1)
	var harness: GDScript = load(HARNESS) as GDScript
	var seconds: int = _arg(args, "seconds", "120").to_int()
	var seed_value: int = _arg(args, "seed", "1").to_int()
	var keep: bool = _arg(args, "cache", "0") == "1"
	var pass_index: int = -1
	if args.has("pass"):
		pass_index = clampi(_arg(args, "pass", "0").to_int(), 0, 1)
		seed_value = harness.call(&"row_seed", level, difficulty, gate, pass_index)
		seconds = _arg(args, "seconds", str(harness.get(&"PASS_SECONDS"))).to_int()
		keep = true
	rng.seed = seed_value
	maxt = _arg(args, "maxt", "4371").to_int()
	var whole: bool = _arg(args, "whole", "1") == "1"
	real = _arg(args, "real", "0") == "1"
	no_throw = _arg(args, "nothrow", "0") == "1"
	no_place = _arg(args, "noplace", "0") == "1" or real
	CoopSearch.reset_audit = _arg(args, "audit", "0") == "1"
	var key: String = ""
	if keep and not real and whole and not no_throw and not no_place and not args.has("lure") \
			and not args.has("prefix") and not args.has("tick0"):
		key = harness.call(&"explore_key", level, difficulty, gate, seed_value, seconds)
	if key != "" and _arg(args, "fresh", "0") != "1":
		# The same pass on the same level file and code: its kept result (fresh=1 plays it again).
		var kept: Dictionary = harness.call(&"cache_read", key)
		if not kept.is_empty():
			print("EXPLORE %s d%d %s whole: %s; kept result of seed %d, %d s (%d rounds, %d ticks played, %d replays off their state) [cached]" % [
				level, difficulty, gate, "REACHED the far cell in %d ticks" % int(kept.get("ticks", -1))
				if bool(kept.get("reached", false)) else "NOT reached", seed_value, seconds, int(kept.get("rounds", 0)),
				int(kept.get("played", 0)), int(kept.get("misses", 0))])
			if bool(kept.get("reached", false)) and str(kept.get("route_file", "")) != "" and args.has("out"):
				var again: FileAccess = FileAccess.open(_arg(args, "out", ""), FileAccess.WRITE)
				if again != null:
					again.store_string(str(kept["route_file"]))
					again.close()
			return 1 if bool(kept.get("reached", false)) else 0
	var built: bool = false
	if real:
		lib = (load(REAL_HARNESS) as GDScript).new()
		built = await lib.build(self, level, gate, difficulty)
	else:
		lib = harness.new()
		built = lib.build(level, gate, difficulty, whole, _arg(args, "tick0", "-1").to_int())
	if not built:
		print("EXPLORE %s %s d%d: cannot build the world" % [level, gate, difficulty])
		return 2
	if real and args.has("tickoff"):
		lib.tick_offset = _arg(args, "tickoff", "0").to_int()
	far_px = Vector2i(lib.far.x * 16 + 8, lib.far.y * 16 + 16)
	var label: String = "%s d%d %s%s%s%s%s" % [level, difficulty, gate, " whole" if whole else "",
		" lure %s" % _arg(args, "lure", "") if args.has("lure") else "", " REAL GAME" if real else "",
		" club only" if no_throw else ""]
	# Roots: every start of the gate (the tablet's, the last checkpoint's), or the end of the scripted lure.
	for start_index: int in lib.starts.size():
		var root: Dictionary = {"parent": -1, "flags": PackedInt32Array(), "events": [], "t": 0, "visits": 0,
			"start": start_index, "bounces": 0, "hand": -1, "placed": false}
		if args.has("lure"):
			var lured: PackedInt32Array = await _lure(start_index, _arg(args, "lure", ""))
			if lured.is_empty():
				continue
			root["flags"] = lured
			root["t"] = lured.size()
			root["bounces"] = lib.bounces
		else:
			await lib.begin(lib.starts[start_index], 1)
		root["check"] = _check()
		root["values"] = _values(lib.hero(), int(root["bounces"]))
		nodes.append(root)
	if args.has("prefix"):
		await _prefix_roots(_arg(args, "prefix", ""), _arg(args, "prefix_start", "0").to_int())
	if nodes.is_empty():
		print("EXPLORE %s: no root (the lure did not bring the follower)" % label)
		lib.close()
		return 2
	print("EXPLORE %s: far %s, %d root(s), starts %s, %d s, seed %d, paths up to %d ticks" % [label, str(lib.far),
		nodes.size(), str(lib.starts), seconds, rng.seed, maxt])
	var clock: int = Time.get_ticks_msec()
	var rounds: int = 0
	var last_report: int = clock
	while found.is_empty() and (Time.get_ticks_msec() - clock) / 1000.0 < seconds:
		rounds += 1
		await _round()
		if rounds % FRAME_EVERY == 0:
			await get_tree().process_frame
		if Time.get_ticks_msec() - last_report > 30000:
			last_report = Time.get_ticks_msec()
			print("    ... %d rounds, %d states, %d ticks, nearest %d px, highest y %d (row %.1f), most bounces %d, deaths %d" % [
				rounds, nodes.size(), ticks_played, best_dist, best_y, best_y / 16.0, most_bounces, deaths])
	var spent: float = (Time.get_ticks_msec() - clock) / 1000.0
	var verdict: String = "NOT reached"
	if not found.is_empty():
		verdict = "REACHED the far cell in %d ticks" % int(found["t"])
	var searcher: CoopSearch.Searcher = lib.s as CoopSearch.Searcher
	var drift: int = searcher.drift + searcher.audit_drift if searcher != null else 0
	print("EXPLORE %s: %s; %d rounds, %d states in %d cells, %d ticks played (%d replays, %d of them off their state), nearest %d px, highest feet y %d (row %.1f), most head bounces %d, %d deaths; %.0f s" % [
		label, verdict, rounds, nodes.size(), cells.size(), ticks_played, replays, replay_misses, best_dist, best_y,
		best_y / 16.0, most_bounces, deaths, spent])
	if searcher != null:
		print("    the exact reset: %d resets, %d entities respawned in place, %d put back by their variables, the heroes built anew %d times, %d left not in the level-file state; resets %.1f s, signatures %.1f s" % [
			searcher.runs, searcher.respawns, searcher.restores, searcher.party_respawns, drift, usec_begin / 1000000.0,
			usec_sig / 1000000.0])
	var route_text: String = ""
	if not found.is_empty():
		var out: String = _arg(args, "out", "res://build/coop_explore/found/%s.%s.%d%s.txt" % [level, gate, difficulty,
			".real" if real else ""])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
		route_text = harness.call(&"route_file_text", level, gate, difficulty, whole, int(found["start"]),
			found["events"], str(found["route"]), real, _arg(args, "tickoff", "0").to_int(),
			searcher.tick_base if searcher != null else 0)
		var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		if file != null:
			file.store_string(route_text)
			file.close()
		print("    FOUND start %d events %s" % [int(found["start"]), str(found["events"])])
		print("    ROUTE %s" % str(found["route"]))
		print("    route file: %s" % out)
	if key != "":
		harness.call(&"cache_write", key, {"level": String(level), "gate": gate, "difficulty": difficulty,
			"seed": seed_value, "seconds": seconds, "pass": pass_index, "reached": not found.is_empty(),
			"ticks": int(found.get("t", -1)), "rounds": rounds, "states": nodes.size(), "played": ticks_played,
			"replays": replays, "misses": replay_misses, "drift": drift, "spent": spent, "route_file": route_text})
	lib.close()
	return 1 if not found.is_empty() else 0


# =================================================================================================================
# The archive
# =================================================================================================================

## What a state is worth by each objective of the tournaments: [near the far cell, height, head bounces, a follower
## in tow or near].
func _values(hero: PlayerBase, bounces: int) -> Array:
	var dx: int = absi(far_px.x - hero.sim_pos.x)
	var dy: int = hero.sim_pos.y - far_px.y   # > 0: under the far cell's floor
	var near: float = -float(dx + 2 * maxi(dy, 0))
	var height: float = -float(hero.sim_pos.y) - 0.25 * float(dx)
	var ride: float = 120.0 * float(mini(bounces, 8)) - float(hero.sim_pos.y) - 0.5 * float(dx)
	var tow: float = -4000.0
	for entity: SimEntity in lib.s.level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy == null or enemy.dead or enemy.keeper != &"" or not _is_follower(enemy):
			continue
		var d: int = absi(enemy.sim_pos.x - hero.sim_pos.x) + absi(enemy.sim_pos.y - hero.sim_pos.y)
		var value: float = -float(d)
		if enemy.awake and d < 170:
			# In tow: the nearer the far cell the better.
			value = 2000.0 - float(dx) - float(d)
		tow = maxf(tow, value)
	return [near, height, ride, tow]


func _is_follower(enemy: EnemyBase) -> bool:
	return FOLLOWERS.has(String((enemy.get_script() as Script).resource_path).get_file().get_basename())


## What a replay of a state must come back to: the whole world's hash in the search world (harness.gd world_hash), the
## hero's place in the real game.
func _check() -> int:
	if lib.has_method(&"world_hash"):
		return lib.world_hash()
	return hash(lib.hero().sim_pos)


func _cell_key(hero: PlayerBase, bounces: int, sig_hash: int) -> String:
	return "%d,%d,%d,%d,%d,%d,%d" % [hero.sim_pos.x >> 4, (hero.sim_pos.y - 1) >> 4, 1 if hero.is_grounded() else 0,
		mini(bounces, 6), sig_hash, 1 if _placed else 0, _hand]


func _chain(index: int) -> Array:
	# [flags of the whole path, events of the whole path, start index]
	var parts: Array = []
	var events: Array = []
	var at: int = index
	var start: int = 0
	while at >= 0:
		parts.append(nodes[at]["flags"])
		events = (nodes[at]["events"] as Array) + events
		start = int(nodes[at]["start"])
		at = int(nodes[at]["parent"])
	var flags: PackedInt32Array = PackedInt32Array()
	for i: int in range(parts.size() - 1, -1, -1):
		flags.append_array(parts[i])
	return [flags, events, start]


func _pick() -> int:
	var roll: float = rng.randf()
	if roll < 0.15 or nodes.size() < 8:
		return rng.randi_range(0, nodes.size() - 1)
	# A tournament by one objective (less what was tried often), or the least tried of a few.
	var objective: int = rng.randi_range(0, 3)
	var best: int = -1
	var best_value: float = -1e18
	var novelty: bool = roll > 0.9
	for i: int in 14:
		var index: int = rng.randi_range(0, nodes.size() - 1)
		var node: Dictionary = nodes[index]
		var value: float = -float(node["visits"]) if novelty \
				else float((node["values"] as Array)[objective]) - 8.0 * float(node["visits"])
		if value > best_value:
			best_value = value
			best = index
	return best


func _round() -> void:
	var index: int = _pick()
	var node: Dictionary = nodes[index]
	node["visits"] = int(node["visits"]) + 1
	var chain: Array = _chain(index)
	var flags: PackedInt32Array = chain[0]
	var events: Array = chain[1]
	var start: int = chain[2]
	# Replay.
	var clock: int = Time.get_ticks_usec()
	await lib.begin(lib.starts[start], 1)
	usec_begin += Time.get_ticks_usec() - clock
	_events = events.duplicate()
	_hand = -1
	_placed = false
	var next_event: int = 0
	replays += 1
	for i: int in flags.size():
		while next_event < events.size() and int(events[next_event][0]) <= i:
			_apply(events[next_event])
			next_event += 1
		var end: String = lib.step(flags[i])
		ticks_played += 1
		if end == "dead":
			replay_misses += 1
			return
		if end == "goal":
			_found(start)
			return
	while next_event < events.size():
		_apply(events[next_event])
		next_event += 1
	if _check() != int(node["check"]):
		# The replay did not come back to its state: a world the reset does not bring back exactly (0 since wf11;
		# counted, and the path is still a real one - played on).
		replay_misses += 1
	# Explore on from here.
	var parent: int = index
	var since: int = lib.t
	var event_base: int = _events.size()
	var moves: int = rng.randi_range(2, 7)
	for move: int in moves:
		if lib.t >= maxt:
			break
		var end: String = _move()
		if end == "goal":
			_found(start)
			return
		if end == "dead":
			deaths += 1
			return
		var hero: PlayerBase = lib.hero()
		var dist: int = absi(far_px.x - hero.sim_pos.x) + absi(far_px.y - hero.sim_pos.y)
		best_dist = mini(best_dist, dist)
		best_y = mini(best_y, hero.sim_pos.y)
		most_bounces = maxi(most_bounces, lib.bounces)
		clock = Time.get_ticks_usec()
		var key: String = _cell_key(hero, lib.bounces, lib.s.signature().hash())
		usec_sig += Time.get_ticks_usec() - clock
		var known: int = int(cells.get(key, -1))
		if known >= 0 and int(nodes[known]["t"]) <= lib.t:
			continue
		var own: PackedInt32Array = lib.s._flags.slice(since)
		var own_events: Array = _events.slice(event_base)
		event_base = _events.size()
		var child: Dictionary = {"parent": parent, "flags": own, "events": own_events, "t": lib.t, "visits": 0,
			"start": start, "check": _check(), "bounces": lib.bounces, "hand": _hand, "placed": _placed,
			"values": _values(hero, lib.bounces)}
		nodes.append(child)
		cells[key] = nodes.size() - 1
		parent = nodes.size() - 1
		since = lib.t


func _found(start: int) -> void:
	found = {"t": lib.t, "start": start, "events": _events.duplicate(), "route": lib.route_text()}


func _apply(event: Array) -> void:
	match str(event[1]):
		"hand":
			_hand = int(event[2])
			lib.set_hand(_hand)
		"place":
			_placed = true
			lib.place_partner()


func _event(kind: String, value: int) -> void:
	var event: Array = [lib.t, kind, value]
	_events.append(event)
	_apply(event)


# =================================================================================================================
# Moves
# =================================================================================================================

func _play(flags: Array) -> String:
	for flag: int in flags:
		var end: String = lib.step(flag)
		ticks_played += 1
		if end != "":
			return end
	return ""


func _rep(flag: int, count: int) -> Array:
	var result: Array = []
	for i: int in count:
		result.append(flag)
	return result


func _dir() -> int:
	# Toward the far cell more often than away from it.
	var toward: int = R if far_px.x >= lib.hero().sim_pos.x else L
	var away: int = L if toward == R else R
	return toward if rng.randf() < 0.62 else away


func _move() -> String:
	var hero: PlayerBase = lib.hero()
	var dir: int = _dir()
	var roll: int = rng.randi_range(0, 99)
	if roll < 13:
		return _play(_rep(dir, rng.randi_range(2, 30)))
	if roll < 18:
		return _play(_rep(0, rng.randi_range(1, 36)))
	if roll < 31:
		# A jump: Up held 2..14 ticks, on in the air with or without Up.
		var hold: int = [2, 4, 6, 9, 9, 12, 14][rng.randi_range(0, 6)]
		var side: int = dir if rng.randf() < 0.8 else 0
		var air: int = rng.randi_range(4, 24)
		var runup: int = rng.randi_range(0, 8) if rng.randf() < 0.5 else 0
		return _play(_rep(dir, runup) + _rep(U | side, hold) + _rep(side | (U if rng.randf() < 0.4 else 0), air))
	if roll < 39:
		return _ride(rng.randi_range(18, 70))
	if roll < 43:
		return _play(_rep(D | (dir if rng.randf() < 0.6 else 0), rng.randi_range(4, 26)))
	if roll < 48:
		# Strikes: forward, high, low, charged.
		var kind: int = rng.randi_range(0, 3)
		if kind == 0:
			return _play(_rep(dir, 1) + _rep(F, 8) + _rep(0, 2))
		if kind == 1:
			return _play(_rep(dir, 1) + _rep(U | F, 10) + _rep(0, 2))
		if kind == 2:
			return _play(_rep(dir, 1) + _rep(D | F, 10) + _rep(0, 2))
		return _play(_rep(dir, 1) + _rep(D, rng.randi_range(8, 30)) + _rep(F, 8) + _rep(0, 2))
	if roll < 57:
		# The hop jump (a jump begun in a low strike's hop), with or without a high strike in it; the pogo.
		var low: int = rng.randi_range(6, 10)
		var up: int = rng.randi_range(5, 12)
		if rng.randf() < 0.3:
			return _play(_rep(U | dir, 9) + _rep(dir | D | F, 16))
		if rng.randf() < 0.5:
			return _play(_rep(dir, 1) + _rep(D | F, low) + _rep(U | dir, up) + _rep(dir, rng.randi_range(6, 20)))
		return _play(_rep(dir, 1) + _rep(D | F, low) + _rep(U | dir, 4) + _rep(U | F, 10)
				+ _rep(dir, rng.randi_range(4, 14)))
	if roll < 71 and no_throw:
		return _play(_rep(dir, rng.randi_range(2, 20)))
	if roll < 65:
		return _throw(dir)
	if roll < 71:
		return _second_throw(dir)
	if roll < 74:
		if _hand != -1:
			_event("hand", -1)
		return _play(_rep(0, 1))
	if roll < 80:
		# A vine: Up held, and a leap off it.
		var end: String = _play(_rep(U, rng.randi_range(8, 60)))
		if end != "" or rng.randf() < 0.5:
			return end
		return _play(_rep(U | dir, 4) + _rep(dir, rng.randi_range(8, 22)))
	if roll < 84:
		return _long_climb(dir)
	if roll < 87:
		if hero.is_grounded() and lib.s.partner != null and not no_place:
			_event("place", 0)
		return _play(_rep(0, 2))
	if roll < 89:
		# Down + Up (a dismount), a drop through a one-way floor.
		return _play(_rep(D, rng.randi_range(2, 10)) + _rep(D | U, 2) + _rep(dir, rng.randi_range(0, 12)))
	if roll < 92:
		var sprung: String = _spring(dir)
		if sprung != "none":
			return sprung
	if roll < 96:
		var lured: String = _lure_move()
		if lured != "none":
			return lured
	# A run: far, with jumps when something stops him.
	var steps: int = rng.randi_range(20, 90)
	var blocked: int = 0
	for i: int in steps:
		blocked = blocked + 1 if hero.is_grounded() and hero.xvel == 0 else 0
		if blocked >= 3:
			var jump: String = _play(_rep(U | dir, 9) + _rep(dir, 10))
			if jump != "":
				return jump
			blocked = 0
			continue
		var end: String = lib.step(dir)
		ticks_played += 1
		if end != "":
			return end
	return ""


## A throw of a special: standing, high, low or in a jump.
func _throw(dir: int) -> String:
	var weapon: int = [Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR][rng.randi_range(0, 2)]
	if _hand != weapon:
		_event("hand", weapon)
	var kind: int = rng.randi_range(0, 3)
	if kind == 0:
		return _play(_rep(dir, 1) + _rep(F, 6) + _rep(0, rng.randi_range(2, 20)))
	if kind == 1:
		return _play(_rep(dir, 1) + _rep(U | F, 8) + _rep(0, rng.randi_range(2, 20)))
	if kind == 2:
		return _play(_rep(dir, 1) + _rep(D | F, 8) + _rep(0, rng.randi_range(2, 20)))
	return _play(_rep(U | dir, rng.randi_range(3, 9)) + _rep(dir | F, 6) + _rep(dir, rng.randi_range(4, 14)))


## SECOND THROW (cause C of G3b: a bond or a drum pair broken by two hits in flight): a special thrown one way, then
## - after a delay of his choosing - a second throw or a strike the same or the other way: standing, walking on
## between the two, or both thrown in one jump (two axes in one jump between two drums).
func _second_throw(dir: int) -> String:
	var weapon: int = [Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR][rng.randi_range(0, 2)]
	if _hand != weapon:
		_event("hand", weapon)
	var other: int = dir if rng.randf() < 0.5 else (L if dir == R else R)
	var delay: int = rng.randi_range(0, 26)
	var kind: int = rng.randi_range(0, 3)
	var end: String = ""
	if kind == 0:
		# Two throws from where he stands.
		end = _play(_rep(dir, 1) + _rep(F, 6) + _rep(0, delay) + _rep(other, 1) + _rep(F, 6)
				+ _rep(0, rng.randi_range(2, 16)))
	elif kind == 1:
		# Both in one jump.
		end = _play(_rep(U | dir, rng.randi_range(3, 9)) + _rep(dir | F, 6) + _rep(0, 1 + delay / 4) + _rep(other, 1)
				+ _rep(other | F, 6) + _rep(other, rng.randi_range(4, 14)))
	elif kind == 2:
		# A throw, on toward what it flies at, and the club as it lands.
		end = _play(_rep(dir, 1) + _rep(F, 6) + _rep(other, delay) + _rep(other, 1) + _rep(F, 8) + _rep(0, 2))
		if end == "" and rng.randf() < 0.5:
			end = _play(_rep(F, 8) + _rep(0, 2))
	else:
		# A throw in a jump and a second from the ground.
		end = _play(_rep(U | dir, rng.randi_range(3, 9)) + _rep(dir | F, 6) + _rep(dir, rng.randi_range(4, 14)))
		if end == "":
			end = _play(_rep(0, delay) + _rep(other, 1) + _rep(F, 6) + _rep(0, rng.randi_range(2, 12)))
	return end


## LONG CLIMB (cause D of G3b: a climb the search could not play): Up held until he is off the vine's top or it
## carries him no higher - however long the vine - then a leap off it, a walk off its top, or a running jump.
func _long_climb(dir: int) -> String:
	var hero: PlayerBase = lib.hero()
	var still: int = 0
	var last_y: int = hero.sim_pos.y
	for i: int in 400:
		var end: String = _play(_rep(U, 1))
		if end != "":
			return end
		still = still + 1 if hero.sim_pos.y >= last_y else 0
		last_y = hero.sim_pos.y
		if still >= 6 or (i > 4 and hero.state != Defs.HeroState.CLIMB):
			break
	var kind: int = rng.randi_range(0, 3)
	if kind == 0:
		return ""
	if kind == 1:
		return _play(_rep(U | dir, 4) + _rep(dir, rng.randi_range(8, 30)))
	if kind == 2:
		return _play(_rep(dir, rng.randi_range(4, 40)))
	return _play(_rep(dir, rng.randi_range(4, 30)) + _rep(U | dir, 9) + _rep(dir, rng.randi_range(8, 30)))


## SPRING (cause B of G3b): a spring within a few steps - onto it, a low strike begun there and Up from its hop (the
## hop jump stacked on the spring's launch: 256 px before R1). "none" when no spring is near.
func _spring(dir: int) -> String:
	var hero: PlayerBase = lib.hero()
	var spring: SimEntity = _nearest_spring()
	if spring == null:
		return "none"
	var steps: int = 0
	while absi(spring.sim_pos.x - hero.sim_pos.x) > 6 and steps < 40:
		var walk: String = _play(_rep(lib.dir_flag(signi(spring.sim_pos.x - hero.sim_pos.x)), 1))
		if walk != "":
			return walk
		steps += 1
	var settle: String = _play(_rep(0, 6))
	if settle != "":
		return settle
	return _play(_rep(D | F, rng.randi_range(9, 11)) + _rep(U | (dir if rng.randf() < 0.5 else 0), 12)
			+ _rep(dir | (U if rng.randf() < 0.5 else 0), rng.randi_range(10, 50)))


## The nearest spring pad within 120 px on his floor (or a row beside it), or null.
func _nearest_spring() -> SimEntity:
	var hero: PlayerBase = lib.hero()
	var best: SimEntity = null
	var best_d: int = 120
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in lib.s.level.get_kind(kind):
			if entity is SpringPad and absi(entity.sim_pos.y - hero.sim_pos.y) <= 20 \
					and absi(entity.sim_pos.x - hero.sim_pos.x) < best_d:
				best_d = absi(entity.sim_pos.x - hero.sim_pos.x)
				best = entity
	return best


## The nearest living, awake enemy within 200 px (the one to ride), or null.
func _nearest_enemy() -> EnemyBase:
	var hero: PlayerBase = lib.hero()
	var best: EnemyBase = null
	var best_d: int = 200
	for entity: SimEntity in lib.s.level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy == null or enemy.dead or not enemy.awake:
			continue
		var d: int = absi(enemy.sim_pos.x - hero.sim_pos.x) + absi(enemy.sim_pos.y - hero.sim_pos.y) / 2
		if d < best_d:
			best_d = d
			best = enemy
	return best


## RIDE: Up held for `ticks` - come down on the nearest enemy (over it, or falling fast: any contact is a stomp
## then), keep clear of it otherwise; with nobody near, jump on the spot.
func _ride(ticks: int) -> String:
	var hero: PlayerBase = lib.hero()
	var held: bool = false
	var bias: int = [L, R, 0, 0][rng.randi_range(0, 3)]
	for i: int in ticks:
		var enemy: EnemyBase = _nearest_enemy()
		var flag: int = U
		if hero.is_grounded():
			if held:
				held = false
				flag = 0
			else:
				held = true
				flag = U | bias
		elif enemy != null:
			held = true
			var dx: int = enemy.sim_pos.x - hero.sim_pos.x
			var top: int = enemy.sim_pos.y - enemy.box_h
			if hero.sim_pos.y <= top + 3 or hero.yvel >= 120:
				flag = U | (lib.dir_flag(signi(dx)) if absi(dx) > 2 else 0)
			elif absi(dx) < 30:
				flag = U | lib.dir_flag(-signi(dx))
			else:
				flag = U | bias
		else:
			held = true
			flag = U | bias
		var end: String = lib.step(flag)
		ticks_played += 1
		if end != "":
			return end
	return ""


## LURE (cause A of G3b: a woken enemy is led to the gate): with a follower awake and near, on toward the far cell at
## a pace it keeps up with (he waits when it falls behind); else toward the nearest follower of the whole level that
## still sleeps, until it wakes. "none" when the level has no follower left.
func _lure_move() -> String:
	var hero: PlayerBase = lib.hero()
	var towed: EnemyBase = null
	var asleep: EnemyBase = null
	var towed_d: int = 240
	var asleep_d: int = 1 << 30
	for entity: SimEntity in lib.s.level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy == null or enemy.dead or enemy.keeper != &"" or not _is_follower(enemy):
			continue
		var d: int = absi(enemy.sim_pos.x - hero.sim_pos.x) + absi(enemy.sim_pos.y - hero.sim_pos.y)
		if enemy.awake and d < towed_d:
			towed_d = d
			towed = enemy
		elif not enemy.awake and d < asleep_d and rng.randf() < 0.7:
			asleep_d = d
			asleep = enemy
	if towed == null and asleep == null:
		return "none"
	_blocked = 0
	_jump_left = 0
	var ticks: int = rng.randi_range(40, 160)
	for i: int in ticks:
		var flag: int = 0
		if towed != null:
			if not is_instance_valid(towed) or towed.dead:
				return ""
			var gap: int = absi(towed.sim_pos.x - hero.sim_pos.x)
			if gap > 70 and hero.is_grounded() and _jump_left == 0:
				flag = 0   # (it falls behind: wait for it)
			else:
				flag = _go(hero, far_px.x, 5)
		else:
			if not is_instance_valid(asleep) or asleep.dead:
				return ""
			if asleep.awake:
				towed = asleep
				continue
			flag = _go(hero, asleep.sim_pos.x, 4)
		var end: String = lib.step(flag)
		ticks_played += 1
		if end != "":
			return end
	return ""


# =================================================================================================================
# The scripted lure (a prefix): wake a follower and lead it to the ride spot
# =================================================================================================================

func _lure(start_index: int, spec: String) -> PackedInt32Array:
	var parts: PackedStringArray = spec.split(";")
	var who: PackedStringArray = parts[0].split("@")
	var cell: PackedStringArray = who[1].split(",")
	var wake: Array[int] = []
	for x: String in parts[1].split(",", false):
		wake.append(x.to_int())
	var ride_x: int = parts[2].to_int()
	await lib.begin(lib.starts[start_index], 1)
	var follower: EnemyBase = lib.entity(who[0], cell[0].to_int(), cell[1].to_int()) as EnemyBase
	if follower == null:
		print("    lure: no %s at %s" % [who[0], who[1]])
		return PackedInt32Array()
	var hero: PlayerBase = lib.hero()
	var phase: int = 0
	var wake_index: int = 0
	_blocked = 0
	_jump_left = 0
	while lib.t < 1400:
		var flag: int = 0
		var after: bool = follower.awake and (bool(follower.get("_circling")) if follower.get("_circling") is bool
				else follower.sim_pos != follower.spawn_pos)
		if phase == 0:
			if after:
				phase = 1
			elif wake_index < wake.size():
				flag = _go(hero, wake[wake_index], 4)
				if absi(hero.sim_pos.x - wake[wake_index]) <= 4 and hero.is_grounded():
					wake_index += 1
			elif lib.t > 700:
				break
		else:
			var gap: int = absi(follower.sim_pos.x - hero.sim_pos.x)
			if absi(hero.sim_pos.x - ride_x) <= 5 and hero.is_grounded() and gap < 90:
				print("    lure: start %d, the %s follows; hero at %s, follower at %s after %d ticks (%d hurts)" % [
					start_index, who[0], str(hero.sim_pos), str(follower.sim_pos), lib.t, lib.hurts])
				return lib.s._flags.duplicate()
			if gap > 70 and hero.is_grounded() and _jump_left == 0:
				flag = 0
			else:
				flag = _go(hero, ride_x, 5)
		if lib.step(flag) != "":
			break
	print("    lure: start %d failed (phase %d, hero %s, follower %s awake %s)" % [start_index, phase,
		str(hero.sim_pos), str(follower.sim_pos), str(follower.awake)])
	return PackedInt32Array()


## The keys of one tick on the way to x (a crude navigator: a jump at a pit's lip or when a step stops him).
func _go(hero: PlayerBase, x: int, tolerance: int) -> int:
	var dir: int = signi(x - hero.sim_pos.x)
	if absi(x - hero.sim_pos.x) <= tolerance:
		dir = 0
	var keys: int = lib.dir_flag(dir)
	if _jump_left > 0:
		_jump_left -= 1
		return U | keys
	if dir == 0 or not hero.is_grounded():
		return keys
	_blocked = _blocked + 1 if hero.xvel == 0 else 0
	var col: int = Tuning.to_cell(hero.sim_pos.x + dir * 14)
	var row: int = Tuning.to_cell(hero.sim_pos.y + 2)
	var grid: TileGrid = lib.s.level.grid
	var under: String = grid.get_char(col, row) if grid.in_bounds(col, row) else "#"
	var pit: bool = under == "." or under == "~" or under == "^" or under == "+"
	if (pit or _blocked >= 4) and hero.no_jump == 0:
		_blocked = 0
		_jump_left = 8
		return U | keys
	return keys


# =================================================================================================================
# Roots from a route found elsewhere (the search world's, tried in the real game): every 20th tick of it that the
# hero lives to is a state to explore on from
# =================================================================================================================

func _prefix_roots(path: String, start_index: int) -> void:
	var route: Dictionary = (load(HARNESS) as GDScript).call(&"read_route", path)
	if route.is_empty():
		print("    prefix: %s is no route file" % path)
		return
	var flags: PackedInt32Array = route["flags"]
	await lib.begin(lib.starts[start_index], 1)
	var kept: int = 0
	var last: int = 0
	for i: int in flags.size():
		var end: String = lib.step(flags[i])
		if end == "goal":
			found = {"t": lib.t, "start": start_index, "events": [], "route": lib.route_text()}
			print("    prefix: the route itself REACHES the far cell here, at tick %d" % lib.t)
			return
		if end != "":
			break
		if lib.t % 20 == 0:
			var hero: PlayerBase = lib.hero()
			nodes.append({"parent": -1, "flags": flags.slice(0, lib.t), "events": [], "t": lib.t, "visits": 0,
				"start": start_index, "bounces": lib.bounces, "hand": -1, "placed": false, "check": _check(),
				"values": _values(hero, lib.bounces)})
			kept += 1
			last = lib.t
	print("    prefix: %d state(s) of %s kept (up to tick %d of %d; hero then at %s)" % [kept, path.get_file(), last,
		flags.size(), str(lib.hero().sim_pos) if lib.hero() != null else "?"])
