extends RouteTestCase
## Gate G3 bookkeeping (owner: integration; docs/expansion/PLAN.md 6.2 "Gate G3": 20 Book II files + 35 co-op files +
## 10 arenas; 31 solo club routes, about 6 featured routes, 57 two-stream co-op routes, belt invariance on all, every x2
## gate refused by the search, every (arena, mode) bot test green).
##
## The content half of the G3 table, read from the tree: which files of the design exist, which (stage, difficulty)
## cells have their route, the featured routes, the paintings with a route (V2.c), the x2 gates of every co-op file
## (at least two per main stage, PLAN.md 9 "never cut"), the arenas and their bot graphs. It prints one `G3 |` line per
## row (tools/g3.sh puts them beside the verdicts of the slow modules it runs) and passes while phase 3 is under way;
## with the environment variable G3_REQUIRE=1 every row must be complete (tools/g3.sh --require, at the gate).
## The proofs themselves are the slow modules: test_book2_routes (V2.a-c), test_coop_routes (V3.a-b), test_coop_gates
## (V3.c), test_versus_bots (V4.b), test_campaign_routes (Book I) - tools/g3.sh runs them all.

## Expert-only files of the design (DESIGN.md A.2 mode E; Book I's world 4 and ending): one cell each, the others two.
const EXPERT_ONLY: Array[StringName] = [&"w4_l1", &"w4_l2", &"w4_l2b", &"ending", &"w8_l1", &"w8_l2", &"w8_l2b",
	&"w9_l1", &"w9_l1b", &"w9_l2", &"w9_l2b", &"w9_l3", &"ending_b"]
## The arenas of DESIGN.md E.5 in table order: the first eight ship at launch, Mesa Rodeo and Cloud Top are the
## painting unlocks (cut 3 of PLAN.md 9: built only after the eight are green).
const ARENAS: Array[StringName] = [&"arena_totem_ring", &"arena_echo_hollow", &"arena_floe_rink", &"arena_cinder_pit",
	&"arena_tar_pulleys", &"arena_coconut_cove", &"arena_sky_picnic", &"arena_colossus_hall", &"arena_mesa_rodeo",
	&"arena_cloud_top"]
const LAUNCH_ARENAS: int = 8
const BOT_GRAPH_DIR: String = "res://resources/bots/"
## About six featured routes at G3 (PLAN.md 6.2): routes of Book II stages that are not club routes.
const FEATURED_WANTED: int = 6
## Book II's paintings (DESIGN.md C.9: one per Book II level, indices 0..19).
const BOOK2_PAINTINGS: int = 20
## A co-op file of a main stage has at least this many x2 gates per difficulty (PLAN.md 9, never cut).
const MIN_GATES_MAIN: int = 2


func test_g3_inventory() -> void:
	var require: bool = OS.get_environment("G3_REQUIRE") == "1"
	var rows: Array[Array] = []
	var table: Dictionary = header_table(ROUTE_DIR, func(_file: String, spec: Dictionary) -> bool:
		return (spec["errors"] as PackedStringArray).is_empty())
	rows.append(_files_row("book2_files", DESIGN_FILES[2], ""))
	var coop_wanted: Array = (DESIGN_FILES[1] as Array) + (DESIGN_FILES[2] as Array)
	rows.append(_files_row("coop_files", coop_wanted, "_coop"))
	rows.append(_cells_row("solo_cells", table, DESIGN_FILES[2], "", 1))
	rows.append(_cells_row("coop_cells", table, coop_wanted, "_coop", 2))
	rows.append(_featured_row(table))
	rows.append(_paintings_row(table))
	rows.append(_gates_row())
	rows.append(_arenas_row())
	print("    G3 | row | have | want | state | detail")
	for row: Array in rows:
		print("    G3 | %s | %d | %d | %s | %s" % [row[0], row[1], row[2], "complete" if row[3] else "open", row[4]])
		if require:
			assert_true(row[3], "G3 %s: %d of %d - %s" % [row[0], row[1], row[2], row[4]])
	assert_eq(rows.size(), 8, "every G3 content row was counted")


## Files of the design that exist (`suffix` "_coop": their co-op files).
func _files_row(row: String, wanted: Array, suffix: String) -> Array:
	var missing: PackedStringArray = PackedStringArray()
	for level_id: StringName in wanted:
		if not Levels.has_level(StringName(String(level_id) + suffix)):
			missing.append(String(level_id) + suffix)
	var have: int = wanted.size() - missing.size()
	return [row, have, wanted.size(), missing.is_empty(), "missing: " + ", ".join(missing) if not missing.is_empty() else "all"]


