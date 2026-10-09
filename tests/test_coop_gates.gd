extends TestCase
## Co-op requiredness (owner: integration; docs/expansion/PLAN.md 8 V3.c, docs/LEVEL_DESIGN.md 15.7.3 - 15.7.6).
##
## The table is not written here: every `objects/x2_tablet gate=<name> far=c,r` of every co-op file (`kind = coop`)
## on every difficulty it is placed for is a co-op gate. For each one the solo-impossibility search of world-B
## (scripts/world/coop_search.gd, PLAN.md P1.7) must FAIL to bring a single reference hero - every weapon, every belt
## special, Chomper where the stage has a pen - to the tablet's `far` cell within its bound, and every twin window
## and daze value the search measures near the gate must be below the measured solo minimum minus 4 ticks
## (`window <= solo_min - 4`). The table is empty until the first co-op file lands; the test passes on an empty
## table, and a gate without the search fails (no co-op file may ship unproven).
##
## The call this test makes (the search's contract, to be confirmed by world-B with P1.7):
##   coop_search.gd: static func search_gate(level_id: StringName, difficulty: int, gate: String) -> Dictionary
##     "reached": bool     true = a single hero got to the far cell (the gate is not co-op only)
##     "bound": int        ticks the search was allowed (LEVEL_DESIGN 15.7.6: 1 457 *(tune)*)
##     "windows": Array    [{"what": String, "window": int, "solo_min": int, "slot_bound": bool}] for every twin
##                         window / daze record; "slot_bound" (G34 / G47) exempts it from the solo_min - 4 cap
##     "detail": String    how the hero got there (when reached), for the failure message
## and, since the orchestrator's SEARCH decision after G3 (DESIGN.md G59, PLAN.md 8 V3.c: "a refusal names its
## evidence"), the verdict of every result:
##   coop_search.gd: static func gate_verdict(result: Dictionary) -> Dictionary
##     "verdict": String   "refused (exhaustive)" - the frontier emptied below the bound, or the static reach rule;
##                         "refused (bounded)" - at least 660 resting points AND every continuous-play probe of the
##                         gate's kind failed; "open" - reached (red); "unproven" - stopped at its bound without its
##                         probes: never "refused"
##     "evidence": String  resting points, bound, probe counts / what is missing
## Every gate prints `<level> (<difficulty>) gate <name>: refused|REACHED in <s> s[ cached]` (the search's line,
## which tools/world_coop_gates.sh reads), `R7 <level> <difficulty> <name>: (a) ... | (b) ... | (c) ... => <row>` and
## `GATE <level> <difficulty> <name>: <verdict> (<evidence>)` (the line the G3 table of tools/g3.sh is made of). An
## OPEN gate and an UNPROVEN gate both fail the test - no co-op file ships unproven - with different words: the G3
## table shows an unproven gate as open work, not as a red proof.
##
## THE ROW IS THREE PROOFS (wf11: the orchestrator's R7, DESIGN.md G77, PLAN.md 8 V3.c "The fixed bar"; the G3b
## verifier put one hero past 19 rows the search had refused). A gate row is green only with all three:
##   (a) the solo search refuses it - exhaustive, or bounded with every probe of its kind (above), on an exact reset;
##   (b) every route of the evidence set for that row (tools/coop_explore/evidence: harness.gd evidence_files) says
##       "not reached" - each replayed in a fresh process by tools/coop_explore/replay_evidence.sh, whose kept result
##       this test reads; a search-world route without one is replayed here (the search world's reset is exact: the
##       same route does the same in any process - tests/test_world_search.gd), a real-game route without one is
##       open work;
##   (c) the continuous-play explorer (tools/coop_explore/explorer.gd) opens it in none of two seeded passes of 300 s
##       over the whole level - run by tools/world_coop_gates.sh (or tools/coop_explore/explore_gates.sh) on worker
##       processes, whose kept results this test reads (harness.gd explore_key: the level file, the simulation's
##       code, the row's seed and the seconds). A pass without a kept result is OPEN WORK (unproven) - or, with the
##       environment variable COOP_GATES_EXPLORE=inline, played here (300 s each: a shard's rows one after another).
## A replayable route is RED whatever (a) says. The GATE line's verdict is the row's: "open" names the proof that
## fell and its route file; "unproven" names the proof that did not run; "refused (...)" is all three.

