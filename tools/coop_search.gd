extends SceneTree
## The solo-impossibility search from the command line (scripts/world/coop_search.gd; docs/expansion/PLAN.md 8 V3.c,
## LEVEL_DESIGN.md 15.7.6). Owner: world-B (PLAN.md 4.1).
##
## Usage (from the project root):
##   bash .tools/gd.sh script res://tools/coop_search.gd -- --list               the gate table of test_coop_gates
##   bash .tools/gd.sh script res://tools/coop_search.gd -- w5_l1_coop           every gate of these files
##   bash .tools/gd.sh script res://tools/coop_search.gd -- w5_l1_coop:hop       one gate, both difficulties
##   bash .tools/gd.sh script res://tools/coop_search.gd -- w5_l1_coop:hop:expert   one gate, one difficulty
##   ... -- --shard=<i>/<n>     only the gates of shard i of n ([method CoopSearch.shard_gates], the rule of
##                              tools/world_coop_gates.sh and of test_coop_gates' COOP_GATES_SHARD)
##   ... -- --profile           where the time of every search went (reset, place, step, sig, build, windows ...)
##   ... -- --sim-profile       the tick time by entity script (Sim's development profiler hook)
##   ... -- --nodes             print every resting point the search expands (and what its world changed)
##   ... -- --moves             ... and every move of every resting point with where it ended
##   ... -- --reset-report      what the exact reset found changed after the runs (which variables of which entities
##                              a level reset leaves, which entities it spawned again; CoopSearch.reset_report)
##   ... -- --audit             every reset compares EVERY entity with the level-file world, not only those that
##                              ticked (CoopSearch.reset_audit: the check of the rule the exact reset rests on; slow)
##   ... -- --egg               the partner stays an egg (no idle hatched partner, CoopSearch.idle_partner = false): tells a
##                              gate one player opens through his idle partner from one he opens alone
##   ... -- --stats             runs, ticks and new resting points per macro group (what the search spends its time on)
##   ... -- --no-cache          no result cache (neither the in-process nor the file cache of CoopSearch)
##   ... -- --fresh             search every chosen gate again (no cache READ) and store the result: the uncached
##                              proof run of G59 (tools/world_coop_gates.sh --fresh)
##   ... -- --table             print only the G59 verdict line of every gate (`GATE <level> <difficulty> <gate>:
##                              <verdict> (<evidence>)`, CoopSearch.verdict_line) and the summary
##   ... -- --nodes=<n>         the resting-point bound (CoopSearch.node_limit; default MAX_NODES)
##   ... -- --ticks=<n>         the tick budget (CoopSearch.tick_limit; default MAX_TICKS)
##   ... -- --no-probes         no continuous-play probes (every bounded result is then UNPROVEN)
##   ... -- --plan              THE GATE JOB'S PLAN (tools/world_coop_gates.sh): no search - one line per piece of the
##                              three proofs of every chosen gate row, saying whether its kept result is still valid
##                              for today's level file and simulation code or has to be made:
##                                `PLAN search <level> <gate> <0|1> <cost s> todo|kept`
##                                `PLAN explore <level> <gate> <0|1> <pass> todo|kept [| its kept line]`
##                                `PLAN replay <route file> todo|kept [| its kept line]`
##                              and a summary; with --fresh everything is `todo`, with --no-explore no explorer lines
##   ... -- --no-explore        (with --plan) leave the explorer's passes out of the plan
##   ... -- --max-gates=<n>     stop after n searches (a queue worker that makes room for an import between gates)
##   ... -- --queue=<dir>       a WORKER of a shared queue: take the gates dearest first (CoopSearch.order_by_cost) and
##                              search only those this process claims in <dir> (CoopSearch.claim_gate) - N workers
##                              started on the same <dir> share the table without a fixed split (tools/world_coop_gates.sh)
##   ... -- --repeat=<k>        a SCALE BENCH: the chosen gates k times over (copy 0 as usual, copies 1..k-1 searched
##                              afresh - no cache read or write), so a table of 45 gates times 3 costs what about 70 gates x
##                              2 difficulties will (tools/world_coop_gates.sh --bench <k>); with --queue each copy is claimed
##                              on its own
## Prints per gate: one line (refused / REACHED / UNPROVEN, seconds, resting points, runs, ticks simulated), its G59
## verdict line (`GATE ...`: refused (exhaustive) | refused (bounded) | open | unproven, with the evidence) and the
## report of the search and of every probe family (CoopSearch.report_lines); then a summary with the verdict counts.
## Exit code 0 = every gate refused (exhaustively, or bounded with every probe of its kind) and every window below its
## solo minimum - 4; 1 = a gate is open or unproven or a window too wide; 2 = bad arguments.
##
## Autoloads are reached through the tree and the search is loaded by path: this script is compiled before they exist.

