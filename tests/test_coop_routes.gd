extends RouteTestCase
## Co-op route proofs (owner: integration; docs/expansion/PLAN.md 8 V3.a / V3.b, docs/LEVEL_DESIGN.md 15.7 and 15.9).
##
## The table is not written here: every route file in tools/autoplay/routes/ whose `# route:` header names a co-op
## file (`kind = coop`) with `players=2` (or more) is a co-op route - one input stream per player (`ticks:KEYS|KEYS`,
## Autoplay.parse_inputs_multi), recorded with `--record` or written as duo macros. Each one is replayed through Flow
## by the bench on every difficulty of its header (a co-op run of its party, the book of its level) and must end as
## its header says (the team exit, a warp or the boss trophy), with every `expect` check - the co-op keys `eggs`,
## `wipes`, `hatches`, `x2_gates` included - and no engine warning or error (V3.a). Every co-op route also replays to
## identical digests twice, without dozing and with the player slots on other devices (V3.b), and with every special
## on the belt (the belt invariance of DESIGN.md C.1). The table is empty until the first co-op file and its routes
## land (phase 1 slice, phase 3 content); the tests pass on an empty table.

## Content gates (PLAN.md 4.2 G1, 6.2 G3): until phase 3 is content complete only the Beginner route of every co-op
## file is required; a missing Expert route is printed, not failed. Integration switches this on at G3 (V3.a).
const REQUIRE_EXPERT_ROUTES: bool = false
## The co-op files of the G1 vertical slice (PLAN.md 4.2): when one exists, its Beginner two-stream route must too.
const SLICE_FILES: Array[StringName] = [&"w5_l1_coop", &"w1_l1_coop"]
## G3: the co-op campaign runs must play the whole book; until then they stop, PENDING, where the content ends.
const REQUIRE_COMPLETE_CAMPAIGN: bool = false
## Side routes of the co-op campaign runs, per book and mode (a warp into a Feast Land instead of a stage's route).
const CAMPAIGN_SIDES: Dictionary = {}


## The co-op header routes: co-op files, a party of two or more.
func _table() -> Dictionary:
	return header_table(ROUTE_DIR, func(_file: String, spec: Dictionary) -> bool:
		return Levels.is_coop_level(StringName(str(spec.get("level", "")))) and int(spec.get("players", 1)) >= 2)


## The co-op files of the registry (with `tests`: also the co-op files of test levels, which the route harness's own
## tests prove with their fixture routes, tests/test_integration_belt.gd).
func _coop_files(tests: bool = false) -> Array[StringName]:
	var files: Array[StringName] = []
	for level_id: StringName in Levels.all_ids():
		if Levels.is_coop_level(level_id) and (tests 				or Levels.get_level_kind(Levels.get_coop_base(level_id)) != Levels.KIND_TEST):
			files.append(level_id)
	return files


## Every route of a co-op file has a valid two-stream header, and every (co-op file, difficulty) has exactly one
## route that ends the stage (`<id>_coop.inputs` Beginner, `<id>_coop.expert.inputs` Expert).
func test_every_coop_file_has_its_routes() -> void:
	var table: Dictionary = _table()
	assert_eq(header_problems(table), PackedStringArray(), "co-op route headers")
	var files: Array[StringName] = _coop_files()
	var problems: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(ROUTE_DIR):
		for level_id: StringName in files:
			if file.begins_with(String(level_id) + ".") and not table.has(file):
				problems.append("%s: a route of co-op file %s without a valid players=2 header" % [file, level_id])
	var pending: PackedStringArray = PackedStringArray()
	for level_id: StringName in files:
		for mode: String in [BEGINNER, EXPERT]:
			var difficulty: int = Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER
			if not Levels.is_available(level_id, difficulty):
				continue
			var routes: PackedStringArray = stage_routes(table, level_id, mode)
			var line: String = "%s (%s): %d route(s) %s" % [level_id, mode, routes.size(), str(routes)]
			if routes.size() > 1:
				problems.append(line)
			elif routes.is_empty():
				var required: bool = g3_required(REQUIRE_EXPERT_ROUTES) or mode == BEGINNER
				if required or not Levels.is_available(level_id, Defs.Difficulty.BEGINNER):
					problems.append(line)
				else:
					pending.append(line)
	for line: String in pending:
		print("    pending until G3: %s" % line)
	assert_eq(problems, PackedStringArray(), "%d co-op file(s), %d route(s)" % [files.size(), table.size()])


## The routes that end co-op file `level_id` on a mode: `<id>.inputs` / `<id>.expert.inputs` (the id ends in
## `_coop`) with a two-stream header of that mode.
static func stage_routes(table: Dictionary, level_id: StringName, mode: String) -> PackedStringArray:
	var routes: PackedStringArray = PackedStringArray()
	for file: String in table:
		var spec: Dictionary = table[file]
		if str(spec["level"]) == String(level_id) and (spec["modes"] as Array).has(mode) \
				and str(spec.get("leaves", "")) != "" \
				and (file == "%s.inputs" % level_id or file == "%s.expert.inputs" % level_id):
			routes.append(file)
	return routes


