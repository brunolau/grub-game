extends RouteTestCase
## Book II solo route proofs (owner: integration; docs/expansion/PLAN.md 8 V2, docs/LEVEL_DESIGN.md 15.6 and 15.9).
##
## The table is not written here: every route file in tools/autoplay/routes/ whose `# route:` header names a solo
## level of Book II (Levels.get_book == 2, not a co-op file, not an arena) is a Book II route. Each one is replayed
## through Flow by the bench (RouteTestCase.play_header_route) on every difficulty of its header and must end as
## its header says, with every `expect` check and no engine warning or error (V2.a). Every such club route is also
## replayed with the hammer, the axe, the swirling axe and the spear on the belt and must give identical per-tick
## digests (V2.b, the belt-invariance runner). The table is empty until phase 3 adds the first Book II stage; the
## tests pass on an empty table and start proving routes as soon as files land.

## Content gates (PLAN.md 4.2 G1, 6.2 G3): until phase 3 is content complete only the Beginner club route of every
## Book II stage is required (G1: "`w5_l1` with its Beginner club route"); a missing Expert route is printed, not
## failed. Integration switches this on at G3 (every (stage, difficulty) cell, V2.a).
const REQUIRE_EXPERT_ROUTES: bool = false
## The Book II stages of the G1 vertical slice (PLAN.md 4.2): when one exists, its Beginner club route must too.
const SLICE_STAGES: Array[StringName] = [&"w5_l1"]
## G3: the campaign runs must play the whole book (no stage without its route); until then they stop, PENDING, where
## the content ends.
const REQUIRE_COMPLETE_CAMPAIGN: bool = false
## The side routes the campaign runs take instead of a stage's club route (V2.c). None yet: the warp of Rattlesnake
## Gulch into Feast Land D needs the spear on the belt, and no route that ends 5-1 picks it up (requested from D5,
## wf9_integration_to_D5.txt #1); until then both runs fight Tusker and Feast Land D is proven by its own route.
const CAMPAIGN_SIDES: Dictionary = {
	BEGINNER: {},
	EXPERT: {},
}


## The Book II header routes: solo levels of book 2, one hero.
func _table() -> Dictionary:
	return header_table(ROUTE_DIR, func(_file: String, spec: Dictionary) -> bool:
		var level_id: StringName = StringName(str(spec.get("level", "")))
		return Levels.get_book(level_id) == Levels.BOOK_2 and Levels.is_solo_level(level_id) \
				and int(spec.get("players", 1)) == 1)


## The Book II stages of the registry (solo, not test levels).
func _stages() -> Array[StringName]:
	var stages: Array[StringName] = []
	for level_id: StringName in Levels.all_ids():
		if Levels.get_book(level_id) == Levels.BOOK_2 and Levels.is_solo_level(level_id) \
				and Levels.get_level_kind(level_id) != Levels.KIND_TEST:
			stages.append(level_id)
	return stages


## Every route file of a Book II stage has a valid header, and every (stage, difficulty) has exactly one club route
## that ends the stage (V2.a: `<id>.inputs` Beginner, `<id>.expert.inputs` Expert; an Expert-only stage has just
## `<id>.inputs`).
func test_every_book2_stage_has_its_club_routes() -> void:
	var table: Dictionary = _table()
	assert_eq(header_problems(table), PackedStringArray(), "Book II route headers")
	var stages: Array[StringName] = _stages()
	var problems: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(ROUTE_DIR):
		for stage: StringName in stages:
			if file.begins_with(String(stage) + ".") and not table.has(file):
				problems.append("%s: a route of Book II stage %s without a valid header" % [file, stage])
	var pending: PackedStringArray = PackedStringArray()
	for stage: StringName in stages:
		for mode: String in [BEGINNER, EXPERT]:
			var difficulty: int = Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER
			if not Levels.is_available(stage, difficulty):
				continue
			var club: PackedStringArray = club_routes(table, stage, mode)
			var line: String = "%s (%s): %d club route(s) %s" % [stage, mode, club.size(), str(club)]
			if club.size() > 1:
				problems.append(line)
			elif club.is_empty():
				# An Expert-only stage's only route is its Beginner-named file, so it is required like a Beginner one.
				var required: bool = g3_required(REQUIRE_EXPERT_ROUTES) or mode == BEGINNER \
						or not Levels.is_available(stage, Defs.Difficulty.BEGINNER)
				if required:
					problems.append(line)
				else:
					pending.append(line)
	for line: String in pending:
		print("    pending until G3: %s" % line)
	assert_eq(problems, PackedStringArray(), "%d Book II stage(s), %d route(s)" % [stages.size(), table.size()])