const SEARCH_PATH: String = "res://scripts/world/coop_search.gd"
## The continuous-play harness (the explorer's passes and the evidence replays keep their results by its keys).
const HARNESS_PATH: String = "res://tools/coop_explore/harness.gd"


## --sim-profile: Sim's development profiler hook (Sim._profiler): the time of every entity call by script and of
## the tick's own parts.
class SimProfile:
	extends RefCounted

	var calls: Dictionary = {}
	var parts: Dictionary = {}

	func add_call(_phase: int, script: Script, usec: int) -> void:
		var key: String = script.resource_path.get_file() if script != null else "?"
		calls[key] = int(calls.get(key, 0)) + usec

	func add_part(part: StringName, usec: int) -> void:
		parts[part] = int(parts.get(part, 0)) + usec

	func report() -> String:
		var rows: Array = []
		for key: String in calls:
			rows.append([int(calls[key]), key])
		for key: StringName in parts:
			rows.append([int(parts[key]), String(key)])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var lines: PackedStringArray = PackedStringArray()
		for row: Array in rows.slice(0, 14):
			lines.append("%s %.1f s" % [row[1], row[0] / 1000000.0])
		return ", ".join(lines)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var selectors: PackedStringArray = PackedStringArray()
	var listing: bool = false
	var profiling: bool = false
	var shard: Vector2i = Vector2i(0, 1)
	var cache: bool = true
	var sim_profile: SimProfile = null
	var search_debug: bool = false
	var stats: bool = false
	var queue: String = ""
	var egg: bool = false
	var repeat: int = 1
	var node_limit: int = -1
	var tick_limit: int = -1
	var no_probes: bool = false
	var fresh: bool = false
	var table_only: bool = false
	var max_gates: int = -1
	var search_moves: bool = false
	var reset_report: bool = false
	var audit: bool = false
	var planning: bool = false
	var plan_explore: bool = true
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--list":
			listing = true
		elif argument == "--profile":
			profiling = true
		elif argument == "--sim-profile":
			sim_profile = SimProfile.new()
		elif argument == "--nodes":
			search_debug = true
		elif argument == "--moves":
			search_debug = true
			search_moves = true
		elif argument == "--reset-report":
			reset_report = true
		elif argument == "--audit":
			audit = true
		elif argument == "--stats":
			stats = true
		elif argument == "--egg":
			egg = true
		elif argument.begins_with("--queue="):
			queue = argument.get_slice("=", 1)
		elif argument.begins_with("--repeat="):
			var count: String = argument.get_slice("=", 1)
			if not count.is_valid_int() or count.to_int() < 1:
				print("coop_search: bad --repeat (want a count of 1 or more)")
				_finish(2)
				return
			repeat = count.to_int()
		elif argument == "--no-cache":
			cache = false
		elif argument == "--plan":
			planning = true
		elif argument == "--no-explore":
			plan_explore = false
		elif argument == "--no-probes":
			no_probes = true
		elif argument == "--fresh":
			fresh = true
		elif argument == "--table":
			table_only = true
		elif argument.begins_with("--max-gates="):
			var most: String = argument.get_slice("=", 1)
			if not most.is_valid_int() or most.to_int() < 1:
				print("coop_search: bad --max-gates (want a count of 1 or more)")
				_finish(2)
				return
			max_gates = most.to_int()
		elif argument.begins_with("--ticks="):
			var budget: String = argument.get_slice("=", 1)
			if not budget.is_valid_int() or budget.to_int() < 1:
				print("coop_search: bad --ticks (want a count of 1 or more)")
				_finish(2)
				return
			tick_limit = budget.to_int()
		elif argument.begins_with("--nodes="):
			var limit: String = argument.get_slice("=", 1)
			if not limit.is_valid_int() or limit.to_int() < 1:
				print("coop_search: bad --nodes (want a count of 1 or more)")
				_finish(2)
				return
			node_limit = limit.to_int()
		elif argument.begins_with("--shard="):
			var parts: PackedStringArray = argument.get_slice("=", 1).split("/")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
				print("coop_search: bad --shard (want <i>/<n>)")
				_finish(2)
				return
			shard = Vector2i(parts[0].to_int(), maxi(parts[1].to_int(), 1))
		elif argument.begins_with("--"):
			print("coop_search: unknown option %s" % argument)
			_finish(2)
			return
		else:
			selectors.append(argument)
	var search: GDScript = load(SEARCH_PATH) as GDScript
	if search == null:
		print("coop_search: the search %s cannot be loaded" % SEARCH_PATH)
		_finish(2)
		return
	search.set(&"use_cache", cache)
	search.set(&"debug_nodes", search_debug)
	search.set(&"debug_moves", search_moves)
	search.set(&"collect_reset_report", reset_report)
	search.set(&"reset_audit", audit)
	search.set(&"use_file_cache", cache)
	search.set(&"collect_stats", stats)
	if node_limit > 0:
		search.set(&"node_limit", node_limit)
	if tick_limit > 0:
		search.set(&"tick_limit", tick_limit)
	if no_probes:
		search.set(&"probes", false)
	if egg:
		search.set(&"idle_partner", false)
	var table: Array = search.call(&"gate_table")
	if shard.y > 1:
		table = search.call(&"shard_gates", table, shard.x, shard.y)
	var chosen: Array = []
	for entry: Dictionary in table:
		if selectors.is_empty() or _selected(entry, selectors):
			chosen.append(entry)
	if listing:
		for i: int in chosen.size():
			var entry: Dictionary = chosen[i]
			print("%3d  %s  %s  %s  tablet %s  far %s" % [i, entry["level"], _difficulty_name(int(entry["difficulty"])),
				entry["gate"], str(entry["cell"]), str(entry["far"])])
		print("coop_search: %d gate(s)" % chosen.size())
		_finish(0)
		return
	if planning:
		_plan(search, chosen, fresh, plan_explore, selectors.is_empty() and shard.y <= 1)
		_finish(0)
		return
	if sim_profile != null:
		root.get_node("Sim").set(&"_profiler", sim_profile)
	if queue != "":
		chosen = search.call(&"order_by_cost", chosen)
	if repeat > 1:
		# The bench: every copy of a gate after the first one is searched afresh (copy 0 keeps the cache rules).
		var copies: Array = []
		for entry: Dictionary in chosen:
			for copy: int in repeat:
				var twin: Dictionary = entry.duplicate()
				twin["copy"] = copy
				copies.append(twin)
		chosen = copies
	var failures: int = 0
	var verdicts: Dictionary = {}
	var searched: int = 0
	var gate_seconds: float = 0.0
	var started: int = Time.get_ticks_msec()
	for entry: Dictionary in chosen:
		if max_gates > 0 and searched >= max_gates:
			break
		var copy: int = int(entry.get("copy", 0))
		var claim_gate: String = str(entry["gate"]) if copy == 0 else "%s#%d" % [entry["gate"], copy]
		if queue != "" and not bool(search.call(&"claim_gate", queue, entry["level"], int(entry["difficulty"]),
				claim_gate)):
			continue   # another worker has it
		searched += 1
		search.call(&"profile_reset")
		search.set(&"use_cache", cache and copy == 0)
		search.set(&"use_file_cache", cache and copy == 0)
		search.set(&"refresh_cache", fresh)
		var clock: int = Time.get_ticks_msec()
		var result: Dictionary = search.call(&"search_gate", entry["level"], entry["difficulty"], entry["gate"])
		var seconds: float = (Time.get_ticks_msec() - clock) / 1000.0
		gate_seconds += seconds
		var verdict: Dictionary = search.call(&"gate_verdict", result)
		var verdict_name: String = str(verdict["verdict"])
		verdicts[verdict_name] = int(verdicts.get(verdict_name, 0)) + 1
		var label: String = "%s (%s) gate %s%s" % [entry["level"], _difficulty_name(int(entry["difficulty"])),
			entry["gate"], "" if copy == 0 else " (bench copy %d)" % copy]
		var reached: bool = bool(result.get("reached", true))
		var unproven: bool = verdict_name == "unproven"
		var bad_windows: PackedStringArray = PackedStringArray()
		for window: Dictionary in result.get("windows", []):
			if bool(window.get("slot_bound", false)):
				continue   # G34 / G47: one player never meets it, whatever its window (test_coop_gates exempts it too)
			if int(window["window"]) > int(window["solo_min"]) - 4:
				bad_windows.append("%s window %d solo_min %d" % [window["what"], window["window"], window["solo_min"]])
		if reached or not bad_windows.is_empty():
			failures += 1
		if not table_only:
			print("%s: %s in %.1f s (%d resting points, %d runs, %d ticks, %d replayed%s)" % [label,
				"UNPROVEN" if unproven else ("REACHED" if reached else "refused"), seconds,
				int(result.get("explored", 0)), int(result.get("runs", 0)), int(result.get("simulated", 0)),
				int(result.get("replayed", 0)), ", cached" if bool(result.get("cached", false)) else ""])
		print("%s%s" % ["" if table_only else "    ", search.call(&"verdict_line", entry["level"],
			int(entry["difficulty"]), str(entry["gate"]), result)])
		if not table_only:
			for line: String in search.call(&"report_lines", result):
				print("    %s" % line)
		for line: String in bad_windows:
			print("    window too wide: %s" % line)
		if profiling:
			var parts: PackedStringArray = PackedStringArray()
			var profile: Dictionary = search.get(&"profile")
			for part: StringName in profile:
				parts.append("%s %.1f s" % [part, int(profile[part]) / 1000000.0])
			print("    profile: %s" % ", ".join(parts))
		if stats:
			for line: String in search.call(&"stats_report"):
				print("    %s" % line)
		if reset_report:
			for line: String in search.call(&"reset_report_lines"):
				print("    reset found: %s" % line)
			search.set(&"reset_report", {})
		if sim_profile != null:
			print("    sim: %s" % sim_profile.report())
			sim_profile.calls.clear()
			sim_profile.parts.clear()
		# Let the main loop turn: the freed search world's canvas callbacks are flushed (wf8_D5_to_integration #1).
		await process_frame
	var counts: PackedStringArray = PackedStringArray()
	for name: String in ["refused (exhaustive)", "refused (bounded)", "open", "unproven"]:
		counts.append("%d %s" % [int(verdicts.get(name, 0)), name])
	print("coop_search: %d gate(s) in %.1f s (%.1f s searching), %d failing; verdicts: %s" % [searched,
		(Time.get_ticks_msec() - started) / 1000.0, gate_seconds, failures, ", ".join(counts)])
	_finish(1 if failures > 0 else 0)