## Running it: `GD_TIMEOUT=3600 bash .tools/gd.sh test coop_gates` (a slow module, PLAN.md V7; about 1.5 min per gate
## and difficulty). The environment variable COOP_GATES_SHARD=<i>/<n> runs only every n-th gate starting at i
## (0-based), so n processes can share the table (`COOP_GATES_SHARD=0/3 ...`, `1/3`, `2/3`); together they check what
## one run does.
## Each search adds a world to the tree and frees it again: the test lets a frame pass after every gate, or the freed
## nodes' queued canvas callbacks pile up until Godot's message queue overflows (wf8_D5_to_integration.txt #1).

const SEARCH: String = "res://scripts/world/coop_search.gd"
## The continuous-play harness and explorer of R7 (b) and (c) (world-B, tools/coop_explore/).
const HARNESS: String = "res://tools/coop_explore/harness.gd"
const EXPLORER: String = "res://tools/coop_explore/explorer.gd"
const TABLET_ID: StringName = &"objects/x2_tablet"
const WINDOW_MARGIN: int = 4
## The G59 verdicts (CoopSearch.VERDICT_*; spelled out here so a search without them still reads as before).
const VERDICT_OPEN: String = "open"
const VERDICT_UNPROVEN: String = "unproven"
const VERDICT_REFUSED: String = "refused"


## Every co-op gate: [level id, difficulty, gate name, far cell (Vector2i), tablet cell (Vector2i)] - the search's own
## table (CoopSearch.gate_table, wf9_world_b_to_integration.txt #1.4) when it has one, so tools/coop_search.gd
## --shard and this test can never disagree about a shard; else read here in the same order.
func _gates() -> Array[Array]:
	var gates: Array[Array] = []
	var search: GDScript = load(SEARCH) as GDScript if ResourceLoader.exists(SEARCH) else null
	if search != null and search.get_script_method_list().any(func(method: Dictionary) -> bool:
			return str(method["name"]) == "gate_table"):
		for entry: Dictionary in search.call("gate_table"):
			gates.append([entry["level"], entry["difficulty"], entry["gate"], entry["far"], entry["cell"]])
		return gates
	for level_id: StringName in Levels.all_ids():
		if not Levels.is_coop_level(level_id):
			continue
		var data: LevelData = LevelData.load_file(Levels.get_level_path(level_id))
		if data == null:
			continue
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			if not Levels.is_available(level_id, difficulty):
				continue
			for record: Dictionary in data.entity_records():
				var params: Dictionary = record["params"]
				if StringName(str(record["id"])) != TABLET_ID or not params.has("gate") \
						or not LevelText.applies_to(params, difficulty):
					continue
				var far: PackedStringArray = str(params.get("far", "")).replace(" ", "").split(",")
				var far_cell: Vector2i = Vector2i(-1, -1)
				if far.size() == 2 and far[0].is_valid_int() and far[1].is_valid_int():
					far_cell = Vector2i(far[0].to_int(), far[1].to_int())
				gates.append([level_id, difficulty, str(params["gate"]), far_cell,
					Vector2i(int(record["col"]), int(record["row"]))])
	return gates


