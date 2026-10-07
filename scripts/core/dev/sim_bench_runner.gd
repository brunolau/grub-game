extends Node
## The work of scripts/core/dev/sim_bench.gd (see there for the options). Owner: core. Development only.
##
## A route is played the way tests/test_campaign_routes.gd plays it: a fresh run of its difficulty (the source level
## of a bonus stage set as the warp would set it), the level entered through Flow without a transition, the view of
## the 1280 x 720 window, the weapon of the route table, its input flags tick by tick, and the stage it leads into
## (`then`) played the same way. Each tick is timed around Sim.step(1): input sampling, every phase and every
## end-of-tick handler. The tick that ends the stage is reported apart: with the instant transitions of a headless
## run it also performs the scene change, which the game does between frames.
##
## 2.0 (docs/expansion/PLAN.md P0.9): besides the 1.0 ROUTES table, every route file with a `# route:` header
## (Autoplay.parse_route_header) in the route folder (or in --route-dir) is a route: a party route starts a co-op run
## of its `players` (a versus run in an arena; Game.start_run with the level's book), plays one input stream per
## player slot (Autoplay.parse_inputs_multi) and puts the header's `belt` on every hero before the first tick. The
## belt-invariance runner (--belt-invariance) replays every such club route with each special on the belt and demands
## the same per-tick digests (PHYSICS.md C.2 rule 5: nothing in the simulation reads the belt of a route that never
## presses Swap). Tests replay routes in their own process through [method replay].

const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
const ROUTE_DIR: String = "res://tools/autoplay/routes/"
const LEVEL_DIR: String = "res://levels/"
const ROUTES_TEST: String = "res://tests/test_campaign_routes.gd"
const EXPERT: String = "expert"
const DEFAULT_OUT: String = "res://build/perf/bench"
const USER_DIR: String = "res://build/run_users/bench_"

var _routes: Dictionary = {}
var _route_dir: String = ROUTE_DIR
var _out: String = DEFAULT_OUT
var _digest: bool = false
var _profile: bool = false
var _tight: bool = false
## --alone: chained entries marked `alone` are also played from a fresh run (as tests/test_campaign_routes.gd does).
var _alone: bool = false
var _repeat: int = 1
var _pass: int = 0
var _digest_file: FileAccess = null
## --dump=<level>:<tick>: print the digest state of that tick entry by entry.
var _dump: String = ""
## Profile: "phase|script" -> PackedInt64Array [calls, usec].
var _calls: Dictionary = {}
var _profiled_ticks: int = 0
var _profiled_usec: int = 0
## Profile: the heavy calls of the tick being played ([key, usec] over SLOW_CALL_USEC) and the slowest ticks.
const SLOW_CALL_USEC: int = 15
const SLOW_TICKS_KEPT: int = 15
var _tick_calls: Array[Array] = []
var _slow_ticks: Array[Array] = []
var _stages: Array[Dictionary] = []
## Input slots (docs/expansion/PLAN.md P0.5): ticks checked and ticks where slot 0 was not exactly the route's flags,
## `flags` differed from get_flags(0), or a free slot read input.
var _input_ticks: int = 0
var _input_mismatches: int = 0
## The specials the belt-invariance runner puts on the belt, in order (PLAN.md 8 V2.b).
const BELT_SPECIALS: Array[int] = [Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]
## replay(): the digest lines are collected here instead of being written to a file.
var _collect: bool = false
var _lines: PackedStringArray = PackedStringArray()
## The weapon put on every hero's belt before a route's first tick (Defs.Weapon); -1 = what the route says (its
## header's `belt`; nothing for a 1.0 route).
var _belt: int = -1
## replay(): no line per stage on the console.
var _quiet: bool = false
## replay(): called after every tick as on_tick.call(level: LevelBase, stage_tick: int).
var _on_tick: Callable = Callable()
## replay(): false = the stage a route's `then` names is not played (the caller plays it with replay_stage()).
var _chain: bool = true