## (file, difficulty) cells of the design with exactly one stage-ending route of `players` (Book II solo: the club
## route of V2.a; co-op: the two-stream route of V3.a). A file that does not exist yet counts its design cells as open.
func _cells_row(row: String, table: Dictionary, wanted: Array, suffix: String, players: int) -> Array:
	var cells: int = 0
	var have: int = 0
	var open: PackedStringArray = PackedStringArray()
	for base: StringName in wanted:
		var level_id: StringName = StringName(String(base) + suffix)
		for mode: String in [BEGINNER, EXPERT] if not EXPERT_ONLY.has(base) else [EXPERT]:
			cells += 1
			var file: String = campaign_route(table, level_id, mode, {})
			if file != "" and int(table[file].get("players", 1)) == players:
				have += 1
			else:
				open.append("%s%s" % [level_id, "" if mode == BEGINNER or EXPERT_ONLY.has(base) else " (E)"])
	return [row, have, cells, open.is_empty(), "open: " + ", ".join(open) if not open.is_empty() else "all"]


## Featured routes (PLAN.md 6.2 recipe step 3): header routes of Book II solo stages that are not their club routes.
func _featured_row(table: Dictionary) -> Array:
	var featured: PackedStringArray = PackedStringArray()
	for file: String in table:
		var level_id: StringName = StringName(str(table[file]["level"]))
		if Levels.get_book(level_id) != Levels.BOOK_2 or not Levels.is_solo_level(level_id) \
				or Levels.get_level_kind(level_id) == Levels.KIND_TEST:
			continue
		if file != "%s.inputs" % level_id and file != "%s.expert.inputs" % level_id:
			featured.append(file)
	return ["featured", featured.size(), FEATURED_WANTED, featured.size() >= FEATURED_WANTED, ", ".join(featured)]


## Book II's paintings 0..19: each collected by some Book II solo route (`expect=painting:<n>`, V2.c).
func _paintings_row(table: Dictionary) -> Array:
	var named: Dictionary = {}
	for file: String in table:
		var expect: Dictionary = table[file].get("expect", {})
		var level_id: StringName = StringName(str(table[file]["level"]))
		if expect.has("painting") and Levels.get_book(level_id) == Levels.BOOK_2 and Levels.is_solo_level(level_id):
			named[int(expect["painting"])] = file
	var open: PackedStringArray = PackedStringArray()
	for index: int in BOOK2_PAINTINGS:
		if not named.has(index):
			open.append(str(index))
	return ["paintings", BOOK2_PAINTINGS - open.size(), BOOK2_PAINTINGS, open.is_empty(),
		"without a route: " + ", ".join(open) if not open.is_empty() else "all"]


## The x2 gates of every co-op file per difficulty (the table test_coop_gates searches) and the main stages' co-op files
## with fewer than MIN_GATES_MAIN of them on a difficulty. Complete when every co-op file of the design exists and no
## main stage is short.
func _gates_row() -> Array:
	var gates: int = 0
	var short: PackedStringArray = PackedStringArray()
	var files: int = 0
	for level_id: StringName in Levels.all_ids():
		if not Levels.is_coop_level(level_id) or Levels.get_level_kind(Levels.get_coop_base(level_id)) == Levels.KIND_TEST:
			continue
		files += 1
		var data: LevelData = LevelData.load_file(Levels.get_level_path(level_id))
		if data == null:
			continue
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			if not Levels.is_available(level_id, difficulty):
				continue
			var count: int = 0
			for record: Dictionary in data.entity_records():
				var params: Dictionary = record["params"]
				if StringName(str(record["id"])) == TABLET_ID and params.has("gate") \
						and LevelText.applies_to(params, difficulty):
					count += 1
			gates += count
			var main: bool = Levels.get_level_kind(Levels.get_coop_base(level_id)) == Levels.KIND_MAIN
			if main and count < MIN_GATES_MAIN:
				short.append("%s (%s): %d" % [level_id, Defs.difficulty_name(difficulty), count])
	var complete: bool = short.is_empty() and design_complete(Levels.BOOK_1, true) and design_complete(Levels.BOOK_2, true)
	return ["x2_gates", gates, gates, complete, "%d co-op file(s); main stages under %d gates: %s" % [files,
		MIN_GATES_MAIN, ", ".join(short) if not short.is_empty() else "none"]]


## The arenas of DESIGN.md E.5 that exist, each with its bot graph (resources/bots/<id>.json); complete with the eight
## launch arenas (the two unlockables follow only after them, cut 3).
func _arenas_row() -> Array:
	var have: int = 0
	var notes: PackedStringArray = PackedStringArray()
	var launch_ok: bool = true
	for i: int in ARENAS.size():
		var arena: StringName = ARENAS[i]
		var exists: bool = Levels.is_arena(arena)
		var graph: bool = FileAccess.file_exists(BOT_GRAPH_DIR + String(arena) + ".json")
		if exists:
			have += 1
		if not exists or not graph:
			notes.append("%s%s" % [arena, " (no bot graph)" if exists else (" (unlockable)" if i >= LAUNCH_ARENAS else "")])
			launch_ok = launch_ok and i >= LAUNCH_ARENAS
	return ["arenas", have, ARENAS.size(), launch_ok, "launch %d; missing: %s" % [LAUNCH_ARENAS,
		", ".join(notes) if not notes.is_empty() else "none"]]