## The club routes of a Book II stage on a mode (V2.a): `<id>.inputs` / `<id>.expert.inputs` with a header of that
## mode that ends the stage, no special on the belt.
static func club_routes(table: Dictionary, stage: StringName, mode: String) -> PackedStringArray:
	var club: PackedStringArray = PackedStringArray()
	for file: String in table:
		var spec: Dictionary = table[file]
		if str(spec["level"]) == String(stage) and (spec["modes"] as Array).has(mode) \
				and str(spec.get("leaves", "")) != "" and int(spec.get("belt", -1)) < 0 \
				and (file == "%s.inputs" % stage or file == "%s.expert.inputs" % stage):
			club.append(file)
	return club


## The G1 slice (PLAN.md 4.2): a slice stage that exists has its Beginner club route, played through Flow by
## test_book2_routes and proven belt-invariant by test_book2_belt_invariance.
func test_the_slice_stages_have_their_beginner_route() -> void:
	var table: Dictionary = _table()
	var landed: int = 0
	for stage: StringName in SLICE_STAGES:
		if not Levels.has_level(stage):
			print("    slice: %s has not landed yet" % stage)
			continue
		landed += 1
		assert_eq(Levels.get_book(stage), Levels.BOOK_2, "%s is a Book II file" % stage)
		assert_true(Levels.is_solo_level(stage), "%s is a solo file" % stage)
		assert_eq(club_routes(table, stage, BEGINNER).size(), 1, "%s: its Beginner club route %s.inputs" % [stage, stage])
	assert_true(landed <= SLICE_STAGES.size())


## Every Book II file is valid (the validator, LEVEL_DESIGN.md 15.10): no error in any of them (test levels
## included), and no warning in a stage (`--strict`).
func test_every_book2_file_is_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	validator.add_folder(Levels.LEVEL_DIR)
	validator.run()
	var problems: PackedStringArray = PackedStringArray()
	var files: int = 0
	for level_id: StringName in Levels.all_ids():
		if Levels.get_book(level_id) != Levels.BOOK_2 or not Levels.is_solo_level(level_id):
			continue
		files += 1
		var strict: bool = Levels.get_level_kind(level_id) != Levels.KIND_TEST
		for problem: Dictionary in validator.problems_of(Levels.get_level_path(level_id)):
			if strict or int(problem["severity"]) == LevelValidator.ERROR:
				problems.append(LevelValidator.format_problem(problem))
	print("    Book II files: %d" % files)
	assert_eq(problems, PackedStringArray(), "Book II files: no error, and no warning in a stage")


## Every Cave Painting placed in a Book II stage is collected by some route (`expect=painting:<index>`, V2.c).
func test_every_book2_painting_has_a_route() -> void:
	var named: Dictionary = {}
	var table: Dictionary = _table()
	for file: String in table:
		var expect: Dictionary = table[file].get("expect", {})
		if expect.has("painting"):
			named[int(expect["painting"])] = file
	var missing: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.create_from_string("items/painting\\b[^\\n]*\\bindex=(\\d+)")
	for stage: StringName in _stages():
		for found: RegExMatch in regex.search_all(FileAccess.get_file_as_string(Levels.get_level_path(stage))):
			if not named.has(found.get_string(1).to_int()):
				missing.append("%s: painting %s" % [stage, found.get_string(1)])
	assert_eq(missing, PackedStringArray(), "paintings without a route")


## V2.a: every Book II route through Flow, as its header says.
func test_book2_routes() -> void:
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
	assert_eq(played, expected, "every Book II route run started")
	print("    Book II: %d route run(s)" % played)


## V2.c: Book II in ONE run per difficulty, with what the run carries (score, lives, letters, hand and belt), every
## stage by its club route except the side routes CAMPAIGN_SIDES names - the headless twin of
## tools/autoplay/campaign_b2.flow. Until G3 (REQUIRE_COMPLETE_CAMPAIGN) the run plays the stops that have landed and
## stops, PENDING, at the first stage without its route.
func test_the_book2_beginner_campaign_in_one_run() -> void:
	await play_campaign(Levels.BOOK_2, BEGINNER, 1, CAMPAIGN_SIDES[BEGINNER], g3_required(REQUIRE_COMPLETE_CAMPAIGN))


func test_the_book2_expert_campaign_in_one_run() -> void:
	await play_campaign(Levels.BOOK_2, EXPERT, 1, CAMPAIGN_SIDES[EXPERT], g3_required(REQUIRE_COMPLETE_CAMPAIGN))


## V2.b: every Book II club route gives the same per-tick digests whatever special rides on the belt.
func test_book2_belt_invariance() -> void:
	var table: Dictionary = _table()
	var problems: PackedStringArray = PackedStringArray()
	for file: String in table:
		if bool(table[file].get("chained", false)) or int(table[file].get("belt", -1)) >= 0:
			continue
		for mode: String in table[file]["modes"]:
			problems.append_array(await belt_invariance_problems(file, mode, table))
	assert_eq(problems, PackedStringArray(), "belt invariance of %d Book II route(s)" % table.size())