## Run the bench with the user arguments of the command line; returns the exit code.
func run(arguments: PackedStringArray) -> int:
	var options: Dictionary = {}
	var selection: PackedStringArray = PackedStringArray()
	for argument: String in arguments:
		if argument.begins_with("--"):
			var eq: int = argument.find("=")
			if eq < 0:
				options[argument.substr(2)] = ""
			else:
				options[argument.substr(2, eq - 2)] = argument.substr(eq + 1)
		else:
			selection.append(argument)
	if options.has("make-snapshot"):
		return _make_snapshot(str(options["make-snapshot"]))
	if options.has("load-profile"):
		_redirect_user_data()
		return await _load_profile(StringName(str(options["load-profile"])))
	if options.has("warm-up"):
		# Flow's background loading in a headless run (where it is off by default), until it is done.
		Flow.background_loading = true
		var start: int = Time.get_ticks_msec()
		Flow.warm_up(StringName(str(options["warm-up"])))
		while Flow.is_warming_up():
			await get_tree().process_frame
		print("SimBench: warm-up of %s done in %d ms" % [options["warm-up"], Time.get_ticks_msec() - start])
		return 0
	_out = str(options.get("out", DEFAULT_OUT))
	_digest = options.has("digest")
	_dump = str(options.get("dump", ""))
	_profile = options.has("profile")
	_tight = options.has("tight")
	_alone = options.has("alone")
	_repeat = maxi(int(options.get("repeat", "1")), 1)
	LevelBase.doze_enabled = not options.has("no-doze")
	if options.has("sleep"):
		# A headless run sleeps between frames (no window can draw); the default keeps the caches as cold as the
		# windowed game leaves them between two ticks.
		OS.low_processor_usage_mode_sleep_usec = int(options["sleep"])
	_redirect_user_data()
	if options.has("snapshot"):
		if not _use_snapshot(str(options["snapshot"])):
			return 2
	else:
		_routes = live_routes(str(options.get("route-dir", ROUTE_DIR)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var jobs: Array[Array] = []
	for file: String in _routes:
		var spec: Dictionary = _routes[file]
		var chained_only: bool = bool(spec.get("chained", false)) and not (_alone and bool(spec.get("alone", false)))
		if chained_only or not _selected(file, selection):
			continue
		if options.has("belt-invariance") and not _belt_invariant_route(spec):
			continue
		for mode: Variant in spec["modes"]:
			jobs.append([file, str(mode)])
	if options.has("belt-invariance"):
		return await _belt_invariance(jobs)
	print("SimBench: %d route run(s), %s, %s%s" % [jobs.size(), "tight loop" if _tight else "one frame per tick",
			"digest, " if _digest else "", "profile" if _profile else "timing"])
	if _profile:
		Sim._profiler = self
	for p: int in _repeat:
		_pass = p
		for job: Array in jobs:
			await _play_route(str(job[0]), str(job[1]))
			await _reset()
	Sim._profiler = null
	_report()
	return 0


# =================================================================================================================
# Load profile (--load-profile=<level id>, in a fresh process: what the first level start costs, step by step)
# =================================================================================================================

func _load_profile(level_id: StringName) -> int:
	var parts: Array[Array] = []
	var t: int = Time.get_ticks_usec()
	load(Flow.LEVEL_SCENE)
	t = _lap(parts, "level scene", t)
	Spawner.load_scene(&"player/player")
	t = _lap(parts, "player scene", t)
	Spawner.preload_runtime()
	t = _lap(parts, "runtime scenes (fx, items, projectiles)", t)
	var data: LevelData = LevelData.load_file(Levels.get_level_path(level_id))
	t = _lap(parts, "level file parse", t)
	var ids: Array[StringName] = []
	for record: Dictionary in data.entity_records():
		var id: StringName = record["id"]
		if not Spawner.is_prop(id) and not ids.has(id):
			ids.append(id)
	Spawner.preload_ids(ids)
	t = _lap(parts, "level entity scenes (%d)" % ids.size(), t)
	var meta: Dictionary = data.resolved_meta(Defs.Difficulty.BEGINNER)
	var terrain_a: String = str(meta.get("terrain_a", ""))
	WorldTileSet.build(terrain_a, str(meta.get("terrain_b", terrain_a)), str(meta.get("liquid", "water")))
	t = _lap(parts, "tile set build", t)
	for layer: Dictionary in ParallaxSets.layers(str(meta.get("background", "none"))):
		load(ParallaxSets.texture_path(layer))
	t = _lap(parts, "parallax textures", t)
	Audio.preload_music(StringName(str(meta.get("music", ""))))
	Audio.preload_music(Sfx.MUSIC_FEAST)
	t = _lap(parts, "music streams", t)
	for path: String in [Flow.HUD_SCENE, Flow.TOUCH_SCENE, Flow.PAUSE_SCENE]:
		load(path)
	t = _lap(parts, "hud, touch, pause scenes", t)
	Game.new_game(Defs.Difficulty.BEGINNER)
	Sim.manual = true
	var started: Array[int] = [0]
	Events.level_started.connect(func(_id: StringName) -> void: started[0] = Time.get_ticks_usec(), CONNECT_ONE_SHOT)
	t = Time.get_ticks_usec()
	Flow.start_level(level_id, Defs.Transition.NONE)
	while started[0] == 0:
		await get_tree().process_frame
	_lap(parts, "level start with everything loaded", t, started[0])
	var total: int = 0
	for part: Array in parts:
		total += int(part[1])
		print("  %-44s %8.1f ms" % [part[0], float(part[1]) / 1000.0])
	print("SimBench: load profile of %s: %.1f ms in total" % [level_id, float(total) / 1000.0])
	return 0


func _lap(parts: Array[Array], label: String, since: int, now: int = -1) -> int:
	var at: int = Time.get_ticks_usec() if now < 0 else now
	parts.append([label, at - since])
	return Time.get_ticks_usec()


# =================================================================================================================
# Snapshots
# =================================================================================================================

func _make_snapshot(dir: String) -> int:
	var absolute: String = ProjectSettings.globalize_path(dir)
	for sub: String in ["levels", "routes"]:
		DirAccess.make_dir_recursive_absolute(absolute + "/" + sub)
	var count: int = 0
	for file: String in DirAccess.get_files_at(LEVEL_DIR):
		if file.get_extension() == "lvl":
			DirAccess.copy_absolute(ProjectSettings.globalize_path(LEVEL_DIR + file), absolute + "/levels/" + file)
			count += 1
	for file: String in DirAccess.get_files_at(ROUTE_DIR):
		if file.get_extension() == "inputs":
			DirAccess.copy_absolute(ProjectSettings.globalize_path(ROUTE_DIR + file), absolute + "/routes/" + file)
			count += 1
	var routes: Dictionary = (load(ROUTES_TEST) as GDScript).get_script_constant_map()["ROUTES"]
	var out: FileAccess = FileAccess.open(dir + "/routes.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(routes, "\t", false))
	out.close()
	print("SimBench: snapshot of %d files and the route table in %s" % [count, dir])
	return 0


## Replay the frozen levels and routes of a snapshot: the registry points every level id of the snapshot at its
## copy (meta included), so Flow and the level loader read the copies.
func _use_snapshot(dir: String) -> bool:
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/routes.json"))
	if not table is Dictionary:
		print("SimBench: %s/routes.json is missing or broken" % dir)
		return false
	_routes = table
	_route_dir = dir + "/routes/"
	for file: String in DirAccess.get_files_at(dir + "/levels"):
		var path: String = dir + "/levels/" + file
		var id: StringName = StringName(file.get_basename())
		Levels._meta[id] = Levels.parse_meta(FileAccess.get_file_as_string(path))
		Levels._paths[id] = path
	Levels._index_campaign()
	print("SimBench: replaying the snapshot %s" % dir)
	return true


func _selected(file: String, selection: PackedStringArray) -> bool:
	if selection.is_empty():
		return true
	for wanted: String in selection:
		if file == wanted or file.begins_with(wanted):
			return true
	return false


# =================================================================================================================
# 2.0: route headers, in-process replays, belt invariance (docs/expansion/PLAN.md P0.9)
# =================================================================================================================

## The live route table: the 1.0 ROUTES of tests/test_campaign_routes.gd plus every header route of `header_dir`
## ([method header_routes]).
static func live_routes(header_dir: String = ROUTE_DIR) -> Dictionary:
	var routes: Dictionary = ((load(ROUTES_TEST) as GDScript).get_script_constant_map()["ROUTES"] as Dictionary).duplicate()
	var headers: Dictionary = header_routes(header_dir)
	for file: String in headers:
		if routes.has(file):
			push_error("SimBench: %s is in ROUTES and has a route header" % file)
			continue
		if not (headers[file]["errors"] as PackedStringArray).is_empty():
			push_error("SimBench: %s%s has a bad route header: %s" % [header_dir, file,
					"; ".join(headers[file]["errors"])])
			continue
		routes[file] = headers[file]
	return routes


## Every route file of `dir` that describes itself with a `# route:` header (docs/LEVEL_DESIGN.md 15.9), by file
## name: the entry Autoplay.parse_route_header reads (its "errors" included), plus "dir" (where the file is) and
## "chained": true for a route another header route of the folder names as its `then`. 1.0 routes (no header) are
## not listed.
static func header_routes(dir: String = ROUTE_DIR) -> Dictionary:
	var found: Dictionary = {}
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for file: String in files:
		if file.get_extension() != "inputs":
			continue
		var spec: Dictionary = Autoplay.parse_route_header(FileAccess.get_file_as_string(dir + file))
		if spec.is_empty():
			continue
		spec["dir"] = dir
		found[file] = spec
	for file: String in found:
		var next: String = str(found[file].get("then", ""))
		if found.has(next):
			found[next]["chained"] = true
	return found


## True for a route the belt-invariance runner replays: a header route without a `belt` of its own (a club route;
## a featured route starts with its special and is proven by its own replay).
static func _belt_invariant_route(spec: Dictionary) -> bool:
	return spec.has("header") and int(spec.get("belt", PlayerRun.BELT_EMPTY)) < 0


## In-process replay (tests): play route `file` of the route table on `mode` exactly as a --digest run plays it
## (the routes it chains with `then` included) and return {"lines": the digest lines with the "end" line of every
## stage, "screen": Flow.current_screen at the end, "level_id": the last level, "input_ticks", "input_mismatches"}.
## `options`: "routes" (the route table; default [method live_routes]), "route_dir" (folder of the 1.0 route files),
## "belt" (Defs.Weapon put on every hero's belt before the first tick; -1 = the route's own), "doze" (bool, default
## true), "on_tick" (Callable(level: LevelBase, stage_tick: int), after every tick), "keep" (true: leave the last
## stage running instead of clearing the scene; the caller cleans up), "chain" (false: do not play the route its
## `then` names; see [method replay_stage]). The node must be inside the tree.
func replay(file: String, mode: String, options: Dictionary = {}) -> Dictionary:
	var doze_before: bool = _begin_replay(options)
	var result: Dictionary = {}
	if not _routes.has(file):
		push_error("SimBench: no route %s" % file)
	else:
		await _play_route(file, mode)
		result = _replay_result()
		if not bool(options.get("keep", false)):
			await _reset()
	_end_replay(doze_before)
	return result


## In-process: play route `file` in the stage that runs now (the stage a replay() with "keep" and "chain": false
## led into, e.g. the linked stage its route names in `then`), with the options of [method replay]. Returns the
## same Dictionary.
func replay_stage(file: String, mode: String, options: Dictionary = {}) -> Dictionary:
	var doze_before: bool = _begin_replay(options)
	var result: Dictionary = {}
	if not _routes.has(file) or Game.level == null or Flow.current_screen != Flow.SCREEN_LEVEL:
		push_error("SimBench: no route %s or no stage running" % file)
	else:
		await _play_stage(file, mode)
		result = _replay_result()
		if not bool(options.get("keep", false)):
			await _reset()
	_end_replay(doze_before)
	return result


# The settings of an in-process replay; returns the doze switch to restore.
func _begin_replay(options: Dictionary) -> bool:
	_routes = (options["routes"] if options.has("routes") else live_routes()) as Dictionary
	_route_dir = str(options.get("route_dir", ROUTE_DIR))
	_belt = int(options.get("belt", -1))
	_on_tick = options.get("on_tick", Callable()) as Callable
	_chain = bool(options.get("chain", true))
	_tight = true
	_digest = true
	_collect = true
	_quiet = true
	_lines = PackedStringArray()
	_input_ticks = 0
	_input_mismatches = 0
	var doze_before: bool = LevelBase.doze_enabled
	LevelBase.doze_enabled = bool(options.get("doze", true))
	return doze_before


func _replay_result() -> Dictionary:
	return {"lines": _lines, "screen": Flow.current_screen, "level_id": Game.level_id,
		"input_ticks": _input_ticks, "input_mismatches": _input_mismatches}


func _end_replay(doze_before: bool) -> void:
	LevelBase.doze_enabled = doze_before
	_collect = false
	_on_tick = Callable()
	_belt = -1
	_chain = true
	_lines = PackedStringArray()


## The first difference of two replays' digest lines: "" when equal, else "line <n>: <a> / <b>".
static func first_difference(a: PackedStringArray, b: PackedStringArray) -> String:
	for i: int in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return "line %d: %s / %s" % [i + 1, a[i], b[i]]
	if a.size() != b.size():
		return "line %d: %d lines / %d lines" % [mini(a.size(), b.size()) + 1, a.size(), b.size()]
	return ""


## The belt-invariance proof of one route on one mode (PLAN.md 8 V2.b): replayed with an empty belt and then with
## each of BELT_SPECIALS on every hero's belt; returns {"ok", "ticks", "differences": [special name: first
## difference]}. `routes`: the route table (default: the one of the last run() / replay()); `options`: more
## [method replay] options for every replay (e.g. "on_tick").
func belt_invariance(file: String, mode: String, routes: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var table: Dictionary = routes if not routes.is_empty() else _routes
	var settings: Dictionary = options.duplicate()
	settings["routes"] = table
	settings["belt"] = PlayerRun.BELT_EMPTY
	var base: Dictionary = await replay(file, mode, settings)
	var reference: PackedStringArray = base.get("lines", PackedStringArray())
	var differences: PackedStringArray = PackedStringArray()
	if reference.is_empty():
		differences.append("the route did not play")
	for special: int in BELT_SPECIALS:
		settings["belt"] = special
		var other: Dictionary = await replay(file, mode, settings)
		var difference: String = first_difference(reference, other.get("lines", PackedStringArray()))
		if difference != "":
			differences.append("%s: %s" % [Defs.weapon_name(special), difference])
	return {"ok": differences.is_empty(), "ticks": reference.size(), "differences": differences}


## --belt-invariance: every selected header club route on each of its modes; exit code 0 when all are invariant.
func _belt_invariance(jobs: Array[Array]) -> int:
	var table: Dictionary = _routes
	var failed: int = 0
	var names: PackedStringArray = PackedStringArray()
	for special: int in BELT_SPECIALS:
		names.append(Defs.weapon_name(special))
	print("SimBench: belt invariance of %d route run(s) (belts: none, %s)" % [jobs.size(), ", ".join(names)])
	for job: Array in jobs:
		var result: Dictionary = await belt_invariance(str(job[0]), str(job[1]), table)
		if bool(result["ok"]):
			print("  %-28s %-8s identical with every belt (%d digest lines)" % [job[0], job[1], result["ticks"]])
		else:
			failed += 1
			print("  %-28s %-8s DIFFERENT: %s" % [job[0], job[1], "; ".join(result["differences"])])
	print("SimBench: belt invariance: %d route run(s), %d differ" % [jobs.size(), failed])
	return 0 if failed == 0 else 1


# =================================================================================================================
# Playing
# =================================================================================================================

func _play_route(file: String, mode: String) -> void:
	var spec: Dictionary = _routes[file]
	if spec.has("header"):
		_start_header_run(spec, mode)
	else:
		Game.new_game(_difficulty(mode))
	if spec.has("source"):
		Game.warp_return_level = StringName(str(spec["source"]))
	if _digest and _pass == 0 and not _collect:
		_digest_file = FileAccess.open("%s/%s.%s.digest" % [_out, file, mode], FileAccess.WRITE)
	if not await _enter(StringName(str(spec["level"]))):
		return
	_put_on_belts(spec)
	await _play_stage(file, mode)
	var chained: String = str(spec.get("then", ""))
	if _chain and chained != "" and Flow.current_screen == Flow.SCREEN_LEVEL and Game.level != null:
		await _play_stage(chained, mode)
	if _digest_file != null:
		_digest_file.close()
		_digest_file = null


func _play_stage(file: String, mode: String) -> void:
	var spec: Dictionary = _routes[file]
	if spec.has("weapon"):
		Game.set_weapon(int(spec["weapon"]))
	var streams: Array[PackedInt32Array] = _route_streams(spec, file, mode)
	var flags: PackedInt32Array = streams[0]
	var index: Array[int] = [0]
	if streams.size() == 1:
		GameInput.set_scripted(func(_tick: int) -> int:
			var value: int = flags[index[0]] if index[0] < flags.size() else 0
			index[0] += 1
			return value
		)
	else:
		# A party: every slot reads the entry of the tick being played (index[0], set before each step).
		for slot: int in streams.size():
			var stream: PackedInt32Array = streams[slot]
			GameInput.set_scripted_slot(slot, func(_tick: int) -> int:
				return stream[index[0]] if index[0] < stream.size() else 0
			)
	var level: LevelBase = Game.level
	var level_id: StringName = level.level_id
	var costs: PackedInt32Array = PackedInt32Array()
	var entities_max: int = 0
	var entities_sum: int = 0
	var awake_sum: int = 0
	var awake_max: int = 0
	var exit_cost: int = -1
	var played: int = 0
	while played < flags.size() and Sim.running and Game.level == level:
		if streams.size() > 1:
			index[0] = played
		var start: int = Time.get_ticks_usec()
		Sim.step(1)
		var cost: int = Time.get_ticks_usec() - start
		if streams.size() == 1:
			_check_input(flags[played], level_id)
		else:
			_check_party_input(streams, played, level_id)
		played += 1
		if Sim.running and Game.level == level:
			costs.append(cost)
			if _profile:
				_note_tick("%s %s" % [level_id, mode], cost)
			var count: int = Sim.get_entity_count()
			entities_sum += count
			awake_sum += Sim.get_awake_count()
			awake_max = maxi(awake_max, Sim.get_awake_count())
			entities_max = maxi(entities_max, count)
			if _digest_file != null or _collect:
				_store_line(_digest_line(level))
			if _on_tick.is_valid():
				_on_tick.call(level, played)
		else:
			exit_cost = cost
		if not _tight:
			await get_tree().process_frame
	GameInput.clear_scripted()
	if _digest_file != null or _collect:
		_store_line("end %s ticks %d score %d lives %d weapon %d items %d spots %d secrets %d screen %s" % [
			level_id, played, Game.score, Game.lives, Game.weapon, Game.items_collected, Game.spots_opened,
			Game.secrets_found, Flow.current_screen])
	var sorted: PackedInt32Array = costs.duplicate()
	sorted.sort()
	var total: int = 0
	for c: int in costs:
		total += c
	var row: Dictionary = {
		"route": file, "mode": mode, "level": String(level_id), "pass": _pass, "ticks": played,
		"avg_us": float(total) / maxf(float(costs.size()), 1.0), "p50_us": _pct(sorted, 0.5),
		"p99_us": _pct(sorted, 0.99), "max_us": _pct(sorted, 1.0), "exit_tick_us": exit_cost,
		"entities_avg": float(entities_sum) / maxf(float(costs.size()), 1.0), "entities_max": entities_max,
		"awake_avg": float(awake_sum) / maxf(float(costs.size()), 1.0), "awake_max": awake_max,
		"score": Game.score,
	}
	_stages.append(row)
	if not _quiet:
		print("  %-28s %-8s %-7s %5d ticks  avg %4d  p50 %4d  p99 %5d  max %5d us  (exit tick %d us)  ent avg %3d max %3d awake %3d max %3d  score %d" % [
			file, mode, level_id, played, int(row["avg_us"]), row["p50_us"], row["p99_us"], row["max_us"], exit_cost,
			int(row["entities_avg"]), entities_max, int(row["awake_avg"]), awake_max, Game.score])
	await _settle()
	if Flow.current_screen == Flow.SCREEN_LEVEL and Game.level != null and Game.level != level:
		_set_view()


## The input slots after a tick of a single-player route: slot 0 read exactly the route's flags, `flags` is
## get_flags(0), and slots 1..3 read nothing (PLAN.md P0.5). A mismatch is counted and reported.
func _check_input(expected: int, level_id: StringName) -> void:
	_input_ticks += 1
	var ok: bool = GameInput.flags == expected and GameInput.get_flags(0) == GameInput.flags
	for slot: int in range(1, Defs.MAX_PLAYERS):
		ok = ok and GameInput.get_flags(slot) == 0
	if not ok:
		_input_mismatches += 1
		if _input_mismatches <= 3:
			push_error("SimBench: input slots differ in %s tick %d: route %d, flags %d, slots %s" % [level_id,
					Sim.tick, expected, GameInput.flags, str(GameInput.slot_flags)])


## The input party check (PLAN.md P0.5, TECH_AUDIT.md 4.11): after a tick of a party route, slot k read exactly
## stream k, `flags` is get_flags(0), and the slots beyond the party read nothing.
func _check_party_input(streams: Array[PackedInt32Array], played: int, level_id: StringName) -> void:
	_input_ticks += 1
	var ok: bool = GameInput.get_flags(0) == GameInput.flags
	for slot: int in Defs.MAX_PLAYERS:
		var expected: int = streams[slot][played] if slot < streams.size() else 0
		ok = ok and GameInput.get_flags(slot) == expected
	if not ok:
		_input_mismatches += 1
		if _input_mismatches <= 3:
			push_error("SimBench: input slots differ in %s tick %d: slots %s" % [level_id, Sim.tick,
					str(GameInput.slot_flags)])


## The input text of a route: its file, after the prefix of a side path (tests/test_campaign_routes.gd). A header
## route is read from the folder it was found in.
func _route_text(spec: Dictionary, file: String, mode: String) -> String:
	var dir: String = str(spec.get("dir", _route_dir))
	var text: String = ""
	if spec.has("prefix"):
		var main: String = str(spec["prefix"][0])
		if main == "@route":
			main = "%s.expert.inputs" % spec["level"] if mode == EXPERT else "%s.inputs" % spec["level"]
			if not FileAccess.file_exists(dir + main):
				main = "%s.inputs" % spec["level"]
		var marker: String = str(spec["prefix"][1])
		var lines: PackedStringArray = PackedStringArray()
		for line: String in FileAccess.get_file_as_string(dir + main).split("\n"):
			if line.strip_edges().begins_with(marker):
				break
			lines.append(line)
		text = "\n".join(lines) + "\n"
	return text + FileAccess.get_file_as_string(dir + file)


## The input streams of a route (one per player slot): a 1.0 route is one stream, parsed exactly as in 1.0.
func _route_streams(spec: Dictionary, file: String, mode: String) -> Array[PackedInt32Array]:
	var text: String = _route_text(spec, file, mode)
	if not spec.has("header"):
		return [Autoplay.parse_inputs(text)] as Array[PackedInt32Array]
	var streams: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(text)
	var players: int = int(spec.get("players", 1))
	while streams.size() < players:
		var idle: PackedInt32Array = PackedInt32Array()
		idle.resize(streams[0].size())
		streams.append(idle)
	return streams


## The run a header route starts in (docs/LEVEL_DESIGN.md 15.9): a party of its `players` in co-op (versus in an
## arena), the book of its level; one hero of the level's book otherwise.
func _start_header_run(spec: Dictionary, mode: String) -> void:
	var level_id: StringName = StringName(str(spec["level"]))
	var players: int = int(spec.get("players", 1))
	var game_mode: int = Defs.GameMode.SINGLE
	if players > 1:
		game_mode = Defs.GameMode.VERSUS if Levels.is_arena(level_id) else Defs.GameMode.COOP
	Game.start_run(_difficulty(mode), game_mode, players, maxi(Levels.get_book(level_id), 1))


## Put the belt of the run on every hero of the party, before the first tick: the --belt-invariance / replay()
## special, else the header's `belt`. Nothing for a 1.0 route. Set after the level started, so that whatever the
## stage start does to the belt (the fresh-club rule, PHYSICS.md C.2 rule 4) cannot undo it.
func _put_on_belts(spec: Dictionary) -> void:
	var belt: int = _belt if _belt >= 0 else int(spec.get("belt", PlayerRun.BELT_EMPTY))
	if belt < 0 and not spec.has("header"):
		return
	for slot: int in Game.party:
		Game.runs[slot].set_belt(belt)


## Write a digest line to the digest file, or keep it (replay()).
func _store_line(line: String) -> void:
	if _collect:
		_lines.append(line)
	elif _digest_file != null:
		_digest_file.store_line(line)


func _enter(level_id: StringName) -> bool:
	Sim.manual = true
	await _idle()
	Flow.start_level(level_id, Defs.Transition.NONE)
	await _settle()
	if Flow.current_screen != Flow.SCREEN_LEVEL or Game.level == null or Game.level.level_id != level_id:
		print("SimBench: %s did not start" % level_id)
		return false
	_set_view()
	return true


func _set_view() -> void:
	var level: Level = Game.level as Level
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)


func _reset() -> void:
	GameInput.clear_scripted()
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	await _idle()


func _idle() -> void:
	await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _difficulty(mode: String) -> int:
	return Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER


func _redirect_user_data() -> void:
	var dir: String = USER_DIR + str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	Save.set_storage_dir(dir)
	Settings.set_storage_dir(dir)


# =================================================================================================================
# Digest: everything the simulation decides, after every tick
# =================================================================================================================

## The digest line of the running level's state now (what a --digest run writes after a tick); tests compare it with
## the belt changed (PHYSICS.md C.2 rule 5: the belt is not part of it) and with anything else changed.
func digest_line(level: LevelBase) -> String:
	return _digest_line(level)


## One line per tick: tick, RNG state, score, the hero's feet point and a hash over the run state, the camera and
## every entity of the level that is not a cosmetic effect (feet point, velocities, facing, box, on_screen; enemies
## also awake / dead / hit points / tangible / flash; items whether collected).
## Frozen for a party of one (docs/expansion/TECH_AUDIT.md 4.12 #3): the heroes of slots 1.. and their runs are
## appended to the hashed state only when the level holds more than one hero.
func _digest_line(level: LevelBase) -> String:
	var state: Array = [
		Sim.tick, Sim.rng.get_state(), Game.score, Game.lives, Game.hearts, Game.bones, Game.letters, Game.weapon,
		Game.has_glider, Game.feast_kit, Game.exit_unlocked, Game.items_collected, Game.spots_opened,
		Game.secrets_found, Game.has_checkpoint, Game.checkpoint_pos, level.active_enemies, level.get_view_rect(),
		level.wind, level.dark, level.shake, level.shake_offset, level.completed, level.time_left,
	]
	var hero: PlayerBase = level.player
	var hero_pos: Vector2i = Vector2i(-1, -1)
	if hero != null:
		hero_pos = hero.sim_pos
		state.append_array([hero.sim_pos, hero.xvel, hero.yvel, hero.state, hero.facing, hero.grounded,
			hero.hit_timer, hero.dead, hero.box_w, hero.box_h, hero.box_xo, hero.charge, hero.feast, hero.glide,
			hero.on_platform, hero.ice, hero.swing_lock, hero.drop_timer, hero.club_box_active, hero.club_box,
			hero.on_screen])
	if level.hero_count() > 1:
		_digest_party(level, state)
	for kind: int in Defs.KIND_COUNT:
		if kind == Defs.Kind.FX or kind == Defs.Kind.PLAYER:
			continue
		for entity: SimEntity in level.get_kind(kind):
			# A node queued for deletion is gone in the game at the end of the frame; a tight loop keeps it longer.
			if not is_instance_valid(entity) or entity.is_queued_for_deletion():
				continue
			var item: CollectibleBase = entity as CollectibleBase
			if item != null and item.collected and not item.reappears_on_respawn:
				continue
			if not _dump.is_empty():
				state.append(entity.name)  # auto-generated names shift with every node created anywhere
			state.append_array([kind, entity.sim_pos, entity.xvel, entity.yvel, entity.facing, entity.box_w,
				entity.box_h, entity.box_xo, entity.on_screen])
			var enemy: EnemyBase = entity as EnemyBase
			if enemy != null:
				state.append_array([enemy.awake, enemy.dead, enemy.hp, enemy.tangible, enemy.flash])
			elif item != null:
				state.append(item.collected)
	if _dump.begins_with(String(level.level_id) + ":") and absi(int(_dump.get_slice(":", 1)) - Sim.tick) <= 2:
		var dozing: PackedStringArray = PackedStringArray()
		for entity: SimEntity in level._doze:
			if entity.is_dozing():
				dozing.append(String(entity.name))
		print("SimBench dump %s tick %d: view %s hero %s bounds %s dozing %s" % [_dump, Sim.tick, level.get_view_rect(),
				hero_pos, _doze_bounds(level), ",".join(dozing)])
	return "%d %d %d %d,%d %x" % [Sim.tick, Sim.rng.get_state(), Game.score, hero_pos.x, hero_pos.y, hash(state)]


## The party part of the digest (more than one hero): every hero of slot 1.. in slot order with the fields hashed
## for P1, then his run (hearts, bones, hand, glider). The belt is not hashed, as P1's is not (PHYSICS.md C.2 rule
## 5: a digest excludes the belt, so the belt-invariance runner compares the same lines whatever the belt holds).
func _digest_party(level: LevelBase, state: Array) -> void:
	for hero: PlayerBase in level.heroes:
		if hero == null or hero == level.player:
			continue
		var run: PlayerRun = hero.run
		state.append_array([hero.slot, hero.sim_pos, hero.xvel, hero.yvel, hero.state, hero.facing, hero.grounded,
			hero.hit_timer, hero.dead, hero.box_w, hero.box_h, hero.box_xo, hero.charge, hero.feast, hero.glide,
			hero.on_platform, hero.ice, hero.swing_lock, hero.drop_timer, hero.club_box_active, hero.club_box,
			hero.on_screen, run.hearts, run.bones, run.weapon, run.has_glider])


## The grid-rounded rectangles of the level's last doze decision (ARCHITECTURE.md 11.1), for --dump, as
## "view l,t..r,b hero l,t..r,b" plus "more l,t..r,b ..." for the further views and heroes of a party: an idle
## entity whose doze area touches none of them may doze (LevelBase._doze_far).
func _doze_bounds(level: LevelBase) -> String:
	var text: String = "view %d,%d..%d,%d hero %d,%d..%d,%d" % [level._dz_view_left, level._dz_view_top,
			level._dz_view_right, level._dz_view_bottom, level._dz_hero_left, level._dz_hero_top, level._dz_hero_right,
			level._dz_hero_bottom]
	for r: int in level._dz_more_count:
		var j: int = r * 4
		text += " more %d,%d..%d,%d" % [level._dz_more[j], level._dz_more[j + 1], level._dz_more[j + 2],
				level._dz_more[j + 3]]
	return text


# =================================================================================================================
# Profile and report
# =================================================================================================================

## Sim._profiler callback: a part of the tick outside the entity calls took `usec`.
func add_part(part: StringName, usec: int) -> void:
	var key: String = "TICK|" + String(part)
	var entry: PackedInt64Array = _calls.get(key, PackedInt64Array([0, 0]))
	entry[0] += 1
	entry[1] += usec
	_calls[key] = entry


## Sim._profiler callback: one `_sim_tick(phase)` call of an entity with this script took `usec`.
func add_call(phase: int, script: Script, usec: int) -> void:
	var key: String = "%s|%s" % [Defs.Phase.keys()[phase], script.resource_path.get_file() if script != null else "?"]
	var entry: PackedInt64Array = _calls.get(key, PackedInt64Array([0, 0]))
	entry[0] += 1
	entry[1] += usec
	_calls[key] = entry
	if usec >= SLOW_CALL_USEC:
		_tick_calls.append([key, usec])


## Keep the tick just played among the slowest ones (profile mode), with its heavy calls.
func _note_tick(label: String, cost: int) -> void:
	if _slow_ticks.size() < SLOW_TICKS_KEPT or cost > int(_slow_ticks[_slow_ticks.size() - 1][0]):
		_slow_ticks.append([cost, label, Sim.tick, _tick_calls.duplicate()])
		_slow_ticks.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
		if _slow_ticks.size() > SLOW_TICKS_KEPT:
			_slow_ticks.resize(SLOW_TICKS_KEPT)
	_tick_calls.clear()


func _report() -> void:
	var by_level: Dictionary = {}
	for row: Dictionary in _stages:
		var level: String = str(row["level"])
		if not by_level.has(level):
			by_level[level] = [0, 0.0, 0, 0, 0]
		var acc: Array = by_level[level]
		acc[0] = int(acc[0]) + int(row["ticks"])
		acc[1] = float(acc[1]) + float(row["avg_us"]) * float(row["ticks"])
		acc[2] = maxi(int(acc[2]), int(row["p99_us"]))
		acc[3] = maxi(int(acc[3]), int(row["max_us"]))
		acc[4] = maxi(int(acc[4]), int(row["entities_max"]))
	print("SimBench: per level (all routes and passes): ticks, average, worst route p99, max, most entities")
	var all_ticks: int = 0
	var all_sum: float = 0.0
	for level: String in by_level:
		var acc: Array = by_level[level]
		all_ticks += int(acc[0])
		all_sum += float(acc[1])
		print("  %-8s %6d ticks  avg %4d us  p99 %5d us  max %5d us  entities %3d" % [level, acc[0],
				int(float(acc[1]) / maxf(float(acc[0]), 1.0)), acc[2], acc[3], acc[4]])
	print("SimBench: input slots: %d tick(s), slot 0 == route flags == flags == get_flags(0), slots 1..%d silent (a party route: slot k == stream k); %d mismatch(es)" % [
			_input_ticks, Defs.MAX_PLAYERS - 1, _input_mismatches])
	print("SimBench: all levels %d ticks, average %.1f us per tick" % [all_ticks, all_sum / maxf(float(all_ticks), 1.0)])
	if _profile:
		var rows: Array[Array] = []
		var calls_total: int = 0
		for key: String in _calls:
			var entry: PackedInt64Array = _calls[key]
			rows.append([key, entry[0], entry[1]])
			calls_total += entry[1]
		rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
		var ticks: int = maxi(all_ticks, 1)
		print("SimBench: profile, usec per tick by phase|script (calls per tick, usec per call); %.1f us per tick in calls" % [
			float(calls_total) / float(ticks)])
		for row: Array in rows:
			print("  %-44s %7.2f us/tick  %6.2f calls/tick  %5.2f us/call" % [row[0], float(row[2]) / float(ticks),
					float(row[1]) / float(ticks), float(row[2]) / maxf(float(row[1]), 1.0)])
		print("SimBench: slowest ticks and their calls of %d us or more" % SLOW_CALL_USEC)
		for slow: Array in _slow_ticks:
			var parts: PackedStringArray = PackedStringArray()
			for call: Array in slow[3]:
				parts.append("%s %d" % [call[0], call[1]])
			print("  %6d us  %-16s tick %5d: %s" % [slow[0], slow[1], slow[2], ", ".join(parts)])
	var out: FileAccess = FileAccess.open(_out + "/bench.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify({"stages": _stages}, "\t", false))
		out.close()


func _pct(sorted: PackedInt32Array, fraction: float) -> int:
	if sorted.is_empty():
		return 0
	return sorted[clampi(int(ceil(fraction * float(sorted.size()))) - 1, 0, sorted.size() - 1)]