func test_every_coop_gate_is_refused_by_the_solo_search() -> void:
	var gates: Array[Array] = _gates()
	print("    co-op gates: %d" % gates.size())
	if gates.is_empty():
		assert_eq(gates.size(), 0, "no co-op gate yet: nothing to refuse")
		return
	assert_true(ResourceLoader.exists(SEARCH), "the solo search %s (world-B, PLAN.md P1.7) proves the gates" % SEARCH)
	if not ResourceLoader.exists(SEARCH):
		return
	var search: GDScript = load(SEARCH) as GDScript
	var shard: Vector2i = _shard()
	for index: int in gates.size():
		if index % shard.y != shard.x:
			continue
		var gate: Array = gates[index]
		var label: String = "%s (%s) gate %s" % [gate[0], Defs.difficulty_name(int(gate[1])), gate[2]]
		assert_ne(gate[3], Vector2i(-1, -1), "%s: its tablet names a far cell" % label)
		var started: int = Time.get_ticks_msec()
		var result: Dictionary = search.call("search_gate", gate[0], gate[1], gate[2])
		print("    %s: %s in %.1f s%s" % [label, "REACHED" if bool(result.get("reached", true)) else "refused",
				(Time.get_ticks_msec() - started) / 1000.0, " cached" if bool(result.get("cached", false)) else ""])
		var searched: Dictionary = gate_verdict(search, result)
		# Let the main loop turn: the freed search world's canvas callbacks are flushed (see the header).
		await Engine.get_main_loop().process_frame
		# R7: the row is three proofs - (a) the search above, (b) the evidence set, (c) the explorer's two passes.
		var a_red: bool = str(searched["verdict"]) == VERDICT_OPEN
		var evidence: Dictionary = await _evidence_proof(gate[0], int(gate[1]), str(gate[2]))
		var explored: Dictionary = await _explorer_proof(gate[0], int(gate[1]), str(gate[2]),
				a_red or bool(evidence["red"]))
		var verdict: Dictionary = row_verdict(searched, evidence, explored)
		print("    R7 %s %s %s: (a) %s | (b) %s | (c) %s => %s" % [gate[0],
				Defs.difficulty_name(int(gate[1])).to_lower(), gate[2], searched["verdict"], evidence["text"],
				explored["text"], verdict["row"]])
		print("    GATE %s %s %s: %s (%s)%s" % [gate[0], Defs.difficulty_name(int(gate[1])).to_lower(), gate[2],
				verdict["verdict"], verdict["evidence"], " [cached]" if bool(result.get("cached", false)) else ""])
		if str(verdict["verdict"]) == VERDICT_UNPROVEN:
			# G59 / R7: a proof of the row did not run or stopped without its evidence - not refused, not reached.
			fail("%s: UNPROVEN (G59, R7) - %s" % [label, verdict["evidence"]])
		elif str(verdict["verdict"]) == VERDICT_OPEN:
			fail("%s: a single hero must not reach %s - OPEN (%s)" % [label, str(gate[3]), verdict["evidence"]])
		else:
			assert_false(bool(result.get("reached", true)), "%s: a single hero must not reach %s (%s)" % [label,
					str(gate[3]), str(result.get("detail", ""))])
		for window: Dictionary in result.get("windows", []):
			# G34 / G47: a slot-bound rule (two heroes' own hits: the Mangrove twin, Inkjaw's flinch, the Idols' twin,
			# the daze - only a hero of another slot than the bouncer hurts a dazed enemy) cannot be met by one player,
			# whatever its window: the search marks such a record "slot_bound" and it is exempt from the cap.
			if bool(window.get("slot_bound", false)):
				print("      %s: %s window %d is slot-bound (exempt, G34 / G47)" % [label, window.get("what", "?"),
						int(window["window"])])
				continue
			assert_true(int(window["window"]) <= int(window["solo_min"]) - WINDOW_MARGIN,
					"%s: %s window %d below the solo minimum %d - %d" % [label, window.get("what", "?"),
					window["window"], window["solo_min"], WINDOW_MARGIN])


## The G59 verdict of a search result: {"verdict", "evidence"} - the search's own (CoopSearch.gate_verdict) when it has
## one; a search without verdicts reads as before G59: reached = open, anything else "refused" with no evidence named.
static func gate_verdict(search: GDScript, result: Dictionary) -> Dictionary:
	if search != null and search.get_script_method_list().any(func(method: Dictionary) -> bool:
			return str(method["name"]) == "gate_verdict"):
		var verdict: Dictionary = search.call("gate_verdict", result)
		return {"verdict": str(verdict.get("verdict", VERDICT_UNPROVEN)), "evidence": str(verdict.get("evidence", ""))}
	if bool(result.get("reached", true)):
		return {"verdict": VERDICT_OPEN, "evidence": str(result.get("detail", ""))}
	return {"verdict": VERDICT_REFUSED, "evidence": "the search names no evidence"}