## The G1 slice (PLAN.md 4.2): a slice co-op file that exists belongs to its solo level, plays in the co-op campaign
## of its book and has its Beginner two-stream route.
func test_the_slice_files_have_their_beginner_route() -> void:
	var table: Dictionary = _table()
	assert_eq(SLICE_FILES.size(), 2, "w5_l1_coop and w1_l1_coop")
	for level_id: StringName in SLICE_FILES:
		if not Levels.has_level(level_id):
			print("    slice: %s has not landed yet" % level_id)
			continue
		var base: StringName = Levels.get_coop_base(level_id)
		assert_eq(String(base), String(level_id).trim_suffix("_coop"), "%s is the co-op file of its solo level" % level_id)
		assert_eq(Levels.get_coop_level(base), level_id)
		assert_eq(Levels.level_for_mode(base, Defs.GameMode.COOP), level_id, "Flow plays it for %s in co-op" % base)
		assert_eq(Levels.level_for_mode(level_id, Defs.GameMode.SINGLE), base, "and the solo file in single-player")
		assert_eq(Levels.get_book(level_id), Levels.get_book(base), "%s keeps the book of %s" % [level_id, base])
		assert_eq(Levels.get_password(level_id, Defs.Difficulty.BEGINNER), "", "co-op files have no codes")
		assert_eq(stage_routes(table, level_id, BEGINNER).size(), 1, "%s: its Beginner route %s.inputs" % [
			level_id, level_id])


## Every co-op file is valid: no validator error (the validator's `--coop` rules are world-B's, PLAN.md P1.7; a
## warning such as the `coop_base_hash` drift is printed).
func test_every_coop_file_is_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	validator.add_folder(Levels.LEVEL_DIR)
	validator.run()
	var problems: PackedStringArray = PackedStringArray()
	var files: Array[StringName] = _coop_files(true)
	for level_id: StringName in files:
		for problem: Dictionary in validator.problems_of(Levels.get_level_path(level_id)):
			if int(problem["severity"]) == LevelValidator.ERROR:
				problems.append(LevelValidator.format_problem(problem))
			else:
				print("    warning: %s" % LevelValidator.format_problem(problem))
	print("    co-op files: %d" % files.size())
	assert_eq(problems, PackedStringArray(), "co-op files: no error")


## V3.a: every co-op route through Flow, as its header says.
func test_coop_routes() -> void:
	var table: Dictionary = _table()
	var expected: int = 0
	var played: int = 0
	for file: String in table:
		if bool(table[file].get("chained", false)):
			continue
		expected += (table[file]["modes"] as Array).size()
		for mode: String in table[file]["modes"]:
			var result: Dictionary = await play_header_route(file, mode, table)
			if not result.is_empty():
				played += 1
				assert_eq(int(result["input_mismatches"]), 0, "%s (%s): every slot read its stream" % [file, mode])
	assert_eq(played, expected, "every co-op route run started")
	print("    co-op: %d route run(s)" % played)


## The co-op campaign in ONE run per book and difficulty, a party of two through Flow (the co-op files of the map
## stops, Flow passing over a stop without one yet), every stage by its two-stream route, with what the run carries -
## the headless twin of tools/autoplay/campaign_coop.flow (PLAN.md 6.2). Until G3 (REQUIRE_COMPLETE_CAMPAIGN) a run
## stops, PENDING, at the first stage without its route.
func test_the_coop_book1_beginner_campaign_in_one_run() -> void:
	await _coop_campaign(Levels.BOOK_1, BEGINNER)


func test_the_coop_book1_expert_campaign_in_one_run() -> void:
	await _coop_campaign(Levels.BOOK_1, EXPERT)


func test_the_coop_book2_beginner_campaign_in_one_run() -> void:
	await _coop_campaign(Levels.BOOK_2, BEGINNER)


func test_the_coop_book2_expert_campaign_in_one_run() -> void:
	await _coop_campaign(Levels.BOOK_2, EXPERT)


func _coop_campaign(book: int, mode: String) -> void:
	var sides: Dictionary = (CAMPAIGN_SIDES.get(book, {}) as Dictionary).get(mode, {})
	await play_campaign(book, mode, PartyTuning.COOP_PLAYERS, sides, g3_required(REQUIRE_COMPLETE_CAMPAIGN))


## V3.b: twice, without dozing, on other devices - the same digests.
func test_coop_routes_are_deterministic() -> void:
	var table: Dictionary = _table()
	var problems: PackedStringArray = PackedStringArray()
	for file: String in table:
		if bool(table[file].get("chained", false)):
			continue
		for mode: String in table[file]["modes"]:
			problems.append_array(await determinism_problems(file, mode, table))
	assert_eq(problems, PackedStringArray(), "determinism of %d co-op route(s)" % table.size())


## The belt invariance (DESIGN.md C.1, PLAN.md 8 V2.b): every co-op club route with each special on every belt.
func test_coop_belt_invariance() -> void:
	var table: Dictionary = _table()
	var problems: PackedStringArray = PackedStringArray()
	for file: String in table:
		if bool(table[file].get("chained", false)) or int(table[file].get("belt", -1)) >= 0:
			continue
		for mode: String in table[file]["modes"]:
			problems.append_array(await belt_invariance_problems(file, mode, table))
	assert_eq(problems, PackedStringArray(), "belt invariance of %d co-op route(s)" % table.size())
