extends Node
## THE EXACT RESET'S OWN CHECK (wf11, R7: "a found route always replays in a fresh process"; world-B). On the search
## world of one gate it plays a set of routes - the evidence routes of that gate and `runs` random ones (seeded: runs,
## jumps, strikes, throws of every special, the idle partner parked) - `rounds` times over, each round in another
## order, and compares the whole world tick by tick (harness.gd world_hash: the hero and every entity) with the same
## route's first play. A world whose reset is exact gives every route the same trajectory whatever was played before
## it; the first route of a process starts from the world a fresh process builds, so the printed digest is the same
## for every `order=` and in every process (tools/coop_explore/exact.sh runs two orders and compares).
## With audit=1 every reset compares EVERY entity with the level-file world (CoopSearch.reset_audit), also those
## that never ticked.
## Usage: bash .tools/gd.sh script res://tools/coop_explore/main.gd -- exact <level> <gate> <0|1> [whole=1] [runs=24]
##        [rounds=3] [ticks=500] [seed=1] [order=1] [audit=1] [report=1]
## Prints `EXACT <level> d<d> <gate>: <routes> routes x <rounds> plays, <n> play(s) off their first trajectory ...
## digest <md5>`; exit code 0 = none off and no drift, 1 = the reset is not exact (the first differing tick is named).

const HARNESS: String = "res://tools/coop_explore/harness.gd"
const L: int = Defs.IN_LEFT
const R: int = Defs.IN_RIGHT
const U: int = Defs.IN_UP
const D: int = Defs.IN_DOWN
const F: int = Defs.IN_FIRE


func run(arguments: PackedStringArray) -> int:
	if arguments.size() < 3:
		print("EXACT: want <level> <gate> <0|1>")
		return 2
	var args: Dictionary = {}
	for i: int in range(3, arguments.size()):
		var eq: int = arguments[i].find("=")
		if eq > 0:
			args[arguments[i].substr(0, eq)] = arguments[i].substr(eq + 1)
	var result: Dictionary = check(StringName(arguments[0]), arguments[1], arguments[2].to_int(),
		str(args.get("whole", "0")) == "1", str(args.get("runs", "24")).to_int(), str(args.get("rounds", "3")).to_int(),
		str(args.get("ticks", "500")).to_int(), str(args.get("seed", "1")).to_int(),
		str(args.get("order", "1")).to_int(), str(args.get("audit", "0")) == "1", str(args.get("report", "0")) == "1")
	for line: String in result.get("lines", []):
		print(line)
	return 0 if bool(result.get("exact", false)) else 1


## The check as a call (tests/test_world_search.gd): {"exact": bool, "routes", "plays", "off", "drift", "audit_drift",
## "respawns", "party_respawns", "digest", "lines"}.
static func check(level: StringName, gate: String, difficulty: int, whole: bool, runs: int, rounds: int, ticks: int,
		seed_value: int, order: int, audit: bool, report: bool) -> Dictionary:
	var harness: GDScript = load(HARNESS) as GDScript
	var lib: RefCounted = harness.new()
	if not lib.build(level, gate, difficulty, whole):
		return {"exact": false, "lines": PackedStringArray(["EXACT %s d%d %s: cannot build the world" % [level,
			difficulty, gate]])}
	return check_lib(lib, runs, rounds, ticks, seed_value, order, audit, report)