## --plan: what the three proofs of the chosen gate rows still need (see the header). `fresh`: everything is to do;
## `explore`: the explorer's passes are part of the plan; `evidence`: the evidence set too (the whole table is chosen).
func _plan(search: GDScript, chosen: Array, fresh: bool, explore: bool, evidence: bool) -> void:
	var harness: GDScript = load(HARNESS_PATH) as GDScript if ResourceLoader.exists(HARNESS_PATH) else null
	var todo: Vector3i = Vector3i.ZERO
	var total: Vector3i = Vector3i.ZERO
	for entry: Dictionary in chosen:
		var level: StringName = entry["level"]
		var difficulty: int = int(entry["difficulty"])
		var gate: String = str(entry["gate"])
		var kept: bool = not fresh and bool(search.call(&"has_kept_result", level, difficulty, gate))
		var cost: float = float(search.call(&"gate_cost", level, difficulty, gate))
		total.x += 1
		todo.x += 0 if kept else 1
		print("PLAN search %s %s %d %.0f %s" % [level, gate, difficulty,
			cost if cost >= 0.0 else float(search.get(&"UNKNOWN_COST_SECONDS")), "kept" if kept else "todo"])
		if not explore or harness == null:
			continue
		var seconds: int = int(harness.get(&"PASS_SECONDS"))
		for pass_index: int in (harness.get(&"PASS_SEEDS") as Array).size():
			var seed_value: int = harness.call(&"row_seed", level, difficulty, gate, pass_index)
			var result: Dictionary = {} if fresh else harness.call(&"cache_read",
					harness.call(&"explore_key", level, difficulty, gate, seed_value, seconds))
			total.y += 1
			todo.y += 1 if result.is_empty() else 0
			print("PLAN explore %s %s %d %d %s" % [level, gate, difficulty, pass_index, "todo" if result.is_empty()
				else "kept | %s; %d rounds, %d ticks played (%d replays, %d of them off their state); %d s, seed %d [kept]" % [
				"REACHED the far cell in %d ticks" % int(result.get("ticks", -1)) if bool(result.get("reached", false))
				else "NOT reached", int(result.get("rounds", 0)), int(result.get("played", 0)),
				int(result.get("replays", 0)), int(result.get("misses", 0)) + int(result.get("drift", 0)),
				int(result.get("seconds", seconds)), seed_value]])
	if evidence and harness != null:
		for path: String in harness.call(&"evidence_files"):
			var result: Dictionary = {} if fresh else harness.call(&"cache_read", harness.call(&"replay_key", path))
			total.z += 1
			todo.z += 1 if result.is_empty() else 0
			print("PLAN replay %s %s" % [path.trim_prefix("res://"), "todo" if result.is_empty()
				else "kept | REPLAY %s d%d %s: %s at tick %d [kept]" % [str(result.get("level", "?")),
				int(result.get("difficulty", 0)), str(result.get("gate", "?")), str(result.get("outcome", "?")),
				int(result.get("ticks", -1))]])
	print("coop_search: plan - %d of %d search(es), %d of %d explorer pass(es), %d of %d evidence replay(s) to do" % [
		todo.x, total.x, todo.y, total.y, todo.z, total.z])


## True when `entry` matches one of `selectors` (`<level>`, `<level>:<gate>`, `<level>:<gate>:<difficulty>`).
func _selected(entry: Dictionary, selectors: PackedStringArray) -> bool:
	for selector: String in selectors:
		var parts: PackedStringArray = selector.split(":")
		if parts[0] != str(entry["level"]):
			continue
		if parts.size() >= 2 and parts[1] != "" and parts[1] != str(entry["gate"]):
			continue
		if parts.size() >= 3 and parts[2].to_lower() != _difficulty_name(int(entry["difficulty"])).to_lower():
			continue
		return true
	return false


func _difficulty_name(difficulty: int) -> String:
	return "Expert" if difficulty == 1 else "Beginner"


func _finish(code: int) -> void:
	# Let the audio autoload release its players before the engine shuts down (no leak reports).
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.1).timeout
	quit(code)