## R7 (b): the evidence routes of gate row (`level`, `difficulty`, `gate`) - {"red": a route still reaches the far
## cell, "open": a result is missing and could not be made here, "routes": their count, "text", "reached": the route
## files that reach}. A kept result of tools/coop_explore/replay_evidence.sh (a fresh process each) is read back; a
## search-world route without one is replayed here and kept; a real-game route without one is open work.
func _evidence_proof(level: StringName, difficulty: int, gate: String) -> Dictionary:
	var harness: GDScript = load(HARNESS) as GDScript if ResourceLoader.exists(HARNESS) else null
	if harness == null:
		return {"red": false, "open": true, "routes": 0, "reached": [], "text": "NOT RUN: %s is missing" % HARNESS}
	var reached: PackedStringArray = PackedStringArray()
	var missing: PackedStringArray = PackedStringArray()
	var files: PackedStringArray = harness.call(&"evidence_files", level, gate, difficulty)
	for path: String in files:
		var key: String = harness.call(&"replay_key", path)
		var kept: Dictionary = harness.call(&"cache_read", key)
		if kept.is_empty():
			var route: Dictionary = harness.call(&"read_route", path)
			if bool(route.get("real", false)):
				missing.append(path.get_file())
				continue
			var lib: RefCounted = harness.new()
			if not lib.build(level, gate, difficulty, bool(route["whole"]), int(route["tick0"])):
				missing.append(path.get_file())
				lib.close()
				continue
			var played: Dictionary = lib.play_route(route)
			lib.close()
			await Engine.get_main_loop().process_frame
			kept = {"route": path.get_file(), "level": String(level), "gate": gate, "difficulty": difficulty,
				"reached": str(played["end"]) == "goal", "ticks": int(played["t"]), "real": false,
				"outcome": "REACHED the far cell" if str(played["end"]) == "goal" else ("DIED"
				if str(played["end"]) == "dead" else "not reached")}
			harness.call(&"cache_write", key, kept)
		if bool(kept.get("reached", false)):
			reached.append("%s (tick %d)" % [path.get_file(), int(kept.get("ticks", -1))])
	var text: String = "no route in the evidence set" if files.is_empty() \
			else "%d of %d evidence route(s) not reached" % [files.size() - reached.size() - missing.size(), files.size()]
	if not reached.is_empty():
		text += "; REACHED: tools/coop_explore/evidence/%s" % ", ".join(reached)
	if not missing.is_empty():
		text += "; NOT REPLAYED (bash tools/coop_explore/replay_evidence.sh): %s" % ", ".join(missing)
	return {"red": not reached.is_empty(), "open": not missing.is_empty(), "routes": files.size(), "reached": reached,
		"text": text}


## R7 (c): the explorer's two seeded passes of 300 s on gate row (`level`, `difficulty`, `gate`) - {"red": a pass
## reached the far cell, "open": a pass has no kept result, "text"}. The kept results of tools/world_coop_gates.sh /
## tools/coop_explore/explore_gates.sh are read back; with COOP_GATES_EXPLORE=inline a missing pass is played here
## (not for a row that is red already: `row_red`).
func _explorer_proof(level: StringName, difficulty: int, gate: String, row_red: bool) -> Dictionary:
	var harness: GDScript = load(HARNESS) as GDScript if ResourceLoader.exists(HARNESS) else null
	if harness == null:
		return {"red": false, "open": true, "text": "NOT RUN: %s is missing" % HARNESS}
	var seconds: int = int(harness.get(&"PASS_SECONDS"))
	var parts: PackedStringArray = PackedStringArray()
	var red: bool = false
	var open: bool = false
	for pass_index: int in (harness.get(&"PASS_SEEDS") as Array).size():
		var seed_value: int = harness.call(&"row_seed", level, difficulty, gate, pass_index)
		var key: String = harness.call(&"explore_key", level, difficulty, gate, seed_value, seconds)
		var kept: Dictionary = harness.call(&"cache_read", key)
		if kept.is_empty() and not row_red and OS.get_environment("COOP_GATES_EXPLORE") == "inline" \
				and ResourceLoader.exists(EXPLORER):
			var explorer: Node = (load(EXPLORER) as GDScript).new() as Node
			add_child(explorer)
			await explorer.call(&"run", PackedStringArray([String(level), gate, str(difficulty),
					"pass=%d" % pass_index]))
			remove_child(explorer)
			explorer.free()
			await Engine.get_main_loop().process_frame
			kept = harness.call(&"cache_read", key)
		if kept.is_empty():
			open = true
			parts.append("pass %d (seed %d) NOT RUN" % [pass_index + 1, seed_value])
		elif bool(kept.get("reached", false)):
			red = true
			parts.append("pass %d (seed %d) REACHED the far cell in %d ticks" % [pass_index + 1, seed_value,
				int(kept.get("ticks", -1))])
		else:
			parts.append("pass %d (seed %d) not reached in %d s, %d ticks played%s" % [pass_index + 1, seed_value,
				int(kept.get("seconds", seconds)), int(kept.get("played", 0)),
				"" if int(kept.get("misses", 0)) + int(kept.get("drift", 0)) == 0
				else ", %d REPLAYS OFF THEIR STATE" % (int(kept.get("misses", 0)) + int(kept.get("drift", 0)))])
	var text: String = "explorer " + ", ".join(parts)
	if open and row_red:
		text += " (not needed: the row is red)"
	elif open:
		text += " - bash tools/world_coop_gates.sh runs the passes (or COOP_GATES_EXPLORE=inline)"
	return {"red": red, "open": open, "text": text}