## [method check] on a harness that is built already (harness.gd build / build_data); it is closed at the end.
static func check_lib(lib: RefCounted, runs: int, rounds: int, ticks: int, seed_value: int, order: int, audit: bool,
		report: bool) -> Dictionary:
	var harness: GDScript = load(HARNESS) as GDScript
	var lines: PackedStringArray = PackedStringArray()
	var level: StringName = lib.data.id
	var gate: String = lib.gate
	var difficulty: int = lib.difficulty
	var whole: bool = lib.whole
	var audit_before: bool = CoopSearch.reset_audit
	var report_before: bool = CoopSearch.collect_reset_report
	CoopSearch.reset_audit = audit
	CoopSearch.collect_reset_report = report
	if report:
		CoopSearch.reset_report = {}
	# The routes: the evidence set's for this gate, then the random ones.
	var routes: Array[Dictionary] = []
	for path: String in harness.call(&"evidence_files", level, gate, difficulty):
		var route: Dictionary = harness.call(&"read_route", path)
		if not bool(route["real"]) and bool(route["whole"]) == whole and int(route["tick0"]) == lib.s.tick_base:
			route["name"] = path.get_file()
			routes.append(route)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in runs:
		routes.append(_random_route(rng, lib, ticks, i))
	var first: Array = []   # per route: PackedInt64Array of world hashes
	first.resize(routes.size())
	var off: int = 0
	var plays: int = 0
	var shuffle: RandomNumberGenerator = RandomNumberGenerator.new()
	shuffle.seed = order
	for round_index: int in rounds:
		var indices: Array = range(routes.size())
		for i: int in range(indices.size() - 1, 0, -1):
			var j: int = shuffle.randi_range(0, i)
			var swap: int = indices[i]
			indices[i] = indices[j]
			indices[j] = swap
		for index: int in indices:
			var trace: PackedInt64Array = PackedInt64Array()
			lib.play_route(routes[index], func(_t: int, _flag: int) -> void: trace.append(lib.world_hash()))
			plays += 1
			if first[index] == null:
				first[index] = trace
				continue
			var was: PackedInt64Array = first[index]
			if was == trace:
				continue
			off += 1
			var at: int = 0
			while at < mini(was.size(), trace.size()) and was[at] == trace[at]:
				at += 1
			if off <= 6:
				lines.append("    OFF: %s (round %d) leaves its first trajectory at tick %d of %d / %d" % [
					routes[index]["name"], round_index + 1, at + 1, was.size(), trace.size()])
	var digest: PackedStringArray = PackedStringArray()
	for index: int in routes.size():
		digest.append("%s=%d" % [routes[index]["name"], hash(first[index])])
	var searcher: CoopSearch.Searcher = lib.s
	var exact: bool = off == 0 and searcher.drift == 0 and searcher.audit_drift == 0
	lines.append("EXACT %s d%d %s%s: %d routes x %d plays, %d play(s) off their first trajectory, %d entities left changed by a reset, %d changed without a tick (audit %s); in %d resets %d entities respawned in place and %d put back by their variables, the heroes built anew %d times; digest %s" % [
		level, difficulty, gate, " whole" if whole else "", routes.size(), rounds, off, searcher.drift,
		searcher.audit_drift, "on" if audit else "off", searcher.runs, searcher.respawns, searcher.restores,
		searcher.party_respawns,
		"|".join(digest).md5_text()])
	if report:
		for line: String in CoopSearch.reset_report_lines():
			lines.append("    reset found: %s" % line)
	var result: Dictionary = {"exact": exact, "routes": routes.size(), "plays": plays, "off": off,
		"drift": searcher.drift, "audit_drift": searcher.audit_drift, "respawns": searcher.respawns,
		"party_respawns": searcher.party_respawns, "digest": "|".join(digest).md5_text(), "lines": lines}
	CoopSearch.reset_audit = audit_before
	CoopSearch.collect_reset_report = report_before
	lib.close()
	return result


## A random route of about `ticks` ticks from one of the gate's starts: moves of a few ticks each (runs, jumps,
## crouches, strikes, throws, climbs), a special taken in hand now and then, the idle partner parked once in a while.
static func _random_route(rng: RandomNumberGenerator, lib: RefCounted, ticks: int, number: int) -> Dictionary:
	var flags: PackedInt32Array = PackedInt32Array()
	var events: Array = []
	while flags.size() < ticks:
		var dir: int = R if rng.randf() < 0.6 else L
		var roll: int = rng.randi_range(0, 99)
		if roll < 30:
			_add(flags, dir, rng.randi_range(4, 40))
		elif roll < 50:
			_add(flags, U | dir, rng.randi_range(2, 12))
			_add(flags, dir | (U if rng.randf() < 0.5 else 0), rng.randi_range(6, 30))
		elif roll < 58:
			_add(flags, D | (dir if rng.randf() < 0.5 else 0), rng.randi_range(4, 20))
		elif roll < 72:
			_add(flags, dir, 1)
			_add(flags, [F, U | F, D | F][rng.randi_range(0, 2)], rng.randi_range(6, 12))
			_add(flags, 0, 2)
		elif roll < 80:
			_add(flags, D | F, rng.randi_range(7, 10))
			_add(flags, U | dir, rng.randi_range(5, 12))
			_add(flags, dir, rng.randi_range(6, 20))
		elif roll < 88:
			events.append([flags.size(), "hand", [Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR, -1][
				rng.randi_range(0, 3)]])
			_add(flags, dir, 1)
			_add(flags, F, 6)
			_add(flags, 0, rng.randi_range(2, 16))
		elif roll < 92:
			_add(flags, U, rng.randi_range(8, 60))
		elif roll < 95:
			events.append([flags.size(), "place", 0])
			_add(flags, 0, 2)
		else:
			_add(flags, 0, rng.randi_range(1, 30))
	return {"level": lib.data.id, "gate": lib.gate, "difficulty": lib.difficulty, "whole": lib.whole,
		"start": rng.randi_range(0, lib.starts.size() - 1), "real": false, "tickoff": 0, "events": events,
		"flags": flags, "name": "random %d" % number}


static func _add(flags: PackedInt32Array, flag: int, count: int) -> void:
	for i: int in count:
		flags.append(flag)
