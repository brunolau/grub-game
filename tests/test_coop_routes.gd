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

## The co-op header routes: co-op files, a party of two or more.
func _table() -> Dictionary:
	return header_table(ROUTE_DIR, func(_file: String, spec: Dictionary) -> bool:
		return Levels.is_coop_level(StringName(str(spec.get("level", "")))) and int(spec.get("players", 1)) >= 2)


## The co-op files of the registry.
func _coop_files() -> Array[StringName]:
	var files: Array[StringName] = []
	for level_id: StringName in Levels.all_ids():
		if Levels.is_coop_level(level_id):
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
	for level_id: StringName in files:
		for mode: String in [BEGINNER, EXPERT]:
			var difficulty: int = Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER
			if not Levels.is_available(level_id, difficulty):
				continue
			var routes: PackedStringArray = PackedStringArray()
			for file: String in table:
				var spec: Dictionary = table[file]
				if str(spec["level"]) == String(level_id) and (spec["modes"] as Array).has(mode) \
						and str(spec.get("leaves", "")) != "" \
						and (file == "%s.inputs" % level_id or file == "%s.expert.inputs" % level_id):
					routes.append(file)
			if routes.size() != 1:
				problems.append("%s (%s): %d route(s) %s" % [level_id, mode, routes.size(), str(routes)])
	assert_eq(problems, PackedStringArray(), "%d co-op file(s), %d route(s)" % [files.size(), table.size()])


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