## The verdict of a gate ROW under R7 from its three proofs: (a) `searched` ([method gate_verdict] of the search), (b)
## `evidence` ([method _evidence_proof]), (c) `explored` ([method _explorer_proof]) - {"verdict": VERDICT_OPEN when
## any of the three opened it (a replayable route is red whatever the search says), VERDICT_UNPROVEN when none did
## but one did not run, else the search's own "refused (exhaustive)" / "refused (bounded)"; "evidence"; "row": "GREEN"
## / "RED" / "OPEN WORK"}.
static func row_verdict(searched: Dictionary, evidence: Dictionary, explored: Dictionary) -> Dictionary:
	var a: String = str(searched.get("verdict", VERDICT_UNPROVEN))
	if a == VERDICT_OPEN or bool(evidence.get("red", false)) or bool(explored.get("red", false)):
		var why: PackedStringArray = PackedStringArray()
		if a == VERDICT_OPEN:
			why.append("(a) the search: %s" % str(searched.get("evidence", "")))
		if bool(evidence.get("red", false)):
			why.append("(b) %s" % str(evidence.get("text", "")))
		if bool(explored.get("red", false)):
			why.append("(c) %s" % str(explored.get("text", "")))
		return {"verdict": VERDICT_OPEN, "evidence": "; ".join(why), "row": "RED"}
	if a == VERDICT_UNPROVEN or bool(evidence.get("open", false)) or bool(explored.get("open", false)):
		var missing: PackedStringArray = PackedStringArray()
		if a == VERDICT_UNPROVEN:
			missing.append("(a) the search: %s" % str(searched.get("evidence", "")))
		if bool(evidence.get("open", false)):
			missing.append("(b) %s" % str(evidence.get("text", "")))
		if bool(explored.get("open", false)):
			missing.append("(c) %s" % str(explored.get("text", "")))
		return {"verdict": VERDICT_UNPROVEN, "evidence": "; ".join(missing), "row": "OPEN WORK"}
	return {"verdict": a, "evidence": "%s; R7 (b) %s; (c) %s" % [str(searched.get("evidence", "")),
		str(evidence.get("text", "")), str(explored.get("text", ""))], "row": "GREEN"}


## The shard of the gate table this process runs: (index, count) from COOP_GATES_SHARD=<i>/<n>; (0, 1) = all gates.
func _shard() -> Vector2i:
	var text: String = OS.get_environment("COOP_GATES_SHARD")
	var parts: PackedStringArray = text.split("/")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		var count: int = maxi(1, parts[1].to_int())
		var index: int = clampi(parts[0].to_int(), 0, count - 1)
		if count > 1:
			print("    shard %d of %d" % [index, count])
		return Vector2i(index, count)
	return Vector2i(0, 1)
