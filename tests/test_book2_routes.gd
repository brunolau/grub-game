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
	for stage: StringName in stages:
		for mode: String in [BEGINNER, EXPERT]:
			var difficulty: int = Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER
			if not Levels.is_available(stage, difficulty):
				continue
			var club: PackedStringArray = PackedStringArray()
			for file: String in table:
				var spec: Dictionary = table[file]
				if str(spec["level"]) == String(stage) and (spec["modes"] as Array).has(mode) \
						and str(spec.get("leaves", "")) != "" and int(spec.get("belt", -1)) < 0 \
						and (file == "%s.inputs" % stage or file == "%s.expert.inputs" % stage):
					club.append(file)
			if club.size() != 1:
				problems.append("%s (%s): %d club route(s) %s" % [stage, mode, club.size(), str(club)])
	assert_eq(problems, PackedStringArray(), "%d Book II stage(s), %d route(s)" % [stages.size(), table.size()])


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
